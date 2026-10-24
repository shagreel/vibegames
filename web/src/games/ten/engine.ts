import { SeededGenerator, shuffle } from '../../lib/seeded';

/**
 * The Vibe Ten board: nine columns of digits, packed at the bottom.
 *
 * A column is a plain array, bottom first, which is the whole of the gravity
 * rule: take a digit out and the ones above are already one place lower. There
 * are never gaps inside a column.
 *
 * Mirrors `VibeTenBoard.swift`, including the deal: the digits are shuffled with
 * the same SplitMix64 generator the app uses, so a room's seed gives both
 * clients the identical 162 digits and neither can see the other's board.
 */

export const COLUMNS = 9;
export const ROWS = 18;

export interface Position {
  readonly column: number;
  readonly row: number;
}

export interface TenBoard {
  readonly seed: number;
  /** Nine columns, each bottom-first, at most `ROWS` digits. */
  readonly stacks: readonly (readonly number[])[];
}

/** Deals a board. Every column starts full: 9 × 18 digits, 18 of each. */
export function newBoard(seed: number): TenBoard {
  const generator = new SeededGenerator(seed);
  const digits: number[] = [];
  for (let value = 1; value <= 9; value += 1) {
    for (let copy = 0; copy < ROWS; copy += 1) digits.push(value);
  }
  shuffle(digits, generator);

  const stacks: number[][] = [];
  let index = 0;
  for (let column = 0; column < COLUMNS; column += 1) {
    stacks.push(digits.slice(index, index + ROWS));
    index += ROWS;
  }
  return { seed, stacks };
}

/** A board of an exact shape, for tests. */
export function boardFromStacks(stacks: number[][], seed = 0): TenBoard {
  return { seed, stacks: stacks.map((column) => column.slice(0, ROWS)) };
}

export function heightOf(board: TenBoard, column: number): number {
  return board.stacks[column]?.length ?? 0;
}

export function valueAt(board: TenBoard, position: Position): number | null {
  const stack = board.stacks[position.column];
  if (!stack || position.row < 0 || position.row >= stack.length) return null;
  return stack[position.row];
}

export function remaining(board: TenBoard): number {
  return board.stacks.reduce((total, column) => total + column.length, 0);
}

export function isCleared(board: TenBoard): boolean {
  return remaining(board) === 0;
}

/** Every cell that holds a digit, column by column from the bottom. */
export function cells(board: TenBoard): { position: Position; value: number }[] {
  const out: { position: Position; value: number }[] = [];
  board.stacks.forEach((column, columnIndex) => {
    column.forEach((value, row) => {
      out.push({ position: { column: columnIndex, row }, value });
    });
  });
  return out;
}

/** Two digits pair when they are equal or add up to ten. */
export function valuesPair(a: number, b: number): boolean {
  return a === b || a + b === 10;
}

/**
 * Whether a pair can be taken: the digits pair, and they sit on the same row,
 * column or diagonal with nothing between them.
 */
export function canMatch(board: TenBoard, a: Position, b: Position): boolean {
  if (a.column === b.column && a.row === b.row) return false;
  const first = valueAt(board, a);
  const second = valueAt(board, b);
  if (first === null || second === null) return false;
  if (!valuesPair(first, second)) return false;
  return hasClearLine(board, a, b);
}

export function hasClearLine(board: TenBoard, a: Position, b: Position): boolean {
  const down = b.row - a.row;
  const across = b.column - a.column;
  const steps = Math.max(Math.abs(down), Math.abs(across));
  if (steps === 0) return false;
  if (!(down === 0 || across === 0 || Math.abs(down) === Math.abs(across))) return false;

  const stepDown = down / steps;
  const stepAcross = across / steps;
  for (let step = 1; step < steps; step += 1) {
    const between = {
      column: a.column + step * stepAcross,
      row: a.row + step * stepDown,
    };
    if (valueAt(board, between) !== null) return false;
  }
  return true;
}

/** Every pair that can be taken right now. */
export function availableMatches(board: TenBoard): [Position, Position][] {
  const all = cells(board);
  const matches: [Position, Position][] = [];
  for (let first = 0; first < all.length; first += 1) {
    for (let second = first + 1; second < all.length; second += 1) {
      if (canMatch(board, all[first].position, all[second].position)) {
        matches.push([all[first].position, all[second].position]);
      }
    }
  }
  return matches;
}

export function hasMoves(board: TenBoard): boolean {
  return availableMatches(board).length > 0;
}

/** Takes a pair off the board, dropping whatever was above it. */
export function remove(board: TenBoard, a: Position, b: Position): TenBoard | null {
  if (!canMatch(board, a, b)) return null;

  const stacks = board.stacks.map((column) => [...column]);
  const ordered = [a, b].sort((first, second) => second.row - first.row);
  for (const position of ordered) {
    if (position.row < 0 || position.row >= stacks[position.column].length) continue;
    stacks[position.column].splice(position.row, 1);
  }
  return { seed: board.seed, stacks };
}
