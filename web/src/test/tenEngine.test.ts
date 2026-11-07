import { describe, expect, it } from 'vitest';
import fixtures from '../games/ten/board.fixtures.json';
import {
  COLUMNS,
  PAIR_OPTIONS,
  ROWS,
  ROW_OPTIONS,
  type TenBoard,
  type TenCell,
  addRows,
  availableMatches,
  boardFromStacks,
  canAddRow,
  canMatch,
  deal,
  heightOf,
  hasMoves,
  isCleared,
  isDimmed,
  newBoard,
  pairChoices,
  remaining,
  remove,
  take,
  valueAt,
  values,
  valuesPair,
} from '../games/ten/engine';

/**
 * Vibe Ten's rules, and the one thing two platforms have to agree on: the deal.
 *
 * The Swift engine is the reference for the board — a room sends a seed and both
 * clients must deal the identical digits from it — so the fixtures here are
 * dumped from `VibeTenBoard.swift` and checked by `VibeTenBoardTests.swift` too.
 */

const board = (
  columns: number[][],
  seed = 0,
  shape: { columns?: number; rows?: number; dealtRows?: number } = {},
) => boardFromStacks(columns, seed, shape);

const cell = (value: number): TenCell => ({ value, dimmed: false });

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
      column.forEach((entry) => expect(entry.value).toBeGreaterThanOrEqual(1));
      column.forEach((entry) => expect(entry.value).toBeLessThanOrEqual(9));
    });
    expect(remaining(grid)).toBe(COLUMNS * ROWS);
  });

  it('deals the same board from the same seed, and matches the app', () => {
    expect(newBoard(99).stacks).toEqual(newBoard(99).stacks);
    expect(newBoard(99).stacks).not.toEqual(newBoard(100).stacks);
    // Dumped from the Swift engine: the app and the browser must agree.
    for (const [name, expected] of Object.entries(fixtures)) {
      const [seed, shape] = name.split('-');
      const [columns, rows] = shape.split('x').map(Number);
      expect(values(newBoard(Number(seed), columns, rows))).toEqual(expected);
    }
  });

  it('draws valid pairs and lays their digits out', () => {
    for (const seed of [1, 7, 1234, 999, 424242]) {
      const count = (COLUMNS * ROWS) / 2;
      const pairs = pairChoices(seed, count);
      expect(pairs).toHaveLength(count);
      pairs.forEach(([first, second]) => expect(valuesPair(first, second)).toBe(true));

      const full = deal(seed, COLUMNS, ROWS).map((column) => column.map((entry) => entry.value));
      const digits = full.flat().sort((a, b) => a - b);
      const dealt = pairs
        .reduce<number[]>((all, [first, second]) => all.concat([first, second]), [])
        .sort((a, b) => a - b);
      expect(digits).toEqual(dealt);

      // A starting board is the top of that whole deal, not a shorter deal of
      // its own: the rows underneath are already drawn and wait face down.
      for (const rows of ROW_OPTIONS) {
        expect(values(newBoard(seed, COLUMNS, rows))).toEqual(
          full.map((column) => column.slice(0, rows)),
        );
      }
    }
  });

  it('shuffles the digits rather than laying the pairs down in order', () => {
    const pairs = pairChoices(1234, (9 * 18) / 2);
    const dealt = pairs.reduce<number[]>((all, [first, second]) => all.concat([first, second]), []);
    expect(values(newBoard(1234)).flat()).not.toEqual(dealt);
  });

  it('draws from a pool with both kinds of pair in it', () => {
    expect(PAIR_OPTIONS.some(([first, second]) => first === second)).toBe(true);
    expect(PAIR_OPTIONS.some(([first, second]) => first + second === 10)).toBe(true);
    PAIR_OPTIONS.forEach(([first, second]) => expect(valuesPair(first, second)).toBe(true));
  });
});

describe('dimming', () => {
  it('dims a pair instead of removing it', () => {
    const grid = board([
      [3, 1],
      [7],
    ]);
    const moved = take(grid, { column: 0, row: 0 }, { column: 1, row: 0 }, 'dim');
    expect(moved).not.toBeNull();
    expect(moved!.move.rowsCleared).toEqual([]);
    expect(valueAt(moved!.board, { column: 0, row: 0 })).toBe(3);
    expect(isDimmed(moved!.board, { column: 0, row: 0 })).toBe(true);
    expect(isDimmed(moved!.board, { column: 1, row: 0 })).toBe(true);
    expect(remaining(moved!.board)).toBe(1);
  });

  it('lets a line pass through a dimmed digit', () => {
    const grid = board([
      [3, 9],
      [9, 7],
      [7, 1],
    ]);
    expect(canMatch(grid, { column: 0, row: 0 }, { column: 2, row: 0 })).toBe(false);
    const after = take(grid, { column: 1, row: 0 }, { column: 2, row: 1 }, 'dim')!.board;
    expect(canMatch(after, { column: 0, row: 0 }, { column: 2, row: 0 })).toBe(true);
  });

  it('clears a row once every digit in it is dimmed', () => {
    let grid = board([
      [1, 9],
      [9, 8],
      [2, 7],
      [8, 6],
      [3, 5],
      [7, 4],
      [4, 3],
      [6, 5],
      [5, 1],
    ]);
    const pairs: [number, number][] = [
      [0, 1],
      [2, 3],
      [4, 5],
      [6, 7],
    ];
    for (const [left, right] of pairs) {
      grid = take(grid, { column: left, row: 0 }, { column: right, row: 0 }, 'dim')!.board;
    }
    expect(grid.stacks[0]).toHaveLength(2);

    const moved = take(grid, { column: 8, row: 0 }, { column: 7, row: 1 }, 'dim')!;
    expect(moved.move.rowsCleared).toEqual([0]);
    expect(moved.board.stacks[0]).toHaveLength(1);
    expect(valueAt(moved.board, { column: 0, row: 0 })).toBe(9);
  });

  it('empties the board when both rows finish together', () => {
    let grid = board([
      [1, 9],
      [2, 8],
      [3, 7],
      [4, 6],
      [5, 5],
      [6, 4],
      [7, 3],
      [8, 2],
      [9, 1],
    ]);
    for (let column = 0; column < COLUMNS; column += 1) {
      grid = take(grid, { column, row: 0 }, { column, row: 1 }, 'dim')!.board;
    }
    expect(isCleared(grid)).toBe(true);
    expect(remaining(grid)).toBe(0);
  });
});

