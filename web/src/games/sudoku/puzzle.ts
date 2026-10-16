/**
 * Grid maths and difficulty tiers. Deliberately free of UI and networking so it
 * can be tested hard.
 *
 * Mirrors `SudokuPuzzle.swift`. A puzzle is a pure function of `(seed,
 * difficulty)`, so there are as many boards as there are seeds — about four
 * billion — and a shared race only has to send a number.
 *
 * Values are 1…9 with `0` for empty, and candidate sets are 9-bit masks held in
 * ordinary numbers: bit 0 is the value 1. Swift uses `UInt16` for these; plain
 * numbers are exact well past nine bits, and every mask operation here stays
 * inside int32.
 */

export const SIDE = 9;
export const CELL_COUNT = 81;

/**
 * How many numbers a cell's notes hold: four, shown big, rather than nine tiny
 * ones. A phone-sized cell cannot show nine marks anybody can read, and an
 * unreadable note is worse than no note.
 */
export const MAXIMUM_NOTES = 4;
export const ALL_VALUES = 0x1ff;

export type Difficulty = 'easy' | 'medium' | 'hard';

export interface DifficultySpec {
  id: Difficulty;
  title: string;
  blurb: string;
  /** How far to keep carving. */
  minimumClues: number;
  /**
   * Whether to stop at the *first* puzzle of this grade, or keep carving and
   * take the last one that still graded the same. Medium wants the first: it is
   * the gentlest board that needs real technique. Hard wants the last, so it
   * ends up genuinely sparse as well.
   */
  stopsAtFirstMatch: boolean;
  /** How many carves to try before settling for the closest grade. */
  maxAttempts: number;
}

export const DIFFICULTIES: DifficultySpec[] = [
  { id: 'easy', title: 'Easy', blurb: 'Singles all the way down', minimumClues: 44, stopsAtFirstMatch: false, maxAttempts: 4 },
  { id: 'medium', title: 'Medium', blurb: 'Needs pairs and locked candidates', minimumClues: 26, stopsAtFirstMatch: true, maxAttempts: 8 },
  { id: 'hard', title: 'Hard', blurb: 'Sparse, and needs real technique', minimumClues: 22, stopsAtFirstMatch: false, maxAttempts: 8 },
];

export const FALLBACK_DIFFICULTY: Difficulty = 'easy';

export function difficultySpec(id: Difficulty): DifficultySpec {
  return DIFFICULTIES.find((d) => d.id === id) ?? DIFFICULTIES[0];
}

export interface SudokuPuzzle {
  seed: number;
  difficulty: Difficulty;
  /** 81 values, row-major. `0` means empty. */
  givens: number[];
  /** The one solution the givens admit. */
  solution: number[];
}

export function clueCount(givens: readonly number[]): number {
  return givens.reduce((total, value) => (value === 0 ? total : total + 1), 0);
}

// MARK: - Bit helpers

export function popcount(mask: number): number {
  let count = 0;
  let remaining = mask;
  while (remaining !== 0) {
    remaining &= remaining - 1;
    count += 1;
  }
  return count;
}

/** The lowest set bit, or 0. `n & -n` is exact for masks this small. */
export function lowestBit(mask: number): number {
  return mask & -mask;
}

/** 0-based position of a single set bit. */
export function bitIndex(bit: number): number {
  return 31 - Math.clz32(bit);
}

export function bitFor(value: number): number {
  return 1 << (value - 1);
}

export function valueFor(bit: number): number {
  return bitIndex(bit) + 1;
}

export function bitsIn(mask: number): number[] {
  const bits: number[] = [];
  let remaining = mask;
  while (remaining !== 0) {
    const bit = lowestBit(remaining);
    bits.push(bit);
    remaining &= ~bit;
  }
  return bits;
}

// MARK: - Geometry

export function rowOf(index: number): number {
  return Math.floor(index / 9);
}

export function columnOf(index: number): number {
  return index % 9;
}

export function boxOf(index: number): number {
  return Math.floor(index / 27) * 3 + Math.floor((index % 9) / 3);
}

/** The 27 units: nine rows, nine columns, nine boxes. */
export const UNITS: number[][] = (() => {
  const units: number[][] = [];
  for (let row = 0; row < 9; row += 1) {
    units.push(Array.from({ length: 9 }, (_, i) => row * 9 + i));
  }
  for (let column = 0; column < 9; column += 1) {
    units.push(Array.from({ length: 9 }, (_, i) => i * 9 + column));
  }
  for (let box = 0; box < 9; box += 1) {
    const baseRow = Math.floor(box / 3) * 3;
    const baseColumn = (box % 3) * 3;
    units.push(
      Array.from({ length: 9 }, (_, i) => (baseRow + Math.floor(i / 3)) * 9 + baseColumn + (i % 3)),
    );
  }
  return units;
})();

