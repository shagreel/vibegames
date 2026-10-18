import {
  get,
  onDisconnect,
  onValue,
  ref,
  remove,
  runTransaction,
  set,
  type Unsubscribe,
} from 'firebase/database';
import { shortId } from '../../lib/shortId';
import { database } from '../../firebase';
import { appliedTakes, replay, wouldFormTrioByIds } from './engine';

/**
 * A shared Vibe Pairings game.
 *
 *     trio/{gameId}
 *       meta/       seed, creator, createdAt, started, restartTime, hints
 *       players/    {shortId}: true        — presence, cleared on disconnect
 *       taken/      {cardId}: { seq, by, name }
 *
 * The board itself is never stored. It is a pure function of the seed and the
 * takes, so every device rebuilds the identical table by replaying them in the
 * order the server accepted them. This is the same schema the iOS app uses, so a
 * browser and a phone can sit in the same game.
 */

export interface TrioTake {
  seq: number;
  by: string;
  name: string;
  cardIds: number[];
}

export interface TrioSnapshot {
  exists: boolean;
  seed: number | null;
  creator: string | null;
  started: boolean;
  /**
   * Whether the room plays with hints.
   *
   * A race with a hint button is a different game — one player can see a
   * pairing and the others cannot — so it is the host's choice for the room,
   * made before the start, and everyone sees the same answer.
   */
  hints: boolean;
  restartTime: number | null;
  /** How many people are here. Only the number is wanted — never a list. */
  playerCount: number;
  /** Accepted takes, oldest first. */
  takes: TrioTake[];
}

export const EMPTY_SNAPSHOT: TrioSnapshot = {
  exists: false,
  seed: null,
  creator: null,
  started: false,
  hints: false,
  restartTime: null,
  playerCount: 0,
  takes: [],
};

export interface TakenEntry {
  seq: number;
  by: string;
  name: string;
}

/** Three cards sharing a sequence number are one take. */
export function takesFrom(entries: Record<string, TakenEntry> | null): TrioTake[] {
  const grouped = new Map<number, TrioTake>();

  for (const [key, entry] of Object.entries(entries ?? {})) {
    const cardId = Number(key);
    if (!Number.isInteger(cardId) || !entry) continue;
    const group = grouped.get(entry.seq) ?? {
      seq: entry.seq,
      by: entry.by,
      name: entry.name,
      cardIds: [],
    };
    group.cardIds.push(cardId);
    grouped.set(entry.seq, group);
  }

  return [...grouped.values()]
    .map((take) => ({ ...take, cardIds: [...take.cardIds].sort((a, b) => a - b) }))
    .sort((a, b) => a.seq - b.seq);
}

/**
 * A short, game-scoped id — FNV-1a over player id and game id, the same
 * derivation the iOS app uses.
 *
 * The browser id is long; at a hundred players that length is paid on every
 * presence entry and every take. Eight characters is plenty for one game, and
 * different games give different ids.
 */
export { shortId };

// MARK: - Observing

export interface TrioObservation {
  snapshot: TrioSnapshot;
  unsubscribe: () => void;
}

export function observeGame(
  gameId: string,
  playerId: string,
  onChange: (snapshot: TrioSnapshot) => void,
): () => void {

  // Held and rebuilt in parts: `meta` changes about four times a game, while
  // `players` and `taken` only ever grow. One `.value` listener on the whole
  // game would re-send everything on every take.
  let meta: Record<string, unknown> | null = null;
  let taken: Record<string, TakenEntry> | null = null;
  let playerCount = 0;

  const emit = () => {
    const rawSeed = meta?.seed;
    onChange({
      exists: meta !== null,
      seed: typeof rawSeed === 'number' ? rawSeed : null,
      creator: typeof meta?.creator === 'string' ? meta.creator : null,
      started: meta?.started === true,
      hints: meta?.hints === true,
      restartTime: typeof meta?.restartTime === 'number' ? meta.restartTime : null,
      playerCount,
      takes: takesFrom(taken),
    });
  };

  const unsubscribers: Unsubscribe[] = [];

  unsubscribers.push(
    onValue(ref(database, `trio/${gameId}/meta`), (snapshot) => {
      meta = snapshot.val();
      emit();
    }),
  );

  const playersRef = ref(database, `trio/${gameId}/players`);
  const recount = (players: Record<string, unknown> | null) => {
    playerCount = players ? Object.keys(players).length : 0;
  };
  unsubscribers.push(
    onValue(playersRef, (snapshot) => {
      recount(snapshot.val());
      emit();
    }),
  );

  // `child_added`/`child_removed` rather than `.value` for the takes: the node
  // only grows, and at a hundred players `.value` would re-send the lot on every
  // single take.
  unsubscribers.push(
    onValue(ref(database, `trio/${gameId}/taken`), (snapshot) => {
      taken = snapshot.val();
      emit();
    }),
  );

  // Presence, and presence again on every reconnect.
  //
  // `onDisconnect` removes a player when the socket drops, so a laptop lid or a
  // train tunnel takes them off the roster — and nothing put them back: the
  // room went on saying "1 player" while the person was looking at the table.
  void ensurePresent(gameId, playerId).catch(() => undefined);
  unsubscribers.push(
    onValue(ref(database, '.info/connected'), (snapshot) => {
      if (snapshot.val() !== true) return;
      void ensurePresent(gameId, playerId).catch(() => undefined);
    }),
  );

  return () => unsubscribers.forEach((off) => off());
}

// MARK: - Writing

