import { get, onDisconnect, onValue, ref, remove, set, update } from 'firebase/database';
import { database } from '../../firebase';
import { ROWS_PER_ADD_OPTIONS, ROW_OPTIONS, ROWS, type TenMode } from './engine';

/**
 * A shared Vibe Ten room.
 *
 *   ten/{gameId}
 *     meta/                { seed, rows, wrap, mode, creator, createdAt, started }
 *     players/{playerId}   { name, joinedAt }
 *     scores/{playerId}    { score, finishedAt }
 *
 * The board is never stored. It is a pure function of the seed and the rules —
 * the rows, whether the rows join end to end, and how a taken pair leaves the
 * board — so every client deals the identical digits and plays them the same
 * way. Those rules are the host's choice, written once when the room is made;
 * only the scores travel after that, one write each, and the rules allow nothing
 * else in a room. The board is always nine columns.
 */

export interface TenScore {
  score: number;
  /** When that player ran out of moves, in milliseconds since the epoch. */
  finishedAt: number | null;
  /** When that player cleared the board. The first clear wins. */
  clearedAt: number | null;
}

export interface TenSnapshot {
  exists: boolean;
  seed: number | null;
  /** How many rows start full of digits. The board always has room for
      eighteen; rooms made before the choice existed read as a full start. */
  rows: number;
  /** How many rows a press of the new-row offer reveals, the host's rule. */
  rowsPerAdd: number;
  /** Whether the rows join end to end. A room rule, so every device plays the
      same board by the same lines. */
  wrapRows: boolean;
  /** How a taken pair leaves the board, also part of the room's rules. */
  mode: TenMode;
  creator: string | null;
  started: boolean;
  players: Record<string, string>;
  scores: Record<string, TenScore>;
}

export const EMPTY_SNAPSHOT: TenSnapshot = {
  exists: false,
  seed: null,
  rows: ROWS,
  rowsPerAdd: ROWS_PER_ADD_OPTIONS[0],
  wrapRows: false,
  mode: 'remove',
  creator: null,
  started: false,
  players: {},
  scores: {},
};

export function snapshotFrom(raw: unknown): TenSnapshot {
  if (!raw || typeof raw !== 'object') return EMPTY_SNAPSHOT;
  const value = raw as Record<string, unknown>;

  const meta = (value.meta ?? {}) as Record<string, unknown>;
  const seedValue = typeof meta.seed === 'number' ? Math.trunc(meta.seed) : null;
  const rawRows = typeof meta.rows === 'number' ? Math.trunc(meta.rows) : ROWS;
  const rows = (ROW_OPTIONS as readonly number[]).includes(rawRows) ? rawRows : ROWS;
  const rawPerAdd = typeof meta.rowsPerAdd === 'number'
    ? Math.trunc(meta.rowsPerAdd)
    : ROWS_PER_ADD_OPTIONS[0];
  const rowsPerAdd = (ROWS_PER_ADD_OPTIONS as readonly number[]).includes(rawPerAdd)
    ? rawPerAdd
    : ROWS_PER_ADD_OPTIONS[0];
  const wrapRows = meta.wrap === true;
  const rawMode = typeof meta.mode === 'string' ? meta.mode : 'remove';
  const mode: TenMode = rawMode === 'dim' ? 'dim' : 'remove';

  const players: Record<string, string> = {};
  const rawPlayers = (value.players ?? {}) as Record<string, unknown>;
  Object.entries(rawPlayers).forEach(([id, entry]) => {
    const name = (entry as Record<string, unknown> | null)?.name;
    if (typeof name === 'string') players[id] = name;
  });

  const scores: Record<string, TenScore> = {};
  const rawScores = (value.scores ?? {}) as Record<string, unknown>;
  Object.entries(rawScores).forEach(([id, entry]) => {
    const record = entry as Record<string, unknown> | null;
    const score = typeof record?.score === 'number' ? Math.trunc(record.score) : 0;
    const finishedAt = typeof record?.finishedAt === 'number' ? record.finishedAt : null;
    const clearedAt = typeof record?.clearedAt === 'number' ? record.clearedAt : null;
    scores[id] = { score, finishedAt, clearedAt };
  });

  return {
    exists: true,
    seed: seedValue,
    rows,
    rowsPerAdd,
    wrapRows,
    mode,
    creator: typeof meta.creator === 'string' ? meta.creator : null,
    started: meta.started === true,
    players,
    scores,
  };
}