/** Cells sharing a row, column or box with each cell. */
export const PEERS: number[][] = (() => {
  const peers: number[][] = [];
  for (let cell = 0; cell < CELL_COUNT; cell += 1) {
    const list: number[] = [];
    for (let other = 0; other < CELL_COUNT; other += 1) {
      if (other === cell) continue;
      if (
        rowOf(other) === rowOf(cell) ||
        columnOf(other) === columnOf(cell) ||
        boxOf(other) === boxOf(cell)
      ) {
        list.push(other);
      }
    }
    peers.push(list);
  }
  return peers;
})();

/** Every unit each cell belongs to. */
export const UNITS_BY_CELL: number[][] = (() => {
  const byCell: number[][] = Array.from({ length: CELL_COUNT }, () => []);
  UNITS.forEach((unit, index) => {
    for (const cell of unit) byCell[cell].push(index);
  });
  return byCell;
})();

export function sees(a: number, b: number): boolean {
  return rowOf(a) === rowOf(b) || columnOf(a) === columnOf(b) || boxOf(a) === boxOf(b);
}

// MARK: - The solver

/**
 * Counts solutions, stopping early once `limit` is reached.
 *
 * Uses bitmasks plus a minimum-remaining-values search, which is what makes
 * uniqueness checking fast enough to run once per removed clue.
 */
export function solutionCount(grid: readonly number[], limit = 2): number {
  if (grid.length !== CELL_COUNT) return 0;

  const rows = new Int32Array(9);
  const columns = new Int32Array(9);
  const boxes = new Int32Array(9);
  const cells = Int32Array.from(grid);

  for (let index = 0; index < CELL_COUNT; index += 1) {
    const value = grid[index];
    if (value === 0) continue;
    if (value < 1 || value > 9) return 0;
    const bit = bitFor(value);
    const r = rowOf(index);
    const c = columnOf(index);
    const b = boxOf(index);
    // A well-formed givens grid never repeats within a unit.
    if ((rows[r] & bit) !== 0 || (columns[c] & bit) !== 0 || (boxes[b] & bit) !== 0) return 0;
    rows[r] |= bit;
    columns[c] |= bit;
    boxes[b] |= bit;
  }

  let found = 0;

  const search = (): void => {
    if (found >= limit) return;

    let target = -1;
    let targetMask = 0;
    let fewest = 10;

    for (let index = 0; index < CELL_COUNT; index += 1) {
      if (cells[index] !== 0) continue;
      const available = ~(rows[rowOf(index)] | columns[columnOf(index)] | boxes[boxOf(index)]) & ALL_VALUES;
      const count = popcount(available);
      if (count === 0) return; // dead end
      if (count < fewest) {
        fewest = count;
        target = index;
        targetMask = available;
        if (count === 1) break; // cannot do better
      }
    }

    if (target === -1) {
      // Nothing empty: a solution.
      found += 1;
      return;
    }

    const r = rowOf(target);
    const c = columnOf(target);
    const b = boxOf(target);
    let mask = targetMask;

    while (mask !== 0) {
      const bit = lowestBit(mask);
      mask &= ~bit;

      cells[target] = valueFor(bit);
      rows[r] |= bit;
      columns[c] |= bit;
      boxes[b] |= bit;

      search();

      rows[r] &= ~bit;
      columns[c] &= ~bit;
      boxes[b] &= ~bit;
      cells[target] = 0;

      if (found >= limit) return;
    }
  };

  search();
  return found;
}

/** Indices whose value repeats within its row, column or box. */
export function conflictsIn(grid: readonly number[]): Set<number> {
  const result = new Set<number>();

  for (let index = 0; index < CELL_COUNT; index += 1) {
    const value = grid[index];
    if (value === 0) continue;
    const r = rowOf(index);
    const c = columnOf(index);
    const b = boxOf(index);

    for (let other = index + 1; other < CELL_COUNT; other += 1) {
      if (grid[other] !== value) continue;
      if (rowOf(other) === r || columnOf(other) === c || boxOf(other) === b) {
        result.add(index);
        result.add(other);
      }
    }
  }

  return result;
}

/** Whether every cell is filled and nothing conflicts. */
export function isComplete(grid: readonly number[]): boolean {
  return (
    grid.length === CELL_COUNT && !grid.includes(0) && conflictsIn(grid).size === 0
  );
}
