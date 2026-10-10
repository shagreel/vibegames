import {
  ALL_VALUES,
  CELL_COUNT,
  PEERS,
  UNITS,
  UNITS_BY_CELL,
  bitFor,
  bitsIn,
  boxOf,
  columnOf,
  popcount,
  rowOf,
  sees,
  valueFor,
} from './puzzle';

/**
 * Grades a Sudoku by solving it the way a person would.
 *
 * Mirrors `SudokuGrader.swift`. It repeatedly applies the *easiest* technique
 * that makes progress and remembers the hardest one it needed. If it runs out of
 * techniques before the grid is full, the puzzle needs trial and error, which
 * counts as hard.
 *
 * This is what makes a difficulty tier mean something. Clue count only
 * correlates with difficulty: a 26-clue grid that falls to singles is far easier
 * than a 32-clue grid that needs an X-Wing.
 */

export type Grade = 'easy' | 'medium' | 'hard';

export const GRADE_ORDER: Grade[] = ['easy', 'medium', 'hard'];

export function gradeRank(grade: Grade): number {
  return GRADE_ORDER.indexOf(grade);
}

export function gradeDistance(a: Grade, b: Grade): number {
  return Math.abs(gradeRank(a) - gradeRank(b));
}

/** The solving techniques the grader knows, ordered by how hard they are. */
export type Technique =
  | 'nakedSingle'
  | 'hiddenSingle'
  | 'lockedCandidates'
  | 'nakedPair'
  | 'hiddenPair'
  | 'nakedTriple'
  | 'xWing'
  | 'xyWing';

const TECHNIQUE_ORDER: Technique[] = [
  'nakedSingle',
  'hiddenSingle',
  'lockedCandidates',
  'nakedPair',
  'hiddenPair',
  'nakedTriple',
  'xWing',
  'xyWing',
];

export function techniqueGrade(technique: Technique): Grade {
  switch (technique) {
    case 'nakedSingle':
    case 'hiddenSingle':
      return 'easy';
    case 'lockedCandidates':
    case 'nakedPair':
    case 'hiddenPair':
    case 'nakedTriple':
      return 'medium';
    case 'xWing':
    case 'xyWing':
      return 'hard';
  }
}

function harder(a: Technique, b: Technique): Technique {
  return TECHNIQUE_ORDER.indexOf(a) >= TECHNIQUE_ORDER.indexOf(b) ? a : b;
}

export function grade(givens: readonly number[]): Grade {
  return solve(givens) ?? 'hard';
}

/**
 * Returns the hardest technique needed, or null if the puzzle cannot be finished
 * without guessing.
 */
export function solve(givens: readonly number[]): Grade | null {
  if (givens.length !== CELL_COUNT) return null;

  const cells = [...givens];
  const candidates = makeCandidates(cells);
  let hardest: Technique = 'nakedSingle';

  while (cells.includes(0)) {
    if (placeNakedSingle(cells, candidates)) {
      hardest = harder(hardest, 'nakedSingle');
      continue;
    }
    if (placeHiddenSingle(cells, candidates)) {
      hardest = harder(hardest, 'hiddenSingle');
      continue;
    }
    if (eliminateLockedCandidates(candidates)) {
      hardest = harder(hardest, 'lockedCandidates');
      continue;
    }
    if (eliminateNakedPair(candidates)) {
      hardest = harder(hardest, 'nakedPair');
      continue;
    }
    if (eliminateHiddenPair(candidates)) {
      hardest = harder(hardest, 'hiddenPair');
      continue;
    }
    if (eliminateNakedTriple(candidates)) {
      hardest = harder(hardest, 'nakedTriple');
      continue;
    }
    if (eliminateXWing(candidates)) {
      hardest = harder(hardest, 'xWing');
      continue;
    }
    if (eliminateXYWing(candidates)) {
      hardest = harder(hardest, 'xyWing');
      continue;
    }
    // Nothing left that a person could reason with.
    return null;
  }

  return techniqueGrade(hardest);
}

// MARK: - Candidates

function makeCandidates(cells: readonly number[]): Int32Array {
  const used = new Int32Array(27);
  for (let index = 0; index < CELL_COUNT; index += 1) {
    if (cells[index] === 0) continue;
    const bit = bitFor(cells[index]);
    for (const unit of UNITS_BY_CELL[index]) used[unit] |= bit;
  }

  const result = new Int32Array(CELL_COUNT);
  for (let index = 0; index < CELL_COUNT; index += 1) {
    if (cells[index] !== 0) continue;
    let mask = ALL_VALUES;
    for (const unit of UNITS_BY_CELL[index]) mask &= ~used[unit];
    result[index] = mask;
  }
  return result;
}