export interface TenStanding {
  id: string;
  name: string;
  score: number;
  finishedAt: number | null;
  clearedAt: number | null;
}

/**
 * The rule: the first player to clear the board wins, so anybody who has
 * cleared sorts above anybody who has not, earliest first. The pairs are the
 * running total behind that.
 */
export function rank(standings: TenStanding[]): TenStanding[] {
  return [...standings].sort((a, b) => {
    if (a.clearedAt !== null && b.clearedAt !== null && a.clearedAt !== b.clearedAt) {
      return a.clearedAt - b.clearedAt;
    }
    if (a.clearedAt !== null && b.clearedAt === null) return -1;
    if (a.clearedAt === null && b.clearedAt !== null) return 1;
    if (a.score !== b.score) return b.score - a.score;
    if (a.finishedAt !== null && b.finishedAt !== null) return a.finishedAt - b.finishedAt;
    if (a.finishedAt !== null) return -1;
    if (b.finishedAt !== null) return 1;
    return a.name.localeCompare(b.name);
  });
}

// MARK: - Observing

export function observeGame(gameId: string, onChange: (snapshot: TenSnapshot) => void): () => void {
  return onValue(ref(database, `ten/${gameId}`), (snapshot) => {
    onChange(snapshotFrom(snapshot.val()));
  });
}

// MARK: - Writing

export async function createGame(
  gameId: string,
  seed: number,
  rows: number,
  rowsPerAdd: number,
  wrapRows: boolean,
  mode: TenMode,
  creatorName: string,
  playerId: string,
): Promise<void> {
  // One write: the rules only let a room be created while it does not exist, so
  // the meta and the creator's place go in together.
  const perAdd = (ROWS_PER_ADD_OPTIONS as readonly number[]).includes(rowsPerAdd)
    ? rowsPerAdd
    : ROWS_PER_ADD_OPTIONS[0];
  await set(ref(database, `ten/${gameId}`), {
    meta: {
      seed,
      rows,
      rowsPerAdd: perAdd,
      wrap: wrapRows,
      mode,
      creator: creatorName,
      createdAt: Date.now(),
      started: false,
    },
    players: { [playerId]: { name: creatorName, joinedAt: Date.now() } },
  });
  registerPresence(gameId, playerId);
}

export async function joinGame(gameId: string, playerId: string, name: string): Promise<void> {
  const room = await get(ref(database, `ten/${gameId}/meta`));
  if (!room.exists()) throw new Error('No game with that code');

  const playerRef = ref(database, `ten/${gameId}/players/${playerId}`);
  const player = await get(playerRef);
  if (!player.exists()) {
    await set(playerRef, { name, joinedAt: Date.now() });
  }
  registerPresence(gameId, playerId);
}

function registerPresence(gameId: string, playerId: string): void {
  onDisconnect(ref(database, `ten/${gameId}/players/${playerId}`)).remove();
}

/** Takes the player off the roster now, rather than when the socket drops. */
export function removePresence(gameId: string, playerId: string): void {
  void remove(ref(database, `ten/${gameId}/players/${playerId}`)).catch(() => undefined);
}

export async function startGame(gameId: string): Promise<void> {
  await set(ref(database, `ten/${gameId}/meta/started`), true);
}

export async function recordScore(
  gameId: string,
  playerId: string,
  score: number,
  finishedAt: number | null,
  clearedAt: number | null,
): Promise<void> {
  const path = `ten/${gameId}/scores/${playerId}`;
  const value: Record<string, number> = { score };
  if (finishedAt !== null) value.finishedAt = finishedAt;
  // Written once and never removed: a later score update without it must not
  // take the win away.
  if (clearedAt !== null) value.clearedAt = clearedAt;
  await update(ref(database, path), value);
}

/** Deals a new board to the whole room, and clears the scores with it. */
export async function beginRestart(gameId: string, seed: number): Promise<void> {
  // The scores go first, then the seed: the other order can show a client the
  // new board with the old round's winner still in it, which ends the round
  // before it has started.
  await remove(ref(database, `ten/${gameId}/scores`)).catch(() => undefined);
  await set(ref(database, `ten/${gameId}/meta/seed`), seed);
}

/** A seed for a new board. Unsigned 32-bit, the same range the app uses. */
export function randomSeed(): number {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return values[0];
}
