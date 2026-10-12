import {
  get,
  onDisconnect,
  onValue,
  ref,
  runTransaction,
  set,
  update,
} from 'firebase/database';
import { database } from '../../firebase';
import { shortId } from '../../lib/shortId';
import {
  MINIMUM_PLAYERS,
  TARGET,
  describerFor,
  describerOffsets,
  describingTeam,
  membersOf,
  scoringTeam,
  split,
  winner,
  type Team,
} from './engine';
import { PACK_ORDER } from './words.generated';

/**
 * The shared game: one room, two teams, one turn at a time.
 *
 * The database holds a seed, the packs and how far into the deck the game has
 * got — never the words. Every device derives the same deck from those, which is
 * why the describer can be the only person who *sees* a word without the word
 * being hidden anywhere.
 *
 *     blurt/{gameId}/meta      seed, packs, turn length, started
 *     blurt/{gameId}/players   {shortId}: name, cleared on disconnect
 *     blurt/{gameId}/teams     {shortId}: 1 | 2, written once at the start
 *     blurt/{gameId}/play      the turn in progress and the score
 */

export type PlayState = 'ready' | 'running' | 'ended';
export type EndReason = 'time' | 'blurt';

export interface BlurtPlay {
  round: number;
  turn: number;
  team: Team;
  describer: string;
  word: number;
  state: PlayState;
  startedAt: number | null;
  endsAt: number | null;
  reason: EndReason | null;
  scorer: Team | null;
  one: number;
  two: number;
  finished: boolean;
}

export interface BlurtSnapshot {
  exists: boolean;
  seed: number | null;
  started: boolean;
  creator: string | null;
  /** Short id to the name they are playing under. */
  players: Record<string, string>;
  teams: Record<string, Team>;
  play: BlurtPlay | null;
  packs: string[];
}

export const EMPTY_SNAPSHOT: BlurtSnapshot = {
  exists: false,
  seed: null,
  started: false,
  creator: null,
  players: {},
  teams: {},
  play: null,
  packs: [...PACK_ORDER],
};

export function playScore(play: BlurtPlay | null, team: Team): number {
  if (!play) return 0;
  return team === 1 ? play.one : play.two;
}

export function winningTeam(play: BlurtPlay | null): Team | null {
  if (!play) return null;
  return winner(play.one, play.two, TARGET);
}

export function namesOn(snapshot: BlurtSnapshot, team: Team): string[] {
  return Object.keys(snapshot.teams)
    .filter((id) => snapshot.teams[id] === team)
    .sort()
    .map((id) => snapshot.players[id] ?? 'Someone');
}

// MARK: - Observing

export function observeGame(
  gameId: string,
  onChange: (snapshot: BlurtSnapshot) => void,
): () => void {
  // Held and rebuilt in parts: `meta` changes only when settings do, while
  // `play` is rewritten on every turn and every word. One listener on the whole
  // game would re-send the roster on every tap of "Got it".
  let meta: Record<string, unknown> | null | undefined;
  let players: Record<string, string> | null | undefined;
  let teams: Record<string, number> | null | undefined;
  let play: BlurtPlay | null | undefined;

  const emit = () => {
    if (meta === undefined || players === undefined || teams === undefined || play === undefined) {
      return;
    }
    onChange({
      exists: meta !== null,
      seed: typeof meta?.seed === 'number' ? meta.seed : null,
      started: meta?.started === true,
      creator: typeof meta?.creator === 'string' ? meta.creator : null,
      players: players ?? {},
      teams: parseTeams(teams),
      play: parsePlay(play),
      packs: parsePacks(meta?.packs),
    });
  };

  const stops = [
    onValue(ref(database, `blurt/${gameId}/meta`), (snapshot) => {
      meta = (snapshot.val() as Record<string, unknown> | null) ?? null;
      emit();
    }),
    onValue(ref(database, `blurt/${gameId}/players`), (snapshot) => {
      players = (snapshot.val() as Record<string, string> | null) ?? {};
      emit();
    }),
    onValue(ref(database, `blurt/${gameId}/teams`), (snapshot) => {
      teams = (snapshot.val() as Record<string, number> | null) ?? {};
      emit();
    }),
    onValue(ref(database, `blurt/${gameId}/play`), (snapshot) => {
      play = (snapshot.val() as BlurtPlay | null) ?? null;
      emit();
    }),
  ];

  return () => stops.forEach((stop) => stop());
}

