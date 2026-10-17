import { describe, it, expect } from 'vitest';
import { DECK, allTrios, cardOf, completingCard, imageName, isTrio, spokenDescription } from '../games/trio/cards';
import { newTable, replay, takeAt, takeByIds, firstTrio, isFinished, wouldFormTrioByIds } from '../games/trio/engine';
import fixtures from '../games/trio/engine.fixtures.json';

/**
 * The trio rule is pure combinatorics, so it can be checked exhaustively rather
 * than by sampling — all 85,320 triples of the 81-card deck.
 */
describe('the trio rule', () => {
  it('has 81 unique cards', () => {
    expect(DECK).toHaveLength(81);
    expect(new Set(DECK.map((c) => c.id)).size).toBe(81);
  });

  it('numbers the cards the way the artwork is numbered', () => {
    for (const card of DECK) {
      expect(imageName(card)).toBe(
        `card-${String(card.id + 1).padStart(2, '0')}_${['circle', 'hexagon', 'rectangle'][card.base]}_${['swiss', 'gouda', 'brie'][card.cheese]}_${['prosciutto', 'salami', 'turkey'][card.meat]}_${['grapes', 'strawberry', 'pear'][card.garnish]}`,
      );
    }
  });

  it('reads every card differently', () => {
    expect(new Set(DECK.map(spokenDescription)).size).toBe(81);
  });

  /** The independent formulation: a triple fails if one feature has two agreeing. */
  const matchesMagicRule = (a: (typeof DECK)[number], b: (typeof DECK)[number], c: (typeof DECK)[number]) => {
    const ok = (x: number, y: number, z: number) =>
      (x === y && y === z) || (x !== y && y !== z && x !== z);
    return (
      ok(a.base, b.base, c.base) &&
      ok(a.cheese, b.cheese, c.cheese) &&
      ok(a.meat, b.meat, c.meat) &&
      ok(a.garnish, b.garnish, c.garnish)
    );
  };

  it('matches the all-same-or-all-different rule on every one of the 85,320 triples', () => {
    let trios = 0;
    for (let i = 0; i < 81; i += 1) {
      for (let j = i + 1; j < 81; j += 1) {
        for (let k = j + 1; k < 81; k += 1) {
          const verdict = isTrio(DECK[i], DECK[j], DECK[k]);
          expect(verdict).toBe(matchesMagicRule(DECK[i], DECK[j], DECK[k]));
          if (verdict) trios += 1;
        }
      }
    }
    // 1,080 = 81 * 80 / 6 / ... the known count for a 4-feature, 3-option deck.
    expect(trios).toBe(1080);
  });

  it('completes every pair with exactly one card', () => {
    for (let i = 0; i < 81; i += 1) {
      for (let j = i + 1; j < 81; j += 1) {
        const third = completingCard(DECK[i], DECK[j]);
        expect(isTrio(DECK[i], DECK[j], third)).toBe(true);
        // Nothing else completes it.
        const others = DECK.filter((c) => c.id !== third.id && isTrio(DECK[i], DECK[j], c));
        expect(others).toHaveLength(0);
      }
    }
  });

  it('refuses three copies of one card', () => {
    const card = cardOf(0, 0, 0, 0);
    expect(isTrio(card, card, card)).toBe(true); // the rule itself says yes
    // ...which is why the table checks the indices are distinct, below.
  });
});

/**
 * The fixtures come from the Swift engine (`Tools/trio_fixtures`). A shared game
 * sends a seed and the taken cards and nothing else, so if these two ever
 * disagree a browser and a phone would sit in the same game looking at different
 * tables.
 */
describe('agreement with the iOS engine', () => {
  for (const [seed, expected] of Object.entries(fixtures.shuffles)) {
    it(`shuffles to the same deck as Swift for seed ${seed}`, () => {
      const table = newTable(Number(seed));
      const dealt = [...table.visible, ...table.remaining].map((c) => c.id);
      expect(dealt).toEqual(expected);
    });
  }

  for (const [seed, expected] of Object.entries(fixtures.tables)) {
    it(`opens the same table as Swift for seed ${seed}`, () => {
      const table = newTable(Number(seed));
      expect(table.visible.map((c) => c.id)).toEqual(expected.visible);
      expect(table.remaining.map((c) => c.id)).toEqual(expected.remaining);
    });
  }

  for (const [seed, takes] of Object.entries(fixtures.games)) {
    it(`plays out the same game as Swift for seed ${seed}`, () => {
      let table = newTable(Number(seed));
      const played: number[][] = [];
      for (;;) {
        const trio = firstTrio(table.visible);
        if (!trio) break;
        played.push(trio.map((index) => table.visible[index].id).sort((a, b) => a - b));
        table = takeAt(table, trio)!;
      }
      expect(played).toEqual(takes);
      expect(isFinished(table)).toBe(true);

      // And replaying the same takes lands on the same board.
      const replayed = replay(Number(seed), takes);
      expect(replayed.visible.map((c) => c.id)).toEqual(table.visible.map((c) => c.id));
      expect(replayed.triosTaken).toBe(table.triosTaken);
    });
  }
});

