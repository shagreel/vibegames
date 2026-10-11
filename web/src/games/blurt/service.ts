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
  DEFAULT_SECONDS,
  TARGET,
  describerFor,
  describerOffsets,
  describingTeam,
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
  turnSeconds: number;
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
  turnSeconds: DEFAULT_SECONDS,
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
      turnSeconds: typeof meta?.turnSeconds === 'number' ? meta.turnSeconds : DEFAULT_SECONDS,
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
  turnSeconds: number,
): Promise<void> {
  await set(ref(database, `blurt/${gameId}/meta`), {
    seed,
    creator: creatorName,
    createdAt: Date.now(),
    started: false,
    turnSeconds,
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
  turnSeconds: number,
): Promise<void> {
  await update(ref(database, `blurt/${gameId}/meta`), {
    turnSeconds,
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
  const one = Object.values(teams).filter((t) => t === 1).length;
  const two = Object.values(teams).filter((t) => t === 2).length;
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
export async function beginTurn(gameId: string, seconds: number): Promise<void> {
  const now = Date.now();
  await update(ref(database, `blurt/${gameId}/play`), {
    state: 'running',
    startedAt: now,
    endsAt: now + seconds * 1000,
  });
}

/** The next word. No score: describing earns nothing, it only passes the risk on. */
export async function advanceWord(gameId: string): Promise<void> {
  await runTransaction(ref(database, `blurt/${gameId}/play/word`), (current: number | null) =>
    (current ?? 0) + 1,
  );
}

/**
 * Ends the turn, once, whoever gets there first.
 *
 * Both endings pay the same way — the team that was *not* describing takes the
 * point — whether the clock ran out or the other team called a blurt. The
 * transaction is what makes that fair: two people pressing "they said it" at the
 * same moment score once, not twice.
 */
export async function endTurn(gameId: string, reason: EndReason): Promise<boolean> {
  const result = await runTransaction(
    ref(database, `blurt/${gameId}/play`),
    (current: BlurtPlay | null) => {
      if (!current || current.state === 'ended') return; // abort
      const scorer = scoringTeam(current.team);
      const next: BlurtPlay = {
        ...current,
        scorer,
        reason,
        one: current.one + (scorer === 1 ? 1 : 0),
        two: current.two + (scorer === 2 ? 1 : 0),
      };
      next.finished = winner(next.one, next.two, TARGET) !== null;
      next.state = 'ended';

      // Set the next turn up behind the result, so the handover screen already
      // knows whose phone to point at. A finished game keeps the last turn's
      // shape; nobody plays it.
      if (!next.finished) {
        next.turn = current.turn + 1;
        next.team = describingTeam(next.turn);
        next.word = current.word + 1;
        next.startedAt = null;
        next.endsAt = null;
      }
      return next;
    },
  );
  return result.committed;
}

/** Same room, same teams, fresh deck and scoreboard. */
export async function playAgain(gameId: string, seed: number): Promise<boolean> {
  const teamsSnapshot = await get(ref(database, `blurt/${gameId}/teams`));
  const teams = parseTeams((teamsSnapshot.val() as Record<string, number> | null) ?? null);
  const one = Object.keys(teams).filter((id) => teams[id] === 1).sort();
  const two = Object.keys(teams).filter((id) => teams[id] === 2).sort();

  const result = await runTransaction(
    ref(database, `blurt/${gameId}/play`),
    (current: BlurtPlay | null) => {
      if (!current) return; // abort
      const round = current.round + 1;
      const offsets = describerOffsets(one.length, two.length, (seed + round) >>> 0);
      const first = describingTeam(0);
      return {
        round,
        turn: 0,
        team: first,
        describer:
          describerFor(first === 1 ? one : two, 0, first === 1 ? offsets.one : offsets.two) ?? '',
        word: 0,
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