function parseTeams(raw: Record<string, number> | null): Record<string, Team> {
  const teams: Record<string, Team> = {};
  for (const [id, value] of Object.entries(raw ?? {})) {
    if (value === 1 || value === 2) teams[id] = value;
  }
  return teams;
}

function parsePacks(raw: unknown): string[] {
  if (!raw || typeof raw !== 'object') return [...PACK_ORDER];
  const chosen = Object.keys(raw as Record<string, unknown>).filter((id) =>
    PACK_ORDER.includes(id),
  );
  // An empty selection is what a corrupt read looks like, not a choice.
  return chosen.length === 0 ? [...PACK_ORDER] : chosen;
}

function parsePlay(raw: BlurtPlay | null): BlurtPlay | null {
  if (!raw || typeof raw !== 'object') return null;
  if (typeof raw.turn !== 'number' || (raw.team !== 1 && raw.team !== 2)) return null;
  if (typeof raw.describer !== 'string' || typeof raw.word !== 'number') return null;
  if (raw.state !== 'ready' && raw.state !== 'running' && raw.state !== 'ended') return null;
  return {
    round: typeof raw.round === 'number' ? raw.round : 0,
    turn: raw.turn,
    team: raw.team,
    describer: raw.describer,
    word: raw.word,
    state: raw.state,
    startedAt: typeof raw.startedAt === 'number' ? raw.startedAt : null,
    endsAt: typeof raw.endsAt === 'number' ? raw.endsAt : null,
    reason: raw.reason === 'time' || raw.reason === 'blurt' ? raw.reason : null,
    scorer: raw.scorer === 1 || raw.scorer === 2 ? raw.scorer : null,
    one: typeof raw.one === 'number' ? raw.one : 0,
    two: typeof raw.two === 'number' ? raw.two : 0,
    finished: raw.finished === true,
  };
}

// MARK: - Writing

/**
 * Registers a player and their name.
 *
 * Keyed by the short id — the same one the teams and the turn use — so a player
 * has one identity in this game rather than two. RTDB has no decrement and
 * `onDisconnect` can only set or remove, which is why presence is the set of
 * live entries rather than a count.
 */
async function ensurePresent(gameId: string, playerId: string, name: string): Promise<void> {
  const playerRef = ref(database, `blurt/${gameId}/players/${shortId(playerId, gameId)}`);
  await set(playerRef, name);
  onDisconnect(playerRef).remove();
}

/** The packs as the map the rules validate, all ticked or not at all. */
function packValue(packs: readonly string[]): Record<string, boolean> {
  const value: Record<string, boolean> = {};
  for (const id of packs) value[id] = true;
  return value;
}

export async function createGame(
  gameId: string,
  seed: number,
  creatorName: string,
  playerId: string,
  packs: readonly string[],
): Promise<void> {
  await set(ref(database, `blurt/${gameId}/meta`), {
    seed,
    creator: creatorName,
    createdAt: Date.now(),
    started: false,
    packs: packValue(packs),
  });
  await ensurePresent(gameId, playerId, creatorName);
}

export async function joinGame(gameId: string, playerId: string, name: string): Promise<void> {
  await ensurePresent(gameId, playerId, name);
}

/** The room's settings, so the lobby shows everyone the same thing. */
export async function updateSettings(
  gameId: string,
  packs: readonly string[],
): Promise<void> {
  await update(ref(database, `blurt/${gameId}/meta`), {
    packs: packValue(packs),
  });
}

/**
 * Somebody who arrives after the start goes on the smaller team.
 *
 * Read from the room rather than tracked, so a phone that slept through the
 * start still lands somewhere sensible. Two people arriving at once could both
 * pick the same team; at this scale that is a fair trade for not needing a
 * transaction.
 */
