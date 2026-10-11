import { describe, it, expect } from 'vitest';
import fixtures from '../games/blurt/engine.fixtures.json';
import {
  DURATIONS,
  TARGET,
  describerFor,
  describerOffsets,
  describingTeam,
  membersOf,
  nearestDuration,
  scoringTeam,
  split,
  winner,
  wordAt,
  wordsIn,
  shuffled,
} from '../games/blurt/engine';
import { PACK_ORDER, PACK_WORDS } from '../games/blurt/words.generated';

/**
 * The browser's Vibe Blurt rules against the ones the phone runs.
 *
 * This is the test that matters most in the whole game. A room stores a seed, a
 * round and the packs — never the words — so every device derives the deck
 * itself. If the browser shuffled one way and the phone another, the describer
 * would be describing one thing while every other screen scored something else,
 * and it would look like a rules bug rather than a determinism bug.
 *
 * The fixtures are dumped from Swift by `Tools/blurt_fixtures/`.
 */

const ALL = PACK_ORDER;

describe('the word packs', () => {
  it('are the same eight packs, in the same order, as the app', () => {
    expect(PACK_ORDER).toEqual(fixtures.packOrder);
  });

  it('hold exactly the words the app holds', () => {
    for (const id of fixtures.packOrder) {
      expect(PACK_WORDS[id], `pack ${id}`).toEqual(fixtures.packs[id as keyof typeof fixtures.packs]);
    }
  });

  it('add up to the whole deck, with nothing repeated', () => {
    const every = PACK_ORDER.flatMap((id) => PACK_WORDS[id]);
    expect(every).toHaveLength(fixtures.wordCount);
    expect(new Set(every).size).toBe(fixtures.wordCount);
  });

  it('concatenate in pack order, not in the order they were ticked', () => {
    // Two people ticking the same boxes in a different order must still deal
    // the same deck.
    const one = wordsIn(['food', 'play']);
    const two = wordsIn(['play', 'food']);
    expect(one).toEqual(two);
    expect(one).toEqual([...PACK_WORDS.food, ...PACK_WORDS.play]);
  });

  it('treat an empty selection as every pack, not as no words', () => {
    expect(wordsIn([])).toEqual(PACK_ORDER.flatMap((id) => PACK_WORDS[id]));
  });
});

describe('the deck', () => {
  it('comes out exactly as the app lays it out, for every seed', () => {
    for (const [seed, deck] of Object.entries(fixtures.decks)) {
      expect(shuffled(Number(seed), 0, ALL), `seed ${seed}`).toEqual(deck);
    }
  });

  it('agrees with the app when only some packs are on', () => {
    for (const [seed, deck] of Object.entries(fixtures.subsetDecks)) {
      expect(shuffled(Number(seed), 0, fixtures.packsChosen), `seed ${seed}`).toEqual(deck);
    }
  });

  it('agrees with the app about what "play again" deals', () => {
    for (const [round, deck] of Object.entries(fixtures.roundDecks)) {
      expect(shuffled(42, Number(round), ALL), `round ${round}`).toEqual(deck);
    }
    // The round, not a new seed, is what makes the second game different.
    expect(fixtures.roundDecks['0']).not.toEqual(fixtures.roundDecks['1']);
  });

  it('wraps rather than running out mid-turn', () => {
    const deck = shuffled(3, 0, ALL);
    expect(wordAt(0, deck)).toBe(deck[0]);
    expect(wordAt(deck.length, deck)).toBe(deck[0]);
    expect(wordAt(-1, deck)).toBe(deck[deck.length - 1]);
    expect(wordAt(0, [])).toBe('');
  });
});

describe('the teams', () => {
  it('split the same way as the app, for every roster', () => {
    for (const [key, expected] of Object.entries(fixtures.splits)) {
      const [seed, size] = key.split(':').map(Number);
      const roster = Array.from({ length: size }, (_, i) => `p${i + 1}`);
      expect(split(roster, seed), key).toEqual(expected);
    }
  });

  it('are balanced', () => {
    for (let size = 2; size <= 9; size += 1) {
      const roster = Array.from({ length: size }, (_, i) => `p${i + 1}`);
      const teams = split(roster, 99);
      const one = membersOf(1, teams).length;
      const two = membersOf(2, teams).length;
      expect(one + two).toBe(size);
      expect(Math.abs(one - two)).toBeLessThanOrEqual(1);
      expect(one).toBeGreaterThan(0);
      expect(two).toBeGreaterThan(0);
    }
  });

  it('do not depend on the order people arrived in', () => {
    expect(split(['p1', 'p2', 'p3', 'p4', 'p5'], 12)).toEqual(
      split(['p4', 'p1', 'p5', 'p2', 'p3'], 12),
    );
  });
});

describe('the turn order', () => {
  it('alternates, with team one starting', () => {
    expect([0, 1, 2, 3].map(describingTeam)).toEqual([1, 2, 1, 2]);
  });

  it('draws the same starting offsets as the app', () => {
    for (const [key, expected] of Object.entries(fixtures.offsets)) {
      const [seed, size] = key.split(':').map(Number);
      const teams = split(
        Array.from({ length: size }, (_, i) => `p${i + 1}`),
        seed,
      );
      const one = membersOf(1, teams).length;
      const two = membersOf(2, teams).length;
      expect(describerOffsets(one, two, seed), key).toEqual(expected);
    }
  });

  it('hands the word to the same people the app does, turn for turn', () => {
    for (const [key, expected] of Object.entries(fixtures.describers)) {
      const [seed, size] = key.split(':').map(Number);
      const roster = Array.from({ length: size }, (_, i) => `p${i + 1}`);
      const teams = split(roster, seed);
      const one = membersOf(1, teams);
      const two = membersOf(2, teams);
      const offsets = describerOffsets(one.length, two.length, seed);

      const actual = expected.map((_, turn) => {
        const team = describingTeam(turn);
        const members = team === 1 ? one : two;
        const offset = team === 1 ? offsets.one : offsets.two;
        return describerFor(members, turn, offset);
      });

      expect(actual, key).toEqual(expected);
    }
  });

  it('has nobody to describe with an empty team', () => {
    expect(describerFor([], 0, 0)).toBeNull();
  });
});

describe('the scoring', () => {
  it('pays the team that was not holding the word', () => {
    for (const [turn, expected] of Object.entries(fixtures.scoring)) {
      const describing = describingTeam(Number(turn));
      expect(describing, `turn ${turn} describing`).toBe(expected.describing);
      expect(scoringTeam(describing), `turn ${turn} scoring`).toBe(expected.scoring);
    }
  });

  it('ends at the same target', () => {
    expect(TARGET).toBe(fixtures.target);
  });

  it('declares the same winner', () => {
    for (const [key, expected] of Object.entries(fixtures.winners)) {
      const [one, two] = key.split('-').map(Number);
      expect(winner(one, two), key).toBe(expected === 'nil' ? null : Number(expected));
    }
  });
});

describe('the turn lengths', () => {
  it('offers the same options as the app', () => {
    expect(DURATIONS.map((option) => option.seconds)).toEqual(
      Object.values(fixtures.durations).sort((a, b) => a - b),
    );
  });

  it('rounds an unexpected value to the same nearest option', () => {
    for (const [seconds, expected] of Object.entries(fixtures.nearestDuration)) {
      expect(nearestDuration(Number(seconds)).seconds, `${seconds}s`).toBe(expected);
    }
  });
});
