import { describe, expect, it } from 'vitest';
import fixtures from '../games/ten/board.fixtures.json';
import {
  COLUMNS,
  COLUMN_OPTIONS,
  type TenCell,
  ROWS,
  ROW_OPTIONS,
  addRow,
  availableMatches,
  boardFromStacks,
  DIFFICULTIES,
  canAddRow,
  canMatch,
  heightOf,
  plan,
  type TenDifficulty,
  hasMoves,
  isCleared,
  isDimmed,
  newBoard,
  remaining,
  remove,
  take,
  valueAt,
  values,
} from '../games/ten/engine';

/**
 * Vibe Ten's rules, and the one thing two platforms have to agree on: the deal.
 *
 * The Swift engine is the reference for the board — a room sends a seed and both
 * clients must deal the identical digits from it — so the fixture here is dumped
 * from `VibeTenBoard.swift` and checked by `VibeTenBoardTests.swift` too.
 */

const board = (
  columns: number[][],
  seed = 0,
  shape: { columns?: number; rows?: number } = {},
) => boardFromStacks(columns, seed, shape);

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
      const [seed, shape, level, extra] = name.split('-');
      const [columns, rows] = shape.split('x').map(Number);
      expect(values(newBoard(Number(seed), columns, rows, rows, extra === 'wrap',
        level as TenDifficulty))).toEqual(expected);
    }
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

describe('adding a row', () => {
  it('hangs the new row under the digits without moving them', () => {
    const grid = board([[1], [2], [3], [4], [5], [6], [7], [8], [9]]);
    expect(canAddRow(grid)).toBe(true);
    const next = addRow(grid, [9, 8, 7, 6, 5, 4, 3, 2, 1])!;
    expect(valueAt(next, { column: 0, row: 0 })).toBe(1);
    expect(valueAt(next, { column: 0, row: 1 })).toBe(9);
  });

  it('is refused while a column reaches the top row', () => {
    expect(canAddRow(newBoard(7))).toBe(false);
    expect(addRow(newBoard(7), Array(COLUMNS).fill(1))).toBeNull();
  });
});

describe('the shape', () => {
  it('deals a full grid in every shape on offer', () => {
    for (const columns of COLUMN_OPTIONS) {
      for (const rows of ROW_OPTIONS) {
        const grid = newBoard(31337, columns, rows);
        expect(grid.columns).toBe(columns);
        expect(grid.rows).toBe(rows);
        expect(grid.stacks).toHaveLength(columns);
        grid.stacks.forEach((column) => {
          expect(column).toHaveLength(rows);
          column.forEach((entry) => {
            expect(entry.value).toBeGreaterThanOrEqual(1);
            expect(entry.value).toBeLessThanOrEqual(9);
          });
        });
        expect(remaining(grid)).toBe(columns * rows);
      }
    }
  });

  it('spreads nine values as evenly as the shape allows', () => {
    for (const columns of COLUMN_OPTIONS) {
      for (const rows of ROW_OPTIONS) {
        const counts = new Map<number, number>();
        newBoard(99, columns, rows).stacks.flat().forEach((entry) => {
          counts.set(entry.value, (counts.get(entry.value) ?? 0) + 1);
        });
        expect(counts.size).toBe(9);
        const values = [...counts.values()];
        expect(Math.max(...values) - Math.min(...values)).toBeLessThanOrEqual(1);
      }
    }
  });

  it('is part of the deal', () => {
    expect(values(newBoard(7, 6, 12))).toEqual(values(newBoard(7, 6, 12)));
    expect(values(newBoard(7, 6, 12))).not.toEqual(values(newBoard(7, 6, 14)));
    // The board the app deals for six by twelve, pinned in the same fixture the
    // Swift test reads: one seed, one shape, one board on both platforms.
    expect(values(newBoard(1234, 6, 12, 12, false, 'medium')))
      .toEqual(fixtures['1234-6x12-medium']);
  });

  it('counts the top row of its own shape, not of the full board', () => {
    const cells = [[1, 9], [9, 8], [2, 7], [8, 6], [3, 5], [7, 4]];
    const full = board(cells, 0, { columns: 6, rows: 2 });
    expect(canAddRow(full)).toBe(false);

    const shorter = board(cells, 0, { columns: 6, rows: 3 });
    expect(canAddRow(shorter)).toBe(true);
    const next = addRow(shorter, [1, 2, 3, 4, 5, 6])!;
    expect(next.stacks[0]).toHaveLength(3);
    expect(next.columns).toBe(6);
    expect(next.rows).toBe(3);
  });
});

const cell = (value: number): TenCell => ({ value, dimmed: false });