describe('the table', () => {
  it('always shows twelve cards out of the gate', () => {
    for (let seed = 1; seed <= 40; seed += 1) {
      expect(newTable(seed).visible.length).toBeGreaterThanOrEqual(12);
    }
  });

  it('never stalls: there is always a trio while the deck lasts', () => {
    for (let seed = 1; seed <= 60; seed += 1) {
      let table = newTable(seed);
      let guardRail = 0;
      while (!isFinished(table)) {
        guardRail += 1;
        if (guardRail > 100) throw new Error(`seed ${seed} would not finish`);
        const trio = firstTrio(table.visible);
        expect(trio).not.toBeNull();
        table = takeAt(table, trio!)!;
      }
      expect(table.remaining).toHaveLength(0);
    }
  });

  it('never shows the same card twice', () => {
    let table = newTable(3);
    while (!isFinished(table)) {
      const ids = table.visible.map((c) => c.id);
      expect(new Set(ids).size).toBe(ids.length);
      const trio = firstTrio(table.visible)!;
      table = takeAt(table, trio)!;
    }
  });

  it('pulls three cards from the deck for each take', () => {
    const table = newTable(7);
    const trio = firstTrio(table.visible)!;
    const after = takeAt(table, trio)!;
    expect(after.triosTaken).toBe(1);
    expect(after.remaining.length).toBeLessThanOrEqual(table.remaining.length - 3);
  });

  it('refuses a trio it has already taken', () => {
    const table = newTable(11);
    const trio = firstTrio(table.visible)!;
    const ids = trio.map((index) => table.visible[index].id);
    const after = takeAt(table, trio)!;

    expect(takeByIds(after, ids)).toBeNull();
    expect(wouldFormTrioByIds(after, ids)).toBe(false);
  });

  it('judges by card id and not by position', () => {
    // Card ids run 0…80 and positions 0…11, so a real trio usually names cards
    // that are not even valid positions. Reading ids as positions refuses it.
    let sawIdsBeyondTheTable = false;
    for (let seed = 1; seed <= 40; seed += 1) {
      const table = newTable(seed);
      const trio = firstTrio(table.visible);
      if (!trio) continue;
      const ids = trio.map((index) => table.visible[index].id);
      expect(wouldFormTrioByIds(table, ids)).toBe(true);
      if (ids.some((id) => id >= table.visible.length)) sawIdsBeyondTheTable = true;
    }
    expect(sawIdsBeyondTheTable).toBe(true);
  });

  it('lists every trio on the table', () => {
    const table = newTable(5);
    for (const [i, j, k] of allTrios(table.visible)) {
      expect(isTrio(table.visible[i], table.visible[j], table.visible[k])).toBe(true);
    }
  });

  it('ignores a take it cannot apply rather than throwing the board away', () => {
    const table = newTable(2);
    const good = firstTrio(table.visible)!.map((index) => table.visible[index].id).sort();
    const replayed = replay(2, [good, good]);
    expect(replayed.triosTaken).toBe(1);
  });
});

/**
 * The table grows out of a dead end and shrinks back as soon as it can.
 *
 * The extra deal is a way out of a table with no trio, not a new size for the
 * board: a table of fifteen with a trio among the first twelve should be twelve
 * again, so the cards dealt last do not sit on the board while the game goes on
 * without them. The invariant is exact and holds after every take.
 */
describe('the size of the table', () => {
  const BASE = 12;

  it('is never bigger than it has to be, after any take', () => {
    for (let seed = 0; seed < 60; seed += 1) {
      let table = newTable(seed);
      let guard = 0;
      while (!isFinished(table) && guard < 60) {
        guard += 1;
        if (table.visible.length > BASE) {
          expect(
            firstTrio(table.visible.slice(0, BASE)),
            `seed ${seed} sat at ${table.visible.length} with a trio among the first ${BASE}`,
          ).toBeNull();
        }

        const trio = firstTrio(table.visible);
        if (!trio) break;
        const next = takeAt(table, trio);
        expect(next).not.toBeNull();
        table = next!;

        // Nothing is lost or invented by growing and shrinking again: every
        // card the deck has not dealt is still there, and a taken trio is gone
        // from the game when the deck runs out.
        expect(table.visible.length + table.remaining.length + 3 * table.triosTaken).toBe(81);
        expect(new Set(table.visible.map((card) => card.id)).size).toBe(table.visible.length);
      }
    }
  });

  it('gives back the cards it dealt to get unstuck', () => {
    // A table stuck at twelve grows; when a later take leaves twelve that can be
    // played again, the three it borrowed go back to the deck.
    let sawGrown = false;
    let sawShrink = false;

    for (let seed = 0; seed < 80 && !(sawGrown && sawShrink); seed += 1) {
      let table = newTable(seed);
      let guard = 0;
      while (!isFinished(table) && guard < 60) {
        guard += 1;
        const before = table.visible.length;
        const trio = firstTrio(table.visible);
        if (!trio) break;
        const next = takeAt(table, trio);
        if (!next) break;
        table = next;
        if (table.visible.length > before) sawGrown = true;
        if (table.visible.length === BASE && before > BASE) sawShrink = true;
      }
    }

    expect(sawGrown, 'no table in the sample ever needed an extra deal').toBe(true);
    expect(sawShrink, 'no table in the sample ever gave its cards back').toBe(true);
  });
});