/** Places a value, clearing it from every peer's candidates. */
function place(
  value: number,
  index: number,
  cells: number[],
  candidates: Int32Array,
): boolean {
  if (cells[index] !== 0) return false;
  cells[index] = value;
  candidates[index] = 0;

  const bit = bitFor(value);
  for (const unit of UNITS_BY_CELL[index]) {
    for (const peer of UNITS[unit]) {
      if (cells[peer] === 0) candidates[peer] &= ~bit;
    }
  }
  return true;
}

// MARK: - Techniques

function placeNakedSingle(cells: number[], candidates: Int32Array): boolean {
  for (let index = 0; index < CELL_COUNT; index += 1) {
    if (cells[index] === 0 && popcount(candidates[index]) === 1) {
      return place(valueFor(candidates[index]), index, cells, candidates);
    }
  }
  return false;
}

function placeHiddenSingle(cells: number[], candidates: Int32Array): boolean {
  for (const unit of UNITS) {
    let seen = 0;
    let duplicates = 0;
    for (const cell of unit) {
      if (cells[cell] !== 0) continue;
      duplicates |= seen & candidates[cell];
      seen |= candidates[cell];
    }
    const unique = seen & ~duplicates;
    if (unique === 0) continue;

    // One value has a single home in this unit.
    const bit = bitsIn(unique)[0];
    for (const cell of unit) {
      if (cells[cell] === 0 && (candidates[cell] & bit) !== 0) {
        return place(valueFor(bit), cell, cells, candidates);
      }
    }
  }
  return false;
}

/**
 * Pointing and claiming: if a value's only homes in a box lie on one line, it can
 * be removed from the rest of that line, and vice versa.
 */
function eliminateLockedCandidates(candidates: Int32Array): boolean {
  let changed = false;

  for (let box = 0; box < 9; box += 1) {
    const unit = UNITS[18 + box];
    for (let value = 1; value <= 9; value += 1) {
      const bit = bitFor(value);
      const homes = unit.filter((cell) => (candidates[cell] & bit) !== 0);
      if (homes.length < 2 || homes.length > 3) continue;

      if (new Set(homes.map(rowOf)).size === 1) {
        const row = rowOf(homes[0]);
        for (const cell of UNITS[row]) {
          if (!unit.includes(cell) && (candidates[cell] & bit) !== 0) {
            candidates[cell] &= ~bit;
            changed = true;
          }
        }
      }
      if (new Set(homes.map(columnOf)).size === 1) {
        const column = columnOf(homes[0]);
        for (const cell of UNITS[9 + column]) {
          if (!unit.includes(cell) && (candidates[cell] & bit) !== 0) {
            candidates[cell] &= ~bit;
            changed = true;
          }
        }
      }
    }
  }

  for (let line = 0; line < 18; line += 1) {
    const unit = UNITS[line];
    for (let value = 1; value <= 9; value += 1) {
      const bit = bitFor(value);
      const homes = unit.filter((cell) => (candidates[cell] & bit) !== 0);
      if (homes.length < 2 || homes.length > 3) continue;
      if (new Set(homes.map(boxOf)).size !== 1) continue;

      const box = boxOf(homes[0]);
      for (const cell of UNITS[18 + box]) {
        if (!unit.includes(cell) && (candidates[cell] & bit) !== 0) {
          candidates[cell] &= ~bit;
          changed = true;
        }
      }
    }
  }

  return changed;
}

function eliminateNakedPair(candidates: Int32Array): boolean {
  for (const unit of UNITS) {
    const pairs = unit.filter((cell) => popcount(candidates[cell]) === 2);
    if (pairs.length < 2) continue;

    for (let first = 0; first < pairs.length; first += 1) {
      for (let second = first + 1; second < pairs.length; second += 1) {
        const mask = candidates[pairs[first]];
        if (mask !== candidates[pairs[second]]) continue;

        let changed = false;
        for (const cell of unit) {
          if (cell === pairs[first] || cell === pairs[second]) continue;
          if ((candidates[cell] & mask) !== 0) {
            candidates[cell] &= ~mask;
            changed = true;
          }
        }
        if (changed) return true;
      }
    }
  }
  return false;
}

function eliminateHiddenPair(candidates: Int32Array): boolean {
  for (const unit of UNITS) {
    for (let first = 1; first <= 9; first += 1) {
      const firstBit = bitFor(first);
      const firstHomes = unit.filter((cell) => (candidates[cell] & firstBit) !== 0);
      if (firstHomes.length !== 2) continue;

      for (let second = first + 1; second <= 9; second += 1) {
        const secondBit = bitFor(second);
        const secondHomes = unit.filter((cell) => (candidates[cell] & secondBit) !== 0);
        if (secondHomes.length !== 2) continue;
        if (firstHomes[0] !== secondHomes[0] || firstHomes[1] !== secondHomes[1]) continue;

        const mask = firstBit | secondBit;
        let changed = false;
        for (const cell of firstHomes) {
          if (candidates[cell] !== mask) {
            candidates[cell] = mask;
            changed = true;
          }
        }
        if (changed) return true;
      }
    }
  }
  return false;
}

