import { ALL_PACK_IDS, categoriesIn, type PackId, type VibeCategory } from './packs';

/**
 * One round of Vibe Five, as a pure state machine.
 *
 * Mirrors `VibeFiveModel.swift`. The clock is derived from a wall-clock
 * `startedAt` rather than accumulated ticks, so the countdown stays accurate
 * even if the browser throttles timers — which it does aggressively in a
 * background tab, and would otherwise leave a round stuck part-way down.
 *
 * Nothing here touches the DOM, the clock or audio: everything takes `now` and
 * returns cues for the caller to play, so the whole game can be tested by
 * passing in made-up times.
 */

export const ROUND_DURATION = 5;
/** How many of the final whole seconds get an audible tick. */
export const TICK_WINDOW = 3;

export type Phase = 'ready' | 'revealed' | 'running' | 'stopped' | 'buzzed';

export type Cue = 'start' | 'tick' | 'buzzer';

export interface FiveState {
  phase: Phase;
  category: VibeCategory | null;
  roundNumber: number;
  /** Milliseconds, or null when the clock is not running. */
  startedAt: number | null;
  /** Seconds left when the player pressed Done!. */
  frozenRemaining: number;
  deck: VibeCategory[];
  deckIndex: number;
  /** Only used to fire one tick per whole second. */
  lastWholeSecond: number | null;
}

export function initialState(enabled: readonly PackId[]): FiveState {
  return {
    phase: 'ready',
    category: null,
    roundNumber: 0,
    startedAt: null,
    frozenRemaining: 0,
    deck: shuffled(enabled, null),
    deckIndex: 0,
    lastWholeSecond: null,
  };
}

/**
 * Reshuffles the enabled prompts, avoiding an immediate repeat of the category
 * currently on screen — dealing the same card twice in a row reads as a bug.
 */
export function shuffled(enabled: readonly PackId[], current: VibeCategory | null): VibeCategory[] {
  const pool = categoriesIn(enabled);
  for (let i = pool.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  if (pool.length > 1 && current && pool[0].text === current.text && pool[0].pack === current.pack) {
    [pool[0], pool[pool.length - 1]] = [pool[pool.length - 1], pool[0]];
  }
  return pool;
}

/** Seconds left, evaluated at an arbitrary instant so the ring can animate. */
export function remainingAt(state: FiveState, now: number): number {
  switch (state.phase) {
    case 'ready':
    case 'revealed':
      return ROUND_DURATION;
    case 'running':
      return state.startedAt == null
        ? ROUND_DURATION
        : Math.max(0, ROUND_DURATION - (now - state.startedAt) / 1000);
    case 'stopped':
      return state.frozenRemaining;
    case 'buzzed':
      return 0;
  }
}

/** 1 at the moment the clock starts, 0 at the buzzer. */
export function progressAt(state: FiveState, now: number): number {
  return remainingAt(state, now) / ROUND_DURATION;
}

function drawCategory(state: FiveState, enabled: readonly PackId[]): [VibeCategory, FiveState] {
  let deck = state.deck;
  let deckIndex = state.deckIndex;
  if (deckIndex >= deck.length) {
    deck = shuffled(enabled, state.category);
    deckIndex = 0;
  }
  if (deckIndex >= deck.length) {
    // Only reachable if every pack were somehow empty.
    return [{ text: 'Anything you like', pack: 'random' }, { ...state, deck, deckIndex }];
  }
  return [deck[deckIndex], { ...state, deck, deckIndex: deckIndex + 1 }];
}

/** Deals a category and shows it. The clock deliberately does not start. */
export function revealCategory(
  state: FiveState,
  enabled: readonly PackId[],
): FiveState {
  const [category, next] = drawCategory(state, enabled);
  return {
    ...next,
    category,
    roundNumber: state.roundNumber + 1,
    startedAt: null,
    lastWholeSecond: null,
    frozenRemaining: 0,
    phase: 'revealed',
  };
}

export function beginCountdown(state: FiveState, now: number): { state: FiveState; cues: Cue[] } {
  if (state.phase !== 'revealed') return { state, cues: [] };
  return {
    state: { ...state, startedAt: now, lastWholeSecond: null, phase: 'running' },
    cues: ['start'],
  };
}

/** Ends the round early at the player's request. Deliberately silent. */
export function stopRound(state: FiveState, now: number): FiveState {
  if (state.phase !== 'running' || state.startedAt == null) return state;
  return {
    ...state,
    frozenRemaining: Math.max(0, ROUND_DURATION - (now - state.startedAt) / 1000),
    startedAt: null,
    phase: 'stopped',
  };
}

/**
 * The one button: Start, Start again for the clock, Done!, or Next.
 */
export function primaryAction(
  state: FiveState,
  enabled: readonly PackId[],
  now: number,
): { state: FiveState; cues: Cue[] } {
  switch (state.phase) {
    case 'ready':
    case 'stopped':
    case 'buzzed':
      return { state: revealCategory(state, enabled), cues: [] };
    case 'revealed':
      return beginCountdown(state, now);
    case 'running':
      return { state: stopRound(state, now), cues: [] };
  }
}

/**
 * Advances the clock to `now`, returning any cues that fell due.
 *
 * Called on a timer rather than per frame, so the ticks are decided here rather
 * than by whatever rate the browser happens to run at.
 */
export function advance(state: FiveState, now: number): { state: FiveState; cues: Cue[] } {
  if (state.phase !== 'running' || state.startedAt == null) return { state, cues: [] };

  const remaining = ROUND_DURATION - (now - state.startedAt) / 1000;
  const whole = Math.ceil(remaining);
  const cues: Cue[] = [];
  let next = state;

  if (whole !== state.lastWholeSecond) {
    next = { ...next, lastWholeSecond: whole };
    if (whole >= 1 && whole <= TICK_WINDOW) cues.push('tick');
  }

  if (remaining <= 0) {
    next = { ...next, startedAt: null, frozenRemaining: 0, phase: 'buzzed' };
    cues.push('buzzer');
  }

  return { state: next, cues };
}

/** Back to the opening state, keeping the deck position and round count. */
export function resetToReady(state: FiveState): FiveState {
  return {
    ...state,
    phase: 'ready',
    category: null,
    startedAt: null,
    frozenRemaining: 0,
    lastWholeSecond: null,
  };
}

export function primaryButtonTitle(state: FiveState): string {
  switch (state.phase) {
    case 'ready':
    case 'revealed':
      return 'START';
    case 'running':
      return 'Done!';
    case 'stopped':
    case 'buzzed':
      return 'NEXT';
  }
}

export function primaryHint(state: FiveState): string {
  switch (state.phase) {
    case 'ready':
      return 'Reveals a category';
    case 'revealed':
      return 'Starts the five second clock';
    case 'running':
      return 'Ends the round early';
    case 'stopped':
      return 'Deals the next category';
    case 'buzzed':
      return 'Reveals the next category';
  }
}

/** The badge that announces the current state, when it needs one. */
export function statusBadge(state: FiveState): { title: string; tone: string } | null {
  switch (state.phase) {
    case 'revealed':
      return { title: 'GET READY', tone: 'arm' };
    case 'buzzed':
      return { title: "TIME'S UP!", tone: 'danger' };
    case 'stopped':
      return { title: 'STOPPED', tone: 'go' };
    case 'ready':
    case 'running':
      return null;
  }
}

export { ALL_PACK_IDS };
