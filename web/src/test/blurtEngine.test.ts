import { describe, it, expect } from 'vitest';
import fixtures from '../games/blurt/engine.fixtures.json';
import {
  LONGEST_SECONDS,
  MINIMUM_PLAYERS,
  MINIMUM_PER_TEAM,
  SHORTEST_SECONDS,
  STEADY_INTERVAL,
  STEADY_VOLUME,
  TAIL_FRACTION,
  TARGET,
  TEAMS,
  URGENT_INTERVAL,
  URGENT_VOLUME,
  barFill,
  describerFor,
  describerOffsets,
  describingTeam,
  holderFor,
  membersOf,
  namesOn,
  randomTurnSeconds,
  scoringTeam,
  split,
  tickInterval,
  tickSchedule,
  tickVolume,
  urgency,
  winner,
  wordAt,
  wordsIn,
  shuffled,
  type Team,
} from '../games/blurt/engine';
import { PACK_ORDER, PACK_WORDS } from '../games/blurt/words.generated';

/**
 * The browser's Similar Vibe rules against the ones the phone runs.
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
      expect(shuffled(Number(seed), ALL), `seed ${seed}`).toEqual(deck);
    }
  });

  it('agrees with the app when only some packs are on', () => {
    for (const [seed, deck] of Object.entries(fixtures.subsetDecks)) {
      expect(shuffled(Number(seed), fixtures.packsChosen), `seed ${seed}`).toEqual(deck);
    }
  });

  it('wraps rather than running out mid-turn', () => {
    const deck = shuffled(3, ALL);
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

  it('never leaves the word with one team for two words running', () => {
    // This is the mechanic, not a detail: pressing "got it" is what moves the
    // word to the other side, so nobody is ever caught twice in a row.
    for (let turn = 0; turn < 12; turn += 1) {
      expect(describingTeam(turn), `turn ${turn}`).not.toBe(describingTeam(turn + 1));
    }
  });

  it('goes round everybody in the same order every time', () => {
    // Four players, two a side: A's first, B's first, A's second, B's second,
    // and then it starts again.
    const roster = ['p1', 'p2', 'p3', 'p4'];
    const teams = split(roster, 3);
    const one = membersOf(1, teams);
    const two = membersOf(2, teams);
    const offsets = describerOffsets(one.length, two.length, 3);

    const order = Array.from({ length: 8 }, (_, turn) => {
      const team = describingTeam(turn);
      const members = team === 1 ? one : two;
      return describerFor(members, turn, team === 1 ? offsets.one : offsets.two);
    });

    expect(order.slice(0, 4)).toEqual(order.slice(4, 8));
    expect(new Set(order)).toEqual(new Set(roster));
  });

  it('needs two people on each side', () => {
    expect(MINIMUM_PER_TEAM).toBe(fixtures.minimumPerTeam);
    expect(MINIMUM_PLAYERS).toBe(fixtures.minimumPlayers);
    expect(MINIMUM_PLAYERS).toBe(MINIMUM_PER_TEAM * 2);
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

  it('skips a player who has left without giving anyone two turns running', () => {
    const members = ['ann', 'bo', 'cass', 'dee'];
    const withoutBo = new Set(['ann', 'cass', 'dee']);
    const turns = [0, 2, 4, 6];

    expect(turns.map((turn) => describerFor(members, turn, 0)))
      .toEqual(['ann', 'bo', 'cass', 'dee']);

    // Taking bo out rather than standing somebody in for them. Walking forward
    // to the next person instead would give cass turns 2 and 4.
    expect(turns.map((turn) => describerFor(members, turn, 0, withoutBo)))
      .toEqual(['ann', 'cass', 'dee', 'ann']);

    expect(describerFor(members, 2, 0, new Set())).toBeNull();
    expect(describerFor(members, 2, 0, new Set(members))).toBe('bo');
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

describe('the round length and its hurry', () => {
  // Everything here is pinned against the Swift model in `engine.fixtures.json`.
  // Both platforms decide when the ticking hurries and when the bar pulses from
  // these numbers, so a disagreement would look like a bug in whichever device
  // the player was not holding.

  it('agrees with the app about the length of a round', () => {
    expect(SHORTEST_SECONDS).toBe(fixtures.timing.shortest);
    expect(LONGEST_SECONDS).toBe(fixtures.timing.longest);
    expect(TAIL_FRACTION).toBe(fixtures.timing.tailFraction);
    expect(STEADY_INTERVAL).toBe(fixtures.timing.steadyInterval);
    expect(URGENT_INTERVAL).toBe(fixtures.timing.urgentInterval);
    expect(STEADY_VOLUME).toBe(fixtures.timing.steadyVolume);
    expect(URGENT_VOLUME).toBe(fixtures.timing.urgentVolume);
  });

  it('draws a length inside the range, and not the same one every time', () => {
    const seen = new Set<number>();
    for (let i = 0; i < 400; i += 1) {
      const seconds = randomTurnSeconds();
      expect(seconds).toBeGreaterThanOrEqual(SHORTEST_SECONDS);
      expect(seconds).toBeLessThanOrEqual(LONGEST_SECONDS);
      seen.add(seconds);
    }
    // A length a table can learn is a length a table counts down out loud.
    expect(seen.size).toBeGreaterThan(10);
  });

  it('agrees with the app on urgency across the whole round', () => {
    const total = fixtures.timing.sampleTotal;
    for (const [percent, expected] of Object.entries(fixtures.timing.urgencyAt)) {
      const remaining = total * (1 - Number(percent) / 100);
      expect(urgency(remaining, total), `${percent}%`).toBe(expected);
    }
  });

  it('agrees with the app on how full the bar is', () => {
    const total = fixtures.timing.sampleTotal;
    for (const [percent, expected] of Object.entries(fixtures.timing.barFillAt)) {
      const remaining = total * (1 - Number(percent) / 100);
      expect(barFill(remaining, total), `${percent}%`).toBe(expected);
    }
  });

  it('agrees with the app on the tick schedule', () => {
    const total = fixtures.timing.sampleTotal;
    expect(tickSchedule(total)).toEqual(fixtures.timing.schedule);
  });

  it('is not urgent until the last of the round, then is', () => {
    const total = 60;
    expect(urgency(total, total)).toBe(0);
    expect(urgency(total * 0.5, total)).toBe(0);
    expect(urgency(total * 0.15, total)).toBe(0);
    expect(urgency(total * 0.1, total)).toBeCloseTo(1 / 3, 10);
    expect(urgency(0, total)).toBe(1);
  });

  it('spends the bar before the round is spent', () => {
    const total = 60;
    expect(barFill(total, total)).toBe(0);
    // Full with a sixth of the round still to play, so the bar running out
    // cannot be read as the buzzer.
    expect(barFill(total * 0.15, total)).toBe(1);
    expect(barFill(total * 0.01, total)).toBe(1);
    expect(barFill(0, total)).toBe(1);

    // And it only ever fills.
    let last = 0;
    for (let percent = 0; percent <= 100; percent += 1) {
      const fill = barFill(total * (1 - percent / 100), total);
      expect(fill).toBeGreaterThanOrEqual(last);
      last = fill;
    }
  });

  it('hurries and gets louder, but never becomes a tone', () => {
    expect(tickInterval(0)).toBe(STEADY_INTERVAL);
    expect(tickInterval(1)).toBeLessThan(STEADY_INTERVAL);
    expect(tickInterval(1)).toBeGreaterThan(0.05);
    expect(tickVolume(0)).toBe(STEADY_VOLUME);
    expect(tickVolume(1)).toBe(URGENT_VOLUME);
  });

  it('lays out a steady schedule that hurries at the end', () => {
    const total = 60;
    const schedule = tickSchedule(total);
    expect(schedule.length).toBeGreaterThan(0);

    // In order, inside the round, none after the buzzer.
    let previous = 0;
    for (const tick of schedule) {
      expect(tick.at).toBeGreaterThan(previous);
      expect(tick.at).toBeLessThan(total);
      previous = tick.at;
    }

    // The early gaps are all the steady interval.
    const tailStart = total * (1 - TAIL_FRACTION);
    const early = schedule.filter((tick, index) => index > 0 && tick.at < tailStart);
    expect(early.length).toBeGreaterThan(0);
    for (const tick of early) {
      const before = schedule[schedule.indexOf(tick) - 1];
      expect(tick.at - before.at).toBe(STEADY_INTERVAL);
    }

    // And the last gap is hurrying.
    const lastGap = schedule[schedule.length - 1].at - schedule[schedule.length - 2].at;
    expect(lastGap).toBeLessThan(STEADY_INTERVAL / 2);
  });
});

describe('who is holding the word', () => {
  it('matches the Swift engine, case for case', () => {
    // The fixtures are dumped from Swift by `Tools/blurt_fixtures/`, so this is
    // the check that the two engines agree about whose phone shows the word —
    // which, like the deck itself, is derived rather than written down.
    // `fromEntries` rather than indexing the JSON: its keys are literal types.
    const splits: Record<string, Record<string, number>> = Object.fromEntries(
      Object.entries(fixtures.splits),
    );
    const describers: Record<string, string[]> = Object.fromEntries(
      Object.entries(fixtures.describers),
    );

    for (const [key, cases] of Object.entries(fixtures.holders)) {
      const [seed] = key.split(':').map(Number);
      const teams = splits[key] as Record<string, Team>;
      const everyone = Object.keys(teams).sort();
      const named = describers[key];

      for (const scenario of cases) {
        const absent = new Set(scenario.absent);
        const players: Record<string, string> = {};
        for (const id of everyone) if (!absent.has(id)) players[id] = id.toUpperCase();

        const holder = holderFor(
          { describer: named[scenario.turn], team: describingTeam(scenario.turn), turn: scenario.turn },
          { players, teams },
          seed,
        );

        expect(holder ?? '', `${key} turn ${scenario.turn}, gone: ${scenario.absent.join()}`)
          .toBe(scenario.holder);
      }
    }
  });

  it('keeps the word with the named describer while they are here', () => {
    const teams: Record<string, Team> = { a: 1, b: 1, c: 2, d: 2 };
    const here = { a: 'Alex', b: 'Bo', c: 'Cass', d: 'Dee' };
    const holder = holderFor({ describer: 'a', team: 1, turn: 0 }, { players: here, teams }, 7);
    expect(holder).toBe('a');
  });

  it('moves it to somebody still in the room when they leave', () => {
    // The whole point: a round whose describer has gone is a round nobody can
    // play — the other side is told to watch for a person who is not there.
    const teams: Record<string, Team> = { a: 1, b: 1, c: 2, d: 2 };
    const holder = holderFor(
      { describer: 'a', team: 1, turn: 0 },
      { players: { b: 'Bo', c: 'Cass', d: 'Dee' }, teams },
      7,
    );
    expect(holder).toBe('b');
    expect(holder).not.toBe('a');
  });

  it('names nobody when the whole of the describing side has gone', () => {
    const teams: Record<string, Team> = { a: 1, b: 1, c: 2, d: 2 };
    const holder = holderFor(
      { describer: 'a', team: 1, turn: 0 },
      { players: { c: 'Cass', d: 'Dee' }, teams },
      7,
    );
    expect(holder).toBeNull();
  });
});

describe('the scoreboard names', () => {
  /** Just the two parts of a room `namesOn` reads. */
  const room = (players: Record<string, string>, teams: Record<string, Team>) => ({
    players,
    teams,
  });

  it('shows only the people who are actually in the room', () => {
    // A team slot deliberately outlives the player sitting in it — that is what
    // puts somebody back on their own side when they return — so `teams` still
    // lists them long after they have gone. They must not reach the scoreboard.
    expect(namesOn(room({ a: 'Alex', c: 'Jo' }, { a: 1, b: 1, c: 2 }), 1)).toEqual(['Alex']);
  });

  it('says nothing at all when a side has emptied out', () => {
    // Not an empty line where the names used to be, and never a stand-in name.
    expect(namesOn(room({}, { a: 1, b: 1 }), 1)).toEqual([]);
    expect(namesOn(room({ z: 'Zoe' }, { a: 1, b: 2 }), 1)).toEqual([]);
  });

  it('keeps each side to its own players, in a stable order', () => {
    const both = room({ a: 'Alex', b: 'Jo', c: 'Sam' }, { a: 1, b: 2, c: 1 });
    expect(namesOn(both, 1)).toEqual(['Alex', 'Sam']);
    expect(namesOn(both, 2)).toEqual(['Jo']);
  });

  it('never puts the word "Someone" on the board', () => {
    // The exact regression: a slot with nobody in it was named "Someone", so a
    // scoreboard read "Alex, Someone" for a table of one.
    const halfEmpty = room({ a: 'Alex' }, { a: 1, b: 1, c: 2, d: 2 });
    const shown = TEAMS.flatMap((team) => namesOn(halfEmpty, team)).join(', ');
    expect(shown).not.toContain('Someone');
    expect(shown).toBe('Alex');
  });
});