describe('adding rows', () => {
  /** A multiset is whole pairs when the 5s are even and each complement pair
   * (1/9, 2/8, 3/7, 4/6) has an even total. */
  const canBePaired = (values: number[]) => {
    const counts = Array.from({ length: 10 }, () => 0);
    values.forEach((value) => { counts[value] += 1; });
    if (counts[5] % 2 !== 0) return false;
    for (let digit = 1; digit <= 4; digit += 1) {
      if ((counts[digit] + counts[10 - digit]) % 2 !== 0) return false;
    }
    return true;
  };

  const addedRows = (grid: TenBoard, count: number) => {
    const out: number[] = [];
    for (let column = 0; column < COLUMNS; column += 1) {
      out.push(...grid.stacks[column].slice(-count).map((entry) => entry.value));
    }
    return out;
  };

  it('brings a partner for every digit left on the board', () => {
    // 5, 3, 9 and 2, with nothing to take. None of them pair with another
    // leftover, so a perfect pairing of the leftovers and the press proves the
    // press brought a partner for each.
    const grid = boardFromStacks([[5], [3], [9], [2]], 1234);
    const next = addRows(grid, 2)!;
    const added = addedRows(next, 2);
    expect(added).toHaveLength(18);
    expect(canBePaired([5, 3, 9, 2, ...added])).toBe(true);
    expect(heightOf(next, 0)).toBe(3);
    expect(next.dealtRows).toBe(3);
  });

  it('is deterministic from the same board and seed', () => {
    const first = addRows(boardFromStacks([[5], [3], [9], [2]], 99), 2)!;
    const second = addRows(boardFromStacks([[5], [3], [9], [2]], 99), 2)!;
    expect(values(first)).toEqual(values(second));
  });

  it('needs room for both rows of a press', () => {
    const grid = boardFromStacks(
      Array.from({ length: COLUMNS }, () => Array.from({ length: 17 }, () => 1)),
      0,
      { rows: 18 },
    );
    expect(canAddRow(grid)).toBe(true);
    expect(addRows(grid, 2)).toBeNull();
  });

  it('is refused on a full grid', () => {
    expect(canAddRow(newBoard(7))).toBe(false);
    expect(addRows(newBoard(7), 2)).toBeNull();
  });

});

describe('the board hangs from the top', () => {
  it('closes a gap upward', () => {
    const grid = board([[3, 1, 2], [7, 4], [2]]);
    const after = take(grid, { column: 0, row: 0 }, { column: 1, row: 0 }, 'remove')!.board;
    expect(valueAt(after, { column: 0, row: 0 })).toBe(1);
    expect(valueAt(after, { column: 0, row: 1 })).toBe(2);
    expect(heightOf(after, 1)).toBe(1);
  });
});

describe('the rows joining end to end', () => {
  const columns = [[7, 5], [], [], [], [], [], [], [], [5]];

  it('lets the end of a row pair with the start of the next', () => {
    const wrapped = boardFromStacks(columns, 0, { columns: 9, rows: 2, wrapRows: true });
    expect(canMatch(wrapped, { column: 8, row: 0 }, { column: 0, row: 1 })).toBe(true);

    const plain = boardFromStacks(columns, 0, { columns: 9, rows: 2 });
    expect(canMatch(plain, { column: 8, row: 0 }, { column: 0, row: 1 })).toBe(false);
  });

  it('reaches past a taken square', () => {
    const stacks: TenCell[][] = [
      [cell(7), cell(9)],
      [cell(2), cell(5)],
      [],
      [],
      [],
      [],
      [],
      [],
      [cell(5)],
    ];
    stacks[0][1] = { value: 9, dimmed: true };
    const wrapped = { seed: 0, columns: 9, rows: 2, dealtRows: 2, wrapRows: true, stacks };
    expect(canMatch(wrapped, { column: 8, row: 0 }, { column: 1, row: 1 })).toBe(true);

    const blocked = boardFromStacks(columns, 0, { columns: 9, rows: 2, wrapRows: true });
    // The 5 sits in column 0 row 1 there, and nothing is between it and the 5
    // at the end of the row above.
    expect(canMatch(blocked, { column: 8, row: 0 }, { column: 0, row: 1 })).toBe(true);
  });

  it('is off unless it is asked for', () => {
    expect(newBoard(1).wrapRows).toBe(false);
  });
});
