import { describe, it, expect } from 'vitest';
import fixtures from '../games/sudoku/generator.fixtures.json';
import {
  CELL_COUNT,
  clueCount,
  conflictsIn,
  difficultySpec,
  isComplete,
  solutionCount,
} from '../games/sudoku/puzzle';
import { combinations, grade, gradeDistance, solve } from '../games/sudoku/grader';
import { puzzle } from '../games/sudoku/generator';

const GRADES = ['easy', 'medium', 'hard'] as const;
const digits = (values: number[]) => values.join('');

/**
 * The fixtures come from the Swift engine (`Tools/sudoku_fixtures`). A shared
 * race sends a seed and a difficulty and nothing else, so if these two ever
 * disagree, two players race different boards while the screen says otherwise.
 */
describe('agreement with the iOS generator', () => {
  const cases = Object.entries(fixtures);

  it('has fixtures to check', () => {
    expect(cases.length).toBeGreaterThan(0);
  });

  for (const [key, expected] of cases) {
    it(`generates the identical ${key} board`, () => {
      const generated = puzzle(expected.seed, expected.difficulty as 'easy');

      expect(digits(generated.solution.map((v) => v))).toBe(expected.solution);
      expect(digits(generated.givens)).toBe(expected.givens);
      expect(clueCount(generated.givens)).toBe(expected.clues);
      expect(grade(generated.givens)).toBe(GRADES[expected.grade]);
    });
  }
});

describe('a generated puzzle', () => {
  it('is a legal grid with one answer', () => {
    for (const difficulty of ['easy', 'medium', 'hard'] as const) {
      const generated = puzzle(2024, difficulty);

      expect(isComplete(generated.solution)).toBe(true);
      expect(conflictsIn(generated.givens).size).toBe(0);
      // Every given agrees with the solution.
      generated.givens.forEach((value, index) => {
        if (value !== 0) expect(value).toBe(generated.solution[index]);
      });
      // And the givens admit exactly one.
      expect(solutionCount(generated.givens, 2)).toBe(1);
    }
  });

  /**
   * Hitting the grade is best-effort, not a guarantee: generation tries
   * `maxAttempts` carve orders and falls back to the closest miss. Measured over
   * forty seeds it lands exactly on easy 40/40, medium 31/40 and hard 39/40 —
   * and the fixtures show the iOS generator behaving identically, so this is the
   * intended shape rather than a porting slip.
   */
  it('never lands more than one grade away from the one asked for', () => {
    for (const difficulty of ['easy', 'medium', 'hard'] as const) {
      for (let seed = 1; seed <= 12; seed += 1) {
        const earned = grade(puzzle(seed, difficulty).givens);
        expect(
          gradeDistance(earned, difficulty),
          `seed ${seed} asked for ${difficulty} and got ${earned}`,
        ).toBeLessThanOrEqual(1);
      }
    }
  });

  it('always delivers an Easy board that really is easy', () => {
    // Guaranteed rather than best-effort: carving stops at 44 clues, and every
    // board that full falls to singles.
    for (let seed = 1; seed <= 12; seed += 1) {
      expect(grade(puzzle(seed, 'easy').givens)).toBe('easy');
    }
  });

  it('never hands back an Easy board when Hard was asked for', () => {
    for (let seed = 1; seed <= 12; seed += 1) {
      expect(grade(puzzle(seed, 'hard').givens)).not.toBe('easy');
    }
  });

  it('gets sparser as the difficulty rises', () => {
    const easy = clueCount(puzzle(5, 'easy').givens);
    const hard = clueCount(puzzle(5, 'hard').givens);
    expect(easy).toBeGreaterThan(hard);
  });

  it('is the same board every time from the same seed', () => {
    const a = puzzle(777, 'medium');
    const b = puzzle(777, 'medium');
    expect(a.givens).toEqual(b.givens);
    expect(a.solution).toEqual(b.solution);
  });

  it('is a different board from a different seed', () => {
    const a = puzzle(1, 'easy');
    const b = puzzle(2, 'easy');
    expect(a.solution).not.toEqual(b.solution);
  });

  it('never asks for more clues than it can give', () => {
    for (const difficulty of ['easy', 'medium', 'hard'] as const) {
      const spec = difficultySpec(difficulty);
      const generated = puzzle(99, difficulty);
      expect(clueCount(generated.givens)).toBeGreaterThanOrEqual(spec.minimumClues);
      expect(clueCount(generated.givens)).toBeLessThanOrEqual(CELL_COUNT);
    }
  });
});

describe('the grader', () => {
  it('calls a solved grid hard only if it needed a hard technique', () => {
    // A full valid grid needs no technique at all beyond placing what is there.
    const solved = puzzle(4, 'easy').solution;
    expect(grade(solved)).toBe('easy');
  });

  it('refuses a grid it cannot finish without guessing', () => {
    // An empty grid is the extreme case: no technique applies.
    expect(solve(new Array(CELL_COUNT).fill(0))).toBeNull();
    expect(grade(new Array(CELL_COUNT).fill(0))).toBe('hard');
  });

  it('rejects a grid of the wrong size', () => {
    expect(solve([1, 2, 3])).toBeNull();
  });

  it('enumerates combinations the way the technique scan expects', () => {
    expect(combinations([1, 2, 3], 3)).toEqual([[1, 2, 3]]);
    expect(combinations([1, 2, 3, 4], 2)).toEqual([[1, 2], [1, 3], [1, 4], [2, 3], [2, 4], [3, 4]]);
    expect(combinations([1, 2], 3)).toEqual([]);
    expect(combinations([1, 2], 1)).toEqual([[1], [2]]);
  });
});