export async function assignTeam(gameId: string, playerId: string): Promise<void> {
  const teamsRef = ref(database, `blurt/${gameId}/teams`);
  const snapshot = await get(teamsRef);
  const teams = parseTeams((snapshot.val() as Record<string, number> | null) ?? null);
  // Only the people who are here. A team list keeps its departed, and counting
  // those would put a new arrival on a side that is already full of players who
  // never came back.
  const playersSnapshot = await get(ref(database, `blurt/${gameId}/players`));
  const here = new Set(Object.keys((playersSnapshot.val() as Record<string, string> | null) ?? {}));
  const present = Object.keys(teams).filter((id) => here.has(id));
  const one = present.filter((id) => teams[id] === 1).length;
  const two = present.filter((id) => teams[id] === 2).length;
  await set(ref(database, `blurt/${gameId}/teams/${shortId(playerId, gameId)}`), one <= two ? 1 : 2);
}

/**
 * Splits the room and deals the first turn.
 *
 * The roster is read here rather than passed in, so the split is worked out
 * once, by the host, from exactly the people in the room at that moment.
 */
export async function startGame(gameId: string, seed: number): Promise<void> {
  const rosterSnapshot = await get(ref(database, `blurt/${gameId}/players`));
  const roster = Object.keys((rosterSnapshot.val() as Record<string, string> | null) ?? {});
  // Refuses a room that cannot field two teams: with one person a side there is
  // nobody to describe to, and no other team to catch you saying it.
  if (roster.length < MINIMUM_PLAYERS) return;
  const teams = split(roster, seed);

  const one = Object.keys(teams).filter((id) => teams[id] === 1).sort();
  const two = Object.keys(teams).filter((id) => teams[id] === 2).sort();
  const offsets = describerOffsets(one.length, two.length, seed);
  const first = describingTeam(0);

  // Teams first, then the flag: a screen that saw `started` before the teams
  // existed would have nobody to describe and show an empty room.
  await set(ref(database, `blurt/${gameId}/teams`), teams);
  await set(ref(database, `blurt/${gameId}/play`), {
    round: 0,
    turn: 0,
    team: first,
    describer: describerFor(first === 1 ? one : two, 0, first === 1 ? offsets.one : offsets.two) ?? '',
    word: 0,
    state: 'ready',
    startedAt: null,
    endsAt: null,
    reason: null,
    scorer: null,
    one: 0,
    two: 0,
    finished: false,
  });
  await set(ref(database, `blurt/${gameId}/meta/started`), true);
}

/** Starts the clock, when the describer has the phone in their hand. */
export async function beginTurn(
  gameId: string,
  seconds: number,
  describer: string,
): Promise<void> {
  const now = Date.now();
  // `describer` is whoever actually tapped, which is normally the person the
  // rotation named — but not when that person has left the room and a team-mate
  // has picked the round up. Writing it here makes the stand-in stick rather
  // than leaving the word on an empty seat.
  await update(ref(database, `blurt/${gameId}/play`), {
    state: 'running',
    describer,
    startedAt: now,
    endsAt: now + seconds * 1000,
  });
}

/**
 * What the rotation needs: who is on each team, and the seed the starting
 * positions come from. Read before the transaction rather than inside it,
 * because the block has to be pure.
 */
async function rotation(gameId: string) {
  const seedSnapshot = await get(ref(database, `blurt/${gameId}/meta/seed`));
  const seed = seedSnapshot.val();
  if (typeof seed !== 'number') return null;

  const teamsSnapshot = await get(ref(database, `blurt/${gameId}/teams`));
  const teams = parseTeams((teamsSnapshot.val() as Record<string, number> | null) ?? null);
  // Who is actually in the room. The team lists keep their departed — that is
  // what lets them come back to the same side — so the turn has to be walked
  // forward past anybody who is not here.
  const playersSnapshot = await get(ref(database, `blurt/${gameId}/players`));
  const present = new Set(Object.keys((playersSnapshot.val() as Record<string, string> | null) ?? {}));
  const one = membersOf(1, teams);
  const two = membersOf(2, teams);
  return { one, two, present, offsets: describerOffsets(one.length, two.length, seed) };
}

