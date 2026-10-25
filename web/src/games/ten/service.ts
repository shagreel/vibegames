import { get, onDisconnect, onValue, ref, remove, set, update } from 'firebase/database';
import { database } from '../../firebase';
import {
  COLUMN_OPTIONS,
  COLUMNS,
  DIFFICULTIES,
  ROW_OPTIONS,
  ROWS,
  type TenDifficulty,
} from './engine';

/**
 * A shared Vibe Ten room.
 *
 *   ten/{gameId}
 *     meta/                { seed, columns, rows, difficulty, creator, createdAt, started }
 *     players/{playerId}   { name, joinedAt }
 *     scores/{playerId}    { score, finishedAt }
 *
 * The board is never stored. It is a pure function of the seed and the shape, so
 * every client deals the identical digits and then plays its own game — one
 * player's pairs cannot appear on anybody else's board. The shape is the host's
 * choice, written once when the room is made; only the scores travel after that,
 * one write each, and the rules allow nothing else in a room.
 */

export interface TenScore {
  score: number;
  /** When that player ran out of moves, in milliseconds since the epoch. */
  finishedAt: number | null;
}

export interface TenSnapshot {
  exists: boolean;
  seed: number | null;
  /** The board's shape. Rooms made before the choice existed read as 9x18. */
  columns: number;
  rows: number;
  /** How hard the board is to take apart. Rooms without one read as medium. */
  difficulty: TenDifficulty;
  creator: string | null;
  started: boolean;
  players: Record<string, string>;
  scores: Record<string, TenScore>;
}

export const EMPTY_SNAPSHOT: TenSnapshot = {
  exists: false,
  seed: null,
  columns: COLUMNS,
  rows: ROWS,
  difficulty: 'medium',
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
  const rawColumns = typeof meta.columns === 'number' ? Math.trunc(meta.columns) : COLUMNS;
  const rawRows = typeof meta.rows === 'number' ? Math.trunc(meta.rows) : ROWS;
  const columns = (COLUMN_OPTIONS as readonly number[]).includes(rawColumns) ? rawColumns : COLUMNS;
  const rows = (ROW_OPTIONS as readonly number[]).includes(rawRows) ? rawRows : ROWS;
  const rawDifficulty = typeof meta.difficulty === 'string' ? meta.difficulty : 'medium';
  const difficulty = (DIFFICULTIES as readonly string[]).includes(rawDifficulty)
    ? (rawDifficulty as TenDifficulty)
    : 'medium';

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
    scores[id] = { score, finishedAt };
  });

  return {
    exists: true,
    seed: seedValue,
    columns,
    rows,
    difficulty,
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
}

/**
 * The rule: most pairs wins, and a tie goes to whoever ran out of moves first.
 * Somebody still playing sorts below anybody who has finished on the same
 * score, because they have not finished proving it.
 */
export function rank(standings: TenStanding[]): TenStanding[] {
  return [...standings].sort((a, b) => {
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
  columns: number,
  rows: number,
  difficulty: TenDifficulty,
  creatorName: string,
  playerId: string,
): Promise<void> {
  // One write: the rules only let a room be created while it does not exist, so
  // the meta and the creator's place go in together.
  await set(ref(database, `ten/${gameId}`), {
    meta: {
      seed,
      columns,
      rows,
      difficulty,
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
): Promise<void> {
  const path = `ten/${gameId}/scores/${playerId}`;
  if (finishedAt === null) {
    await update(ref(database, path), { score });
  } else {
    await update(ref(database, path), { score, finishedAt });
  }
}

/** Deals a new board to the whole room, and clears the scores with it. */
export async function beginRestart(gameId: string, seed: number): Promise<void> {
  await set(ref(database, `ten/${gameId}/meta/seed`), seed);
  await remove(ref(database, `ten/${gameId}/scores`)).catch(() => undefined);
}

/** A seed for a new board. Unsigned 32-bit, the same range the app uses. */
export function randomSeed(): number {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return values[0];
}
