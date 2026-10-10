import { get, onDisconnect, onValue, ref, remove, runTransaction, set } from 'firebase/database';
import { database } from '../../firebase';
import { FALLBACK_DIFFICULTY, type Difficulty } from './puzzle';

/**
 * A shared Sudoku game.
 *
 *     sudoku/{gameId}
 *       seed        1234567890
 *       difficulty  "easy"
 *       creator     "Alex"
 *       createdAt   1737052800000
 *       started     true
 *       winner      { name, timestamp }
 *       restartTime 1737052810000
 *       players/{playerId} { name, joinedAt }
 *
 * Only the *seed* is stored, never the board. Every device rebuilds the same
 * puzzle from it, so a game costs a handful of bytes rather than 81 numbers —
 * and the answer is never sitting in the database for a client to read. This is
 * the same schema the iOS app uses, so a browser and a phone can race together.
 */

export interface SudokuPlayer {
  id: string;
  name: string;
  joinedAt: number;
}

export interface SudokuWinner {
  name: string;
  timestamp: number;
}

export interface SudokuSnapshot {
  exists: boolean;
  seed: number | null;
  difficulty: Difficulty;
  creator: string | null;
  started: boolean;
  winner: SudokuWinner | null;
  restartTime: number | null;
  players: SudokuPlayer[];
}

export const EMPTY_SNAPSHOT: SudokuSnapshot = {
  exists: false,
  seed: null,
  difficulty: FALLBACK_DIFFICULTY,
  creator: null,
  started: false,
  winner: null,
  restartTime: null,
  players: [],
};

export function snapshotFrom(raw: unknown): SudokuSnapshot {
  if (typeof raw !== 'object' || raw === null) return EMPTY_SNAPSHOT;
  const object = raw as Record<string, unknown>;

  const rawSeed = object.seed;
  const seed =
    typeof rawSeed === 'number' && Number.isInteger(rawSeed) && rawSeed >= 0 && rawSeed <= 0xffffffff
      ? rawSeed
      : null;

  const rawDifficulty = object.difficulty;
  const difficulty: Difficulty =
    rawDifficulty === 'easy' || rawDifficulty === 'medium' || rawDifficulty === 'hard'
      ? rawDifficulty
      : FALLBACK_DIFFICULTY;

  const rawWinner = object.winner as Record<string, unknown> | undefined;
  const winner =
    rawWinner && typeof rawWinner.name === 'string'
      ? { name: rawWinner.name, timestamp: Number(rawWinner.timestamp) || 0 }
      : null;

  const rawPlayers = (object.players ?? {}) as Record<string, { name?: unknown; joinedAt?: unknown }>;
  const players: SudokuPlayer[] = Object.entries(rawPlayers)
    .filter(([, entry]) => entry && typeof entry.name === 'string')
    .map(([id, entry]) => ({
      id,
      name: String(entry.name),
      joinedAt: Number(entry.joinedAt) || 0,
    }))
    .sort((a, b) => a.joinedAt - b.joinedAt);

  return {
    exists: true,
    seed,
    difficulty,
    creator: typeof object.creator === 'string' ? object.creator : null,
    started: object.started === true,
    winner,
    restartTime: typeof object.restartTime === 'number' ? object.restartTime : null,
    players,
  };
}

// MARK: - Observing

export function observeGame(
  gameId: string,
  onChange: (snapshot: SudokuSnapshot) => void,
): () => void {
  return onValue(ref(database, `sudoku/${gameId}`), (snapshot) => {
    onChange(snapshotFrom(snapshot.val()));
  });
}

// MARK: - Writing

export async function createGame(
  gameId: string,
  seed: number,
  difficulty: Difficulty,
  creatorName: string,
  playerId: string,
): Promise<void> {
  // One write: the rules only allow the game node to be created while it does
  // not exist, so setting the seed first would leave the rest refused.
  await set(ref(database, `sudoku/${gameId}`), {
    seed,
    // The host picks; everyone in the game races the same board.
    difficulty,
    creator: creatorName,
    started: false,
    createdAt: Date.now(),
    players: { [playerId]: { name: creatorName, joinedAt: Date.now() } },
  });
  registerPresence(gameId, playerId);
}

export async function joinGame(gameId: string, playerId: string, name: string): Promise<void> {
  const existing = await get(ref(database, `sudoku/${gameId}/seed`));
  if (!existing.exists()) throw new Error('No game with that code');

  const playerRef = ref(database, `sudoku/${gameId}/players/${playerId}`);
  const player = await get(playerRef);
  if (!player.exists()) {
    await set(playerRef, { name, joinedAt: Date.now() });
  }
  registerPresence(gameId, playerId);
}

function registerPresence(gameId: string, playerId: string): void {
  onDisconnect(ref(database, `sudoku/${gameId}/players/${playerId}`)).remove();
}

export async function startGame(gameId: string): Promise<void> {
  await set(ref(database, `sudoku/${gameId}/started`), true);
}

/**
 * Records the winner, if nobody has already.
 *
 * A transaction rather than the read-then-write the app does: two phones
 * finishing on the same tick would otherwise both read "no winner" and both
 * write one, and the second would overwrite the first.
 */
export async function recordWinner(gameId: string, name: string): Promise<void> {
  await runTransaction(ref(database, `sudoku/${gameId}/winner`), (current) => {
    if (current) return; // Aborts: somebody got there first.
    return { name, timestamp: Date.now() };
  });
}

export async function beginRestart(gameId: string, seed: number, afterSeconds = 10): Promise<void> {
  // Order matters, and the rules enforce it: `seed` may only be rewritten while
  // a winner is on record, which is what stops a client quietly swapping the
  // board mid-round. So the new seed goes in first and the winner is cleared
  // afterwards, and the app does the same for the same reason.
  await set(ref(database, `sudoku/${gameId}/seed`), seed);
  await remove(ref(database, `sudoku/${gameId}/winner`)).catch(() => undefined);
  await set(ref(database, `sudoku/${gameId}/restartTime`), Date.now() + afterSeconds * 1000);
}

export async function clearRestartTime(gameId: string): Promise<void> {
  await remove(ref(database, `sudoku/${gameId}/restartTime`));
}

/** A seeded game id, short enough to read out loud. */
export function makeGameId(): string {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  const values = new Uint32Array(8);
  crypto.getRandomValues(values);
  return [...values].map((value) => alphabet[value % alphabet.length]).join('');
}
