import { SeededGenerator, shuffle } from '../../lib/seeded';
import { grade, gradeDistance, gradeRank } from './grader';
import {
  CELL_COUNT,
  SIDE,
  boxOf,
  columnOf,
  difficultySpec,
  rowOf,
  solutionCount,
  type Difficulty,
  type SudokuPuzzle,
} from './puzzle';

/**
 * Builds Sudoku puzzles on demand. Nothing is stored: a puzzle is a pure function
 * of `(seed, difficulty)`, so a shared race only has to send a number — and both
 * devices must build the identical board from it, including which carving attempt
 * succeeded.
 *
 * Mirrors `SudokuGenerator.swift`. On difficulty: a puzzle is **graded by the
 * techniques it needs**, not by how many clues it shows. Generation carves a
 * candidate, grades it, and keeps trying different carve orders until the grade
 * matches the request. Slower than counting clues, but it is the difference
 * between a board that merely looks sparse and one that actually makes you think.
 */

export function randomSeed(): number {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return values[0];
}

export function puzzle(seed: number, difficulty: Difficulty): SudokuPuzzle {
  const generator = new SeededGenerator(seed);
  const solution = makeSolution(generator);

  let best: { givens: number[]; distance: number } | null = null;
  const spec = difficultySpec(difficulty);

  for (let attempt = 0; attempt < spec.maxAttempts; attempt += 1) {
    const givens = carve(solution, difficulty, generator);
    const earned = grade(givens);
    const distance = gradeDistance(earned, difficulty);

    if (distance === 0) {
      return { seed, difficulty, givens, solution };
    }

    // Keep the closest miss, so failing to hit the grade exactly still returns
    // the most fitting board we saw rather than the last one.
    if (best === null || distance < best.distance) {
      best = { givens, distance };
    }
  }

  return { seed, difficulty, givens: best?.givens ?? solution, solution };
}

/**
 * Removes clues one at a time, keeping the puzzle uniquely solvable, and watches
 * the grade as it goes.
 *
 * Clue count alone is a poor proxy for difficulty: a 34-clue grid very often
 * still falls to singles. So rather than carving to a number, this carves until
 * the *grader* says the requested grade has been reached.
 */
function carve(solution: readonly number[], difficulty: Difficulty, generator: SeededGenerator): number[] {
  const spec = difficultySpec(difficulty);
  const state = [...solution];
  const order = Array.from({ length: CELL_COUNT }, (_, i) => i);
  shuffle(order, generator);

  let clues = CELL_COUNT;
  let match: number[] | null = null;

  for (const index of order) {
    if (clues <= spec.minimumClues) break;

    const removed = state[index];
    state[index] = 0;

    // Only keep the removal if the puzzle still has exactly one answer.
    if (solutionCount(state, 2) !== 1) {
      state[index] = removed;
      continue;
    }
    clues -= 1;

    const earned = grade(state);

    if (earned === difficulty) {
      match = [...state];
      if (spec.stopsAtFirstMatch) break;
    } else if (gradeRank(earned) > gradeRank(difficulty) && spec.stopsAtFirstMatch) {
      // Overshot the grade; the previous match is the one to keep.
      break;
    }
  }

  return match ?? state;
}

// MARK: - Building a full grid

/** Fills an empty grid by randomised backtracking. */
function makeSolution(generator: SeededGenerator): number[] {
  const grid = new Array<number>(CELL_COUNT).fill(0);
  fill(grid, generator);
  return grid;
}

function fill(grid: number[], generator: SeededGenerator): boolean {
  const index = grid.indexOf(0);
  if (index === -1) return true;

  const candidates = [1, 2, 3, 4, 5, 6, 7, 8, 9];
  shuffle(candidates, generator);

  for (const candidate of candidates) {
    if (!isSafe(candidate, index, grid)) continue;
    grid[index] = candidate;
    if (fill(grid, generator)) return true;
    grid[index] = 0;
  }

  return false;
}

function isSafe(value: number, index: number, grid: readonly number[]): boolean {
  const r = rowOf(index);
  const c = columnOf(index);
  const b = boxOf(index);

  for (let other = 0; other < CELL_COUNT; other += 1) {
    if (grid[other] !== value) continue;
    if (rowOf(other) === r || columnOf(other) === c || boxOf(other) === b) return false;
  }
  return true;
}

export { SIDE };