/**
 * Moves the word on by one: the next person in the rotation, which is always
 * somebody on the other team, with the next word.
 *
 * The rotation is the game's spine — one member to the next, alternating sides,
 * in the same order every time round — so this is the only thing that decides
 * whose turn it is.
 */
function advance(
  play: BlurtPlay,
  one: string[],
  two: string[],
  offsets: { one: number; two: number },
  present: ReadonlySet<string>,
): BlurtPlay {
  const turn = play.turn + 1;
  const team = describingTeam(turn);
  const members = team === 1 ? one : two;
  const offset = team === 1 ? offsets.one : offsets.two;
  return {
    ...play,
    turn,
    team,
    word: play.word + 1,
    describer: describerFor(members, turn, offset, present) ?? '',
  };
}

/**
 * The team got the word and taps for the next one.
 *
 * This is what passes the word to the other team, and it deliberately does
 * **not** touch the clock: the timer belongs to the round, and a round is
 * however many words both teams get through before it stops.
 *
 * A transaction, so two taps landing together cannot skip a player.
 */
export async function passWord(gameId: string): Promise<boolean> {
  const spin = await rotation(gameId);
  if (!spin) return false;

  const result = await runTransaction(
    ref(database, `blurt/${gameId}/play`),
    (current: BlurtPlay | null) => {
      if (!current || current.state !== 'running') return; // abort
      return advance(current, spin.one, spin.two, spin.offsets, spin.present);
    },
  );
  return result.committed;
}

/**
 * Ends the round, once, whoever gets there first.
 *
 * The clock running out and somebody pressing BUZZ pay exactly the same way:
 * the team *not* holding the word takes the point. The transaction is what
 * makes that fair — a room that all shouts at once still scores once — and it
 * also sets the next round's rotation up behind the result.
 */
export async function endTurn(gameId: string, reason: EndReason): Promise<boolean> {
  const spin = await rotation(gameId);
  if (!spin) return false;

  const result = await runTransaction(
    ref(database, `blurt/${gameId}/play`),
    (current: BlurtPlay | null) => {
      if (!current || current.state === 'ended') return; // abort
      const scorer = scoringTeam(current.team);
      let next: BlurtPlay = {
        ...current,
        scorer,
        reason,
        one: current.one + (scorer === 1 ? 1 : 0),
        two: current.two + (scorer === 2 ? 1 : 0),
        startedAt: null,
        endsAt: null,
      };
      next.finished = winner(next.one, next.two, TARGET) !== null;
      next.state = 'ended';

      // The next round starts one further round the rotation, so the order
      // keeps moving rather than the same person being caught twice. A finished
      // game keeps the last round's shape; nobody plays it.
      if (!next.finished) next = advance(next, spin.one, spin.two, spin.offsets, spin.present);
      return next;
    },
  );
  return result.committed;
}

/**
 * Same room, same teams, scoreboard back to nil — and **the next word**, not the
 * first one again.
 *
 * The deck belongs to the room and is walked from end to end, so a table playing
 * several games in a sitting never sees a word twice. The rotation carries on
 * too, so the next person to describe is the one after whoever was holding it
 * when the last game ended.
 */
export async function playAgain(gameId: string): Promise<boolean> {
  const spin = await rotation(gameId);
  if (!spin) return false;

  const result = await runTransaction(
    ref(database, `blurt/${gameId}/play`),
    (current: BlurtPlay | null) => {
      if (!current) return; // abort
      const turn = current.turn + 1;
      const team = describingTeam(turn);
      const members = team === 1 ? spin.one : spin.two;
      const offset = team === 1 ? spin.offsets.one : spin.offsets.two;
      return {
        round: current.round + 1,
        turn,
        team,
        describer: describerFor(members, turn, offset) ?? '',
        word: current.word + 1,
        state: 'ready',
        startedAt: null,
        endsAt: null,
        reason: null,
        scorer: null,
        one: 0,
        two: 0,
        finished: false,
      } satisfies BlurtPlay;
    },
  );
  return result.committed;
}