function eliminateNakedTriple(candidates: Int32Array): boolean {
  for (const unit of UNITS) {
    const open = unit.filter((cell) => {
      const count = popcount(candidates[cell]);
      return count >= 2 && count <= 3;
    });
    if (open.length < 3) continue;

    for (const combo of combinations(open, 3)) {
      let union = 0;
      for (const cell of combo) union |= candidates[cell];
      if (popcount(union) !== 3) continue;

      let changed = false;
      for (const cell of unit) {
        if (combo.includes(cell)) continue;
        if ((candidates[cell] & union) !== 0) {
          candidates[cell] &= ~union;
          changed = true;
        }
      }
      if (changed) return true;
    }
  }
  return false;
}

/**
 * X-Wing: a value with exactly two homes in each of two lines, and those homes
 * sit in the same two crossing lines. It can be removed elsewhere on the
 * crossing lines.
 */
function eliminateXWing(candidates: Int32Array): boolean {
  for (let orientation = 0; orientation < 2; orientation += 1) {
    for (let value = 1; value <= 9; value += 1) {
      const bit = bitFor(value);

      const linesWithTwoHomes: { line: number; positions: number[] }[] = [];
      for (let line = 0; line < 9; line += 1) {
        const unit = orientation === 0 ? UNITS[line] : UNITS[9 + line];
        const homes = unit.filter((cell) => (candidates[cell] & bit) !== 0);
        if (homes.length === 2) linesWithTwoHomes.push({ line, positions: homes });
      }
      if (linesWithTwoHomes.length < 2) continue;

      for (let first = 0; first < linesWithTwoHomes.length; first += 1) {
        for (let second = first + 1; second < linesWithTwoHomes.length; second += 1) {
          const a = linesWithTwoHomes[first];
          const b = linesWithTwoHomes[second];

          const crossA = a.positions.map((cell) => (orientation === 0 ? columnOf(cell) : rowOf(cell)));
          const crossB = b.positions.map((cell) => (orientation === 0 ? columnOf(cell) : rowOf(cell)));
          if (crossA[0] !== crossB[0] || crossA[1] !== crossB[1]) continue;

          let changed = false;
          for (const cross of crossA) {
            const unit = orientation === 0 ? UNITS[9 + cross] : UNITS[cross];
            for (const cell of unit) {
              if (a.positions.includes(cell) || b.positions.includes(cell)) continue;
              if ((candidates[cell] & bit) !== 0) {
                candidates[cell] &= ~bit;
                changed = true;
              }
            }
          }
          if (changed) return true;
        }
      }
    }
  }
  return false;
}

/**
 * XY-Wing: a pivot with two candidates and two pincers that each share one
 * candidate with it, both able to see it. The third candidate is then impossible
 * anywhere that sees both pincers.
 *
 * Written to avoid rescanning: the naive form is quartic and dominates
 * generation time.
 */
function eliminateXYWing(candidates: Int32Array): boolean {
  const bivalue: number[] = [];
  for (let cell = 0; cell < CELL_COUNT; cell += 1) {
    if (popcount(candidates[cell]) === 2) bivalue.push(cell);
  }

  for (const pivot of bivalue) {
    const pivotMask = candidates[pivot];

    for (const wingX of bitsIn(pivotMask)) {
      const wingY = pivotMask & ~wingX;

      const xWings: { cell: number; z: number }[] = [];
      const yWings: { cell: number; z: number }[] = [];

      for (const peer of PEERS[pivot]) {
        if (popcount(candidates[peer]) !== 2) continue;
        const mask = candidates[peer];
        if ((mask & wingX) !== 0 && (mask & wingY) === 0) {
          xWings.push({ cell: peer, z: mask & ~wingX });
        } else if ((mask & wingY) !== 0 && (mask & wingX) === 0) {
          yWings.push({ cell: peer, z: mask & ~wingY });
        }
      }

      for (const x of xWings) {
        for (const y of yWings) {
          if (x.z !== y.z) continue;

          let changed = false;
          for (const cell of PEERS[x.cell]) {
            if (cell === x.cell || cell === y.cell || cell === pivot) continue;
            if ((candidates[cell] & x.z) === 0) continue;
            if (!sees(cell, y.cell)) continue;
            candidates[cell] &= ~x.z;
            changed = true;
          }
          if (changed) return true;
        }
      }
    }
  }
  return false;
}

export function combinations(items: readonly number[], choose: number): number[][] {
  if (choose <= 0 || items.length < choose) return [];
  if (choose === 1) return items.map((item) => [item]);

  const result: number[][] = [];
  for (let index = 0; index <= items.length - choose; index += 1) {
    const rest = items.slice(index + 1);
    for (const tail of combinations(rest, choose - 1)) {
      result.push([items[index], ...tail]);
    }
  }
  return result;
}