describe('the board hangs from the top', () => {
  it('deals a part-filled board as the top of the same deal', () => {
    const full = newBoard(4321, 9, 18);
    const third = newBoard(4321, 9, 18, 6);
    expect(third.stacks[0]).toHaveLength(6);
    for (let column = 0; column < 9; column += 1) {
      expect(values(third)[column]).toEqual(values(full)[column].slice(0, 6));
    }
    expect(remaining(third)).toBe(54);
    expect(canAddRow(third)).toBe(true);
  });

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
    const wrapped = { seed: 0, columns: 9, rows: 2, wrapRows: true, difficulty: 'medium' as const, stacks };
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

describe('a solution always exists', () => {
  const seeds = [1, 7, 1234, 999, 424242];

  const replay = (
    seed: number,
    columns: number,
    rows: number,
    difficulty: TenDifficulty,
    wrapRows: boolean,
  ) => {
    const { steps } = plan(seed, columns, rows, difficulty, wrapRows);
    const built: TenCell[][] = Array.from({ length: columns }, () => []);
    for (const step of steps) {
      built[step.first.column].splice(
        Math.min(step.first.row, built[step.first.column].length), 0, cell(step.firstValue),
      );
      built[step.second.column].splice(
        Math.min(step.second.row, built[step.second.column].length), 0, cell(step.secondValue),
      );
      const board = { seed, columns, rows, wrapRows, difficulty, stacks: built };
      expect(canMatch(board, step.first, step.second),
        `${difficulty} wrap ${wrapRows} ${seed}: ${JSON.stringify(step)}`).toBe(true);
    }
    return { steps, built };
  };

  it('places every pair where it can be seen, on every level', () => {
    for (const difficulty of DIFFICULTIES) {
      for (const wrapRows of [false, true]) {
        for (const seed of seeds) {
          for (const columns of COLUMN_OPTIONS) {
            for (const rows of ROW_OPTIONS) {
              const { steps, built } = replay(seed, columns, rows, difficulty, wrapRows);
              expect(steps).toHaveLength((columns * rows) / 2);
              built.forEach((column) => expect(column).toHaveLength(rows));
            }
          }
        }
      }
    }
  });

  it('reads the plan backwards as a real clearance', () => {
    for (const difficulty of DIFFICULTIES) {
      for (const wrapRows of [false, true]) {
        for (const seed of [1, 1234]) {
          for (const columns of COLUMN_OPTIONS) {
            for (const rows of ROW_OPTIONS) {
              const { steps, stacks } = plan(seed, columns, rows, difficulty, wrapRows);
              let board = boardFromStacks(
                stacks.map((column) => column.map((entry) => entry.value)),
                seed,
                { columns, rows, wrapRows, difficulty },
              );
              for (const step of [...steps].reverse()) {
                const moved = take(board, step.first, step.second, 'remove');
                expect(moved, `${difficulty} wrap ${wrapRows} ${seed} ${columns}x${rows}`)
                  .not.toBeNull();
                board = moved!.board;
              }
              expect(isCleared(board), `${difficulty} wrap ${wrapRows} ${seed}`).toBe(true);
            }
          }
        }
      }
    }
  });

  it('starts easy with every pair together', () => {
    const { steps } = plan(1234, 9, 18, 'easy');
    const board = newBoard(1234, 9, 18, 18, false, 'easy');
    for (const step of steps) {
      expect(canMatch(board, step.first, step.second)).toBe(true);
    }
  });

  it('hides pairs on hard boards', () => {
    let separated = 0;
    for (const seed of seeds) {
      const { steps } = plan(seed, 9, 18, 'hard');
      const board = newBoard(seed, 9, 18, 18, false, 'hard');
      separated += steps.filter((step) => !canMatch(board, step.first, step.second)).length;
    }
    expect(separated).toBeGreaterThan(100);
  });

  it('hides some pairs on medium boards', () => {
    let separated = 0;
    for (const seed of seeds) {
      const { steps } = plan(seed, 9, 18, 'medium');
      const board = newBoard(seed, 9, 18, 18, false, 'medium');
      separated += steps.filter((step) => !canMatch(board, step.first, step.second)).length;
    }
    expect(separated).toBeGreaterThan(0);
  });

  it('deals both kinds of pair', () => {
    for (const seed of seeds) {
      for (const columns of COLUMN_OPTIONS) {
        for (const rows of ROW_OPTIONS) {
          const { steps } = plan(seed, columns, rows, 'medium');
          expect(steps.some((step) => step.firstValue === step.secondValue)).toBe(true);
          expect(steps.some((step) => step.firstValue + step.secondValue === 10)).toBe(true);
        }
      }
    }
  });

  it('uses the join in the solution when the rows join', () => {
    for (const difficulty of ['medium', 'hard'] as TenDifficulty[]) {
      for (const seed of seeds) {
        const { steps } = plan(seed, 9, 18, difficulty, true);
        const crossing = steps.filter((step) => step.first.row !== step.second.row &&
          step.first.column !== step.second.column &&
          Math.abs(step.first.column - step.second.column) !==
            Math.abs(step.first.row - step.second.row));
        expect(crossing.length, `${difficulty} ${seed}`).toBeGreaterThan(0);
      }
    }
  });

  it('uses rows, columns and diagonals on hard boards', () => {
    let horizontal = 0;
    let vertical = 0;
    let diagonal = 0;
    for (const seed of seeds) {
      const { steps } = plan(seed, 9, 18, 'hard');
      for (const step of steps) {
        if (step.first.row === step.second.row) horizontal += 1;
        else if (step.first.column === step.second.column) vertical += 1;
        else diagonal += 1;
      }
    }
    expect(horizontal).toBeGreaterThan(0);
    expect(vertical).toBeGreaterThan(0);
    expect(diagonal).toBeGreaterThan(0);
  });

  it('cuts a part-filled board at a band boundary', () => {
    for (const difficulty of DIFFICULTIES) {
      const { bandEnds } = plan(1234, 9, 18, difficulty);
      for (let wanted = 1; wanted <= 18; wanted += 1) {
        const board = newBoard(1234, 9, 18, wanted, false, difficulty);
        const height = heightOf(board, 0);
        expect(bandEnds).toContain(height);
        const expected = [...bandEnds].reverse().find((end) => end <= wanted) ?? bandEnds[0];
        expect(height).toBe(expected);
      }
    }
  });
});
