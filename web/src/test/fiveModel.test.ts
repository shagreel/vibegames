import { describe, it, expect } from 'vitest';
import {
  ALL_PACK_IDS,
  PACKS,
  categoriesIn,
  countIn,
} from '../games/five/packs';
import {
  ROUND_DURATION,
  TICK_WINDOW,
  advance,
  beginCountdown,
  initialState,
  primaryAction,
  primaryButtonTitle,
  progressAt,
  remainingAt,
  resetToReady,
  revealCategory,
  shuffled,
  statusBadge,
} from '../games/five/model';
import { PROMPTS } from '../games/five/prompts.generated';

describe('the category library', () => {
  it('has eleven packs of a hundred, as the Swift packs do', () => {
    expect(PACKS).toHaveLength(11);
    for (const pack of PACKS) {
      expect(PROMPTS[pack.id], `${pack.id} is missing`).toHaveLength(100);
    }
    expect(countIn(ALL_PACK_IDS)).toBe(1100);
  });

  it('never repeats a prompt across the whole library', () => {
    const all = categoriesIn(ALL_PACK_IDS).map((c) => c.text.toLowerCase());
    expect(new Set(all).size).toBe(all.length);
  });

  it('deals only from the packs that are switched on', () => {
    const only = categoriesIn(['food']);
    expect(only).toHaveLength(100);
    expect(only.every((c) => c.pack === 'food')).toBe(true);
    expect(countIn(['food', 'music'])).toBe(200);
  });

  it('falls back to everything rather than dealing nothing', () => {
    expect(categoriesIn([])).toHaveLength(1100);
  });
});

describe('the round', () => {
  it('opens hidden, with the clock stopped', () => {
    const state = initialState(ALL_PACK_IDS);
    expect(state.phase).toBe('ready');
    expect(state.category).toBeNull();
    expect(state.roundNumber).toBe(0);
    expect(remainingAt(state, 0)).toBe(ROUND_DURATION);
  });

  it('reveals a category without starting the clock', () => {
    // This is the whole shape of the game: the table reads the category out and
    // argues about it for as long as it likes, and nothing is counting.
    const revealed = revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS);

    expect(revealed.phase).toBe('revealed');
    expect(revealed.category).not.toBeNull();
    expect(revealed.roundNumber).toBe(1);
    expect(revealed.startedAt).toBeNull();
    expect(remainingAt(revealed, 999_999)).toBe(ROUND_DURATION);
    expect(primaryButtonTitle(revealed)).toBe('START');
  });

  it('offers no dial while the category is being read', () => {
    const revealed = revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS);
    expect(statusBadge(revealed)?.title).toBe('GET READY');
  });

  it('starts the clock on the second press, and says so', () => {
    let state = revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS);
    const result = primaryAction(state, ALL_PACK_IDS, 1_000);

    expect(result.state.phase).toBe('running');
    expect(result.cues).toEqual(['start']);
    expect(result.state.startedAt).toBe(1_000);
    expect(primaryButtonTitle(result.state)).toBe('Done!');
    expect(statusBadge(result.state)).toBeNull();

    // The button now says Done!, so a third press stops rather than restarts.
    state = result.state;
    const stopped = primaryAction(state, ALL_PACK_IDS, 3_000);
    expect(stopped.state.phase).toBe('stopped');
    expect(stopped.cues).toEqual([]); // stopping early is deliberately silent
  });

  it('counts down against the wall clock, not against ticks', () => {
    const started = beginCountdown(
      revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS),
      10_000,
    ).state;

    expect(remainingAt(started, 10_000)).toBe(5);
    expect(remainingAt(started, 11_000)).toBe(4);
    expect(remainingAt(started, 12_500)).toBe(2.5);
    expect(remainingAt(started, 15_000)).toBe(0);
    // A tab that was throttled and came back late must not run negative.
    expect(remainingAt(started, 99_000)).toBe(0);
    expect(progressAt(started, 10_000)).toBe(1);
    expect(progressAt(started, 12_500)).toBeCloseTo(0.5);
  });

  it('freezes the time left when the player stops early', () => {
    const started = beginCountdown(
      revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS),
      0,
    ).state;
    const stopped = primaryAction(started, ALL_PACK_IDS, 2_000).state;

    expect(stopped.phase).toBe('stopped');
    expect(stopped.frozenRemaining).toBeCloseTo(3);
    expect(remainingAt(stopped, 99_000)).toBeCloseTo(3);
    expect(statusBadge(stopped)?.title).toBe('STOPPED');
  });

  it('ticks the last three seconds, once each, then buzzes', () => {
    let state = beginCountdown(
      revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS),
      0,
    ).state;

    const heard: string[] = [];
    // Stepped the way the real ticker steps it.
    for (let ms = 0; ms <= 5_000; ms += 50) {
      const result = advance(state, ms);
      state = result.state;
      heard.push(...result.cues);
    }

    expect(heard.filter((cue) => cue === 'tick')).toHaveLength(TICK_WINDOW);
    expect(heard.filter((cue) => cue === 'buzzer')).toHaveLength(1);
    // The buzzer comes last, and only once.
    expect(heard[heard.length - 1]).toBe('buzzer');
    expect(state.phase).toBe('buzzed');
    expect(state.startedAt).toBeNull();
    expect(statusBadge(state)?.title).toBe("TIME'S UP!");
    expect(primaryButtonTitle(state)).toBe('NEXT');
  });

  it('does not tick a second time within the same second', () => {
    // The ticker runs at 20Hz, so a naive implementation would fire five times
    // a second and sound like a rattle.
    let state = beginCountdown(
      revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS),
      0,
    ).state;

    let ticks = 0;
    for (let ms = 0; ms <= 4_000; ms += 50) {
      const result = advance(state, ms);
      state = result.state;
      ticks += result.cues.filter((cue) => cue === 'tick').length;
    }
    expect(ticks).toBe(TICK_WINDOW);
  });

  it('deals the next category from the buzzer, and a round later', () => {
    const first = revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS);
    const buzzed = { ...first, phase: 'buzzed' as const };
    const next = primaryAction(buzzed, ALL_PACK_IDS, 0).state;

    expect(next.phase).toBe('revealed');
    expect(next.roundNumber).toBe(2);
    expect(next.startedAt).toBeNull();
  });

  it('goes back to ready without losing the round count', () => {
    const played = revealCategory(initialState(ALL_PACK_IDS), ALL_PACK_IDS);
    const reset = resetToReady(played);

    expect(reset.phase).toBe('ready');
    expect(reset.category).toBeNull();
    expect(reset.roundNumber).toBe(1);
  });

  it('never deals the same category twice in a row', () => {
    const deck = categoriesIn(ALL_PACK_IDS);
    const current = deck[7];
    for (let attempt = 0; attempt < 50; attempt += 1) {
      const pool = shuffled(ALL_PACK_IDS, current);
      expect(pool[0].text === current.text && pool[0].pack === current.pack).toBe(false);
    }
  });

  it('keeps dealing when the deck runs out', () => {
    // A one-pack game of 100 categories: the 101st draw must reshuffle rather
    // than hand back nothing.
    let state = initialState(['food']);
    const seen = new Set<string>();
    for (let round = 0; round < 130; round += 1) {
      state = { ...state, phase: 'ready' };
      state = primaryAction(state, ['food'], 0).state;
      expect(state.category).not.toBeNull();
      seen.add(state.category!.text);
    }
    expect(state.roundNumber).toBe(130);
    expect(seen.size).toBeGreaterThan(1);
    expect([...seen].every((text) => PROMPTS.food.includes(text))).toBe(true);
  });
});
