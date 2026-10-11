/**
 * The seeded generator and shuffle, shared by every game that has to rebuild a
 * board from a number.
 *
 * Both Vibe Trio and Vibe Sudoku take a seed and must produce exactly what the
 * iOS app produces from the same one — a shared game sends nothing else. That
 * makes this the one piece of arithmetic in the suite that two platforms have to
 * agree on to the bit, so it lives in one place rather than beside each game.
 *
 * `web/src/test/trioEngine.test.ts` and `web/src/test/sudokuGenerator.test.ts`
 * both check it against fixtures dumped from the Swift engine.
 */

/**
 * A small SplitMix64 generator, identical to `SeededGenerator.swift`.
 *
 * Determinism is the whole point: a shared game stores a seed and a list of
 * moves, and every device — iOS or browser — has to build the identical board
 * from them. `Math.random` would give each player a different board, and a
 * mismatch would only show up as two people disagreeing about what is in front
 * of them in a live game.
 */
export class SeededGenerator {
  private state: bigint;

  constructor(seed: number) {
    // The seed *is* the state; `next()` does the add-and-mix, which is how
    // SplitMix64 is defined. See `SeededGenerator.swift` for why pre-scrambling
    // it here made consecutive seeds replay the same stream one draw apart.
    this.state = BigInt(seed) & 0xffffffffffffffffn;
  }

  next(): bigint {
    this.state = (this.state + 0x9e3779b97f4a7c15n) & 0xffffffffffffffffn;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & 0xffffffffffffffffn;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & 0xffffffffffffffffn;
    return (z ^ (z >> 31n)) & 0xffffffffffffffffn;
  }

  /**
   * A uniform value below `bound`, by the same multiply-shift method Swift's
   * `next(upperBound:)` uses.
   *
   * This is the part that is easy to get subtly wrong and impossible to notice:
   * plain `next() % bound` produces a different shuffle for the same seed, so a
   * browser and a phone would disagree about the board. The fixtures in
   * `trio/engine.fixtures.json` and `sudoku/generator.fixtures.json` pin it
   * against the Swift engine.
   */
  nextBounded(bound: number): number {
    const limit = BigInt(bound);
    let product = this.next() * limit;
    let low = product & 0xffffffffffffffffn;
    if (low < limit) {
      const threshold = ((0n - limit) % limit + limit) % limit;
      while (low < threshold) {
        product = this.next() * limit;
        low = product & 0xffffffffffffffffn;
      }
    }
    return Number(product >> 64n);
  }
}

/**
 * Swift's `Array.shuffle(using:)`.
 *
 * Forward Fisher–Yates, swapping `i` with `i + rand(count - i)`. Any other
 * correct shuffle is still a shuffle, but not *this* shuffle, and a shared game
 * needs all of them to agree. The order matters as much as the algorithm: the
 * Sudoku generator reshuffles a candidate list per cell while backtracking, so a
 * different order explores a different tree and lands on a different solution.
 */
export function shuffle<T>(items: T[], generator: SeededGenerator): void {
  const count = items.length;
  for (let i = 0; i < count - 1; i += 1) {
    const j = i + generator.nextBounded(count - i);
    const swap = items[i];
    items[i] = items[j];
    items[j] = swap;
  }
}