async function ensurePresent(gameId: string, playerId: string): Promise<void> {
  const id = shortId(playerId, gameId);
  const playerRef = ref(database, `trio/${gameId}/players/${id}`);

  const existing = await get(playerRef);
  if (existing.exists()) {
    onDisconnect(playerRef).remove();
    return;
  }

  await set(playerRef, true);
  // RTDB has no decrement and `onDisconnect` can only set or remove, which is
  // why the count is the number of live entries rather than a number.
  onDisconnect(playerRef).remove();
}

export async function createGame(
  gameId: string,
  seed: number,
  creatorName: string,
  playerId: string,
): Promise<void> {
  // The rules only allow writing the game node while it does not exist, so this
  // is one write — meta first would leave the node created and the rest refused.
  await set(ref(database, `trio/${gameId}/meta`), {
    seed,
    creator: creatorName,
    createdAt: Date.now(),
    started: false,
    // Off, which is what a race has always been. The host can turn it on
    // before anybody starts.
    hints: false,
  });
  await ensurePresent(gameId, playerId);
}

export async function joinGame(gameId: string, playerId: string): Promise<void> {
  const snapshot = await get(ref(database, `trio/${gameId}/meta`));
  if (!snapshot.exists()) throw new Error('No game with that code');

  if (snapshot.val()?.restartTime) {
    // A stale countdown from a finished round should not greet a new arrival.
    await remove(ref(database, `trio/${gameId}/meta/restartTime`)).catch(() => undefined);
  }
  await ensurePresent(gameId, playerId);
}

/** Turns hints on or off for the whole room. The host's to write, before the start. */
export async function setHints(gameId: string, enabled: boolean): Promise<void> {
  await set(ref(database, `trio/${gameId}/meta/hints`), enabled);
}

export async function startGame(gameId: string): Promise<void> {
  await set(ref(database, `trio/${gameId}/meta/started`), true);
}

export type ClaimOutcome = 'won' | 'taken' | 'failed' | 'stale';

/**
 * Claims three cards, if they are still there.
 *
 * This is the whole of the shared table. The block runs on this device — there
 * is no backend service — but the server decides whether to keep the result: it
 * accepts only if the value it handed the block is still current, and makes
 * everyone else run again against the new one. So the order takes are accepted
 * in is the server's, not a browser clock's.
 *
 * The block replays the game to check the claim properly, so a claim that lost
 * the race, or names cards that are no longer together, is aborted.
 */
export async function claimTrio(
  gameId: string,
  seed: number,
  cardIds: number[],
  playerId: string,
  name: string,
): Promise<ClaimOutcome> {
  const by = shortId(playerId, gameId);
  const takenRef = ref(database, `trio/${gameId}/taken`);

  try {
    // A board rebuilt from an old round would validate its cards against that
    // round's table and write them into this one — a take nobody can see, which
    // then counts on the scoreboard. Check the room is still the round this
    // board was dealt for.
    const room = await get(ref(database, `trio/${gameId}/meta/seed`));
    if (room.val() !== seed) return 'stale';

    const result = await runTransaction(takenRef, (current: Record<string, TakenEntry> | null) => {
      const entries = current ?? {};
      const takes = takesFrom(entries);
      const table = replay(seed, takes.map((take) => take.cardIds));

      if (!wouldFormTrioByIds(table, cardIds)) {
        return; // Aborts: the cards are not all still there, or not a trio.
      }

      const next = takes.reduce((max, take) => Math.max(max, take.seq), 0) + 1;
      const updated = { ...entries };
      for (const id of cardIds) updated[String(id)] = { seq: next, by, name };
      return updated;
    });

    return result.committed ? 'won' : 'taken';
  } catch (error) {
    console.error('Trio claim failed:', error);
    return 'failed';
  }
}

export async function beginRestart(
  gameId: string,
  seed: number,
  afterSeconds = 10,
): Promise<void> {
  await remove(ref(database, `trio/${gameId}/taken`));
  await set(ref(database, `trio/${gameId}/meta/seed`), seed);
  await set(ref(database, `trio/${gameId}/meta/restartTime`), Date.now() + afterSeconds * 1000);
}

export async function clearRestartTime(gameId: string): Promise<void> {
  await remove(ref(database, `trio/${gameId}/meta/restartTime`));
}

/** Names and scores, derived from the takes — never stored. */
/**
 * Every player's score: the takes that actually happened.
 *
 * Not every recorded take is one: a claim that lost a race is written too, and
 * counting those made the scoreboard disagree with the deck — "twelve pairings
 * and three, with fifty-one cards left" is forty-five cards taken out of a round
 * where thirty had been.
 */
export function scoresFrom(snapshot: TrioSnapshot): Map<string, number> {
  const applied = appliedTakes(snapshot.seed ?? 0, snapshot.takes.map((take) => take.cardIds));
  const scores = new Map<string, number>();
  snapshot.takes.forEach((take, index) => {
    if (!applied.has(index)) return;
    scores.set(take.by, (scores.get(take.by) ?? 0) + 1);
  });
  return scores;
}

export function nameOf(snapshot: TrioSnapshot, playerId: string): string | null {
  for (let i = snapshot.takes.length - 1; i >= 0; i -= 1) {
    if (snapshot.takes[i].by === playerId) return snapshot.takes[i].name;
  }
  return null;
}

/** A seeded game id, short enough to read out loud. */
export { makeGameCode } from '../../lib/gameCode';

export function randomSeed(): number {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return values[0];
}
