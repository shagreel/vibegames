import { describe, expect, it } from 'vitest';
import fixtures from '../games/ten/board.fixtures.json';
import {
  COLUMNS,
  ROWS,
  availableMatches,
  boardFromStacks,
  canMatch,
  hasMoves,
  isCleared,
  newBoard,
  remaining,
  remove,
  valueAt,
} from '../games/ten/engine';

/**
 * Vibe Ten's rules, and the one thing two platforms have to agree on: the deal.
 *
 * The Swift engine is the reference for the board — a room sends a seed and both
 * clients must deal the identical digits from it — so the fixture here is dumped
 * from `VibeTenBoard.swift` and checked by `VibeTenBoardTests.swift` too.
 */

const board = (columns: number[][]) => boardFromStacks(columns);

describe('what pairs', () => {
  it('takes equal digits and digits that add to ten', () => {
    const grid = board([
      [3, 7, 2, 2, 5, 9, 1, 4, 6],
      [3, 7, 2, 2, 5, 9, 1, 4, 6],
    ]);
    // 3 and 7 add to ten; the two 2s are equal.
    expect(canMatch(grid, { column: 0, row: 0 }, { column: 1, row: 1 })).toBe(true);
    expect(canMatch(grid, { column: 0, row: 2 }, { column: 1, row: 3 })).toBe(true);
    // 4 and 1 are next to each other but do not pair.
    expect(canMatch(grid, { column: 0, row: 7 }, { column: 1, row: 6 })).toBe(false);
  });

  it('needs a clear line: gaps count, digits in the way do not', () => {
    expect(canMatch(board([[3], [], [7]]), { column: 0, row: 0 }, { column: 2, row: 0 })).toBe(true);
    expect(canMatch(board([[3, 1], [9], [7]]), { column: 0, row: 0 }, { column: 2, row: 0 })).toBe(false);
  });

  it('counts diagonals', () => {
    expect(canMatch(board([[4], [0, 6]]), { column: 0, row: 0 }, { column: 1, row: 1 })).toBe(true);
  });

  it('has to be the same row, column or diagonal', () => {
    // 2 and 8 pair, but they are neither on a line nor next to each other.
    const grid = board([[2, 2], [2], [2, 8]]);
    expect(canMatch(grid, { column: 0, row: 0 }, { column: 2, row: 1 })).toBe(false);
  });
});

describe('taking a pair', () => {
  it('drops what was above it', () => {
    const grid = board([
      [3, 1, 2],
      [7, 4],
      [2],
    ]);
    const after = remove(grid, { column: 0, row: 0 }, { column: 1, row: 0 });
    expect(after).not.toBeNull();
    expect(valueAt(after!, { column: 0, row: 0 })).toBe(1);
    expect(valueAt(after!, { column: 0, row: 1 })).toBe(2);
    expect(remaining(after!)).toBe(4);
  });

  it('leaves the board alone when the pair is not allowed', () => {
    const grid = board([[2, 5], [6]]);
    expect(remove(grid, { column: 0, row: 0 }, { column: 1, row: 0 })).toBeNull();
  });

  it('knows when nothing is left', () => {
    const grid = board([[3], [7]]);
    expect(isCleared(grid)).toBe(false);
    const after = remove(grid, { column: 0, row: 0 }, { column: 1, row: 0 })!;
    expect(isCleared(after)).toBe(true);
    expect(hasMoves(after)).toBe(false);
  });

  it('knows a stuck board', () => {
    expect(hasMoves(board([[2], [5], [6]]))).toBe(false);
    expect(availableMatches(board([[2], [5], [6]]))).toHaveLength(0);
  });
});

describe('the deal', () => {
  it('is nine by eighteen of digits one to nine', () => {
    const grid = newBoard(42);
    expect(grid.stacks).toHaveLength(COLUMNS);
    grid.stacks.forEach((column) => {
      expect(column).toHaveLength(ROWS);
      column.forEach((value) => expect(value).toBeGreaterThanOrEqual(1));
      column.forEach((value) => expect(value).toBeLessThanOrEqual(9));
    });
    expect(remaining(grid)).toBe(COLUMNS * ROWS);
  });

  it('deals the same board from the same seed, and matches the app', () => {
    expect(newBoard(99).stacks).toEqual(newBoard(99).stacks);
    expect(newBoard(99).stacks).not.toEqual(newBoard(100).stacks);
    // Dumped from the Swift engine: the app and the browser must agree.
    expect(newBoard(1234).stacks).toEqual(fixtures['1234']);
  });
});
