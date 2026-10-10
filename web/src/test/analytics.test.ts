import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

/**
 * Analytics.
 *
 * Two things are worth testing here and the rest follows from them. First, that
 * nothing leaves the browser until a measurement id has been filled in — the
 * difference between "off" and "on" has to be real, not a matter of trust.
 * Second, that a counter can never throw into the app: these calls sit inside
 * the router's announce and inside React effects, where an exception would be a
 * broken game rather than a missing data point.
 */

const { logEvent, initializeAnalytics, setAnalyticsCollectionEnabled, isSupported } = vi.hoisted(
  () => ({
    // Typed rather than given dummy parameters, so the recorded calls can be
    // indexed without TypeScript reading the tuple as empty — and without a row
    // of unused arguments that lint would rightly complain about.
    logEvent: vi.fn<(analytics: unknown, name: string, params?: unknown) => void>(),
    initializeAnalytics: vi.fn<(app: unknown, options?: unknown) => { fake: string }>(() => ({
      fake: 'analytics',
    })),
    setAnalyticsCollectionEnabled: vi.fn<(analytics: unknown, enabled: boolean) => void>(),
    isSupported: vi.fn<() => Promise<boolean>>(async () => true),
  }),
);

vi.mock('firebase/analytics', () => ({
  logEvent,
  initializeAnalytics,
  setAnalyticsCollectionEnabled,
  isSupported,
}));

// Mocked so that importing the module does not drag in a real Firebase app
// built from environment variables that a test environment does not have.
vi.mock('../firebase', () => ({ app: { name: 'test' } }));

/** A fresh copy of the module, with the measurement id set or not. */
async function fresh(measurementId: string) {
  vi.resetModules();
  vi.stubEnv('VITE_FIREBASE_MEASUREMENT_ID', measurementId);
  return import('../analytics');
}

/** The parameters of the nth call to `logEvent`, if any. */
function paramsOf(index: number): Record<string, unknown> {
  return (logEvent.mock.calls[index]?.[2] ?? {}) as Record<string, unknown>;
}

function eventNames(): string[] {
  return logEvent.mock.calls.map((call) => call[1] as string);
}

beforeEach(() => {
  logEvent.mockClear();
  initializeAnalytics.mockClear();
  setAnalyticsCollectionEnabled.mockClear();
  isSupported.mockReset();
  isSupported.mockResolvedValue(true);
  window.history.replaceState({}, '', '/');
});

afterEach(() => {
  vi.unstubAllEnvs();
  vi.resetModules();
});

describe('installAnalytics', () => {
  it('does nothing at all without a measurement id', async () => {
    const analytics = await fresh('');

    await analytics.installAnalytics();

    expect(analytics.isTracking()).toBe(false);
    // Not merely quiet: the library is never even loaded.
    expect(initializeAnalytics).not.toHaveBeenCalled();
    expect(logEvent).not.toHaveBeenCalled();
  });

  it('brings Analytics up and reports the page already on screen', async () => {
    window.history.replaceState({}, '', '/trio');
    const analytics = await fresh('G-TEST123');

    await analytics.installAnalytics();

    expect(analytics.isTracking()).toBe(true);
    expect(setAnalyticsCollectionEnabled).toHaveBeenCalled();
    expect(eventNames()).toEqual(['page_view']);
    expect(paramsOf(0)).toMatchObject({ page_path: '/trio', screen_name: 'vibe-trio' });
  });

  it('switches off the automatic page view, so the first load is not counted twice', async () => {
    const analytics = await fresh('G-TEST123');

    await analytics.installAnalytics();

    expect(initializeAnalytics.mock.calls[0][1]).toMatchObject({
      config: { send_page_view: false },
    });
  });

  it('stays quiet in a browser that will not support it', async () => {
    isSupported.mockResolvedValue(false);
    const analytics = await fresh('G-TEST123');

    await analytics.installAnalytics();

    expect(analytics.isTracking()).toBe(false);
    expect(logEvent).not.toHaveBeenCalled();
  });

  it('survives the library refusing to load', async () => {
    initializeAnalytics.mockImplementationOnce(() => {
      throw new Error('blocked by an extension');
    });
    const analytics = await fresh('G-TEST123');

    await expect(analytics.installAnalytics()).resolves.toBeUndefined();
    expect(analytics.isTracking()).toBe(false);
  });

  it('sends nothing before it has been installed', async () => {
    const analytics = await fresh('G-TEST123');

    analytics.trackGameStart(analytics.GAMES.trio, { mode: 'solo' });
    analytics.trackPageView('/trio');

    expect(logEvent).not.toHaveBeenCalled();
  });
});

describe('trackPageView', () => {
  async function ready() {
    const analytics = await fresh('G-TEST123');
    await analytics.installAnalytics();
    logEvent.mockClear();
    return analytics;
  }

  it('counts a route once, however often it is announced', async () => {
    const analytics = await ready();

    analytics.trackPageView('/trio');
    analytics.trackPageView('/trio');
    analytics.trackPageView('/trio');

    expect(logEvent).toHaveBeenCalledTimes(1);
  });

  it('counts leaving and coming back as two visits', async () => {
    const analytics = await ready();

    analytics.trackPageView('/trio');
    analytics.trackPageView('/');
    analytics.trackPageView('/trio');

    expect(eventNames()).toEqual(['page_view', 'page_view', 'page_view']);
  });

  it('names each screen the way the iOS app names it', async () => {
    const analytics = await ready();

    for (const path of ['/five', '/words', '/sudoku', '/trio', '/']) {
      analytics.trackPageView(path);
    }

    expect(logEvent.mock.calls.map((call) => paramsOf(logEvent.mock.calls.indexOf(call)).screen_name))
      .toEqual(['vibe-five', 'vibe-words', 'vibe-sudoku', 'vibe-trio', 'hub']);
  });

  it('calls an unrecognised path unknown rather than guessing', async () => {
    const analytics = await ready();

    analytics.trackPageView('/nonsense');

    expect(paramsOf(0).screen_name).toBe('unknown');
  });
});

describe('game events', () => {
  async function ready() {
    const analytics = await fresh('G-TEST123');
    await analytics.installAnalytics();
    logEvent.mockClear();
    return analytics;
  }

  it('reports a start with its mode and round', async () => {
    const analytics = await ready();

    analytics.trackGameStart(analytics.GAMES.five, { mode: 'solo', round: 3 });

    expect(logEvent.mock.calls[0][1]).toBe('game_start');
    expect(paramsOf(0)).toEqual({ game_name: 'vibe-five', mode: 'solo', round: 3 });
  });

  it('reports a finish with its outcome and score', async () => {
    const analytics = await ready();

    analytics.trackGameFinish(analytics.GAMES.words, {
      mode: 'shared',
      outcome: 'won',
      score: 4,
    });

    expect(logEvent.mock.calls[0][1]).toBe('game_finish');
    expect(paramsOf(0)).toEqual({
      game_name: 'vibe-words',
      mode: 'shared',
      outcome: 'won',
      score: 4,
    });
  });

  it('leaves out what a game does not know, rather than sending zero', async () => {
    const analytics = await ready();

    // Vibe Words tracks no elapsed time; a zero would read as instant.
    analytics.trackGameFinish(analytics.GAMES.words, { mode: 'solo', outcome: 'lost', score: 6 });

    expect(paramsOf(0)).not.toHaveProperty('seconds');
  });

  it('tells a shared game from a shared app', async () => {
    const analytics = await ready();

    analytics.trackShare(analytics.GAMES.trio, 'game');
    analytics.trackShare(undefined, 'app');

    expect(paramsOf(0)).toEqual({ content_type: 'game', item_id: 'vibe-trio' });
    expect(paramsOf(1)).toEqual({ content_type: 'app', item_id: 'vibe-games' });
  });

  it('carries the game on the support and feedback events, when there is one', async () => {
    const analytics = await ready();

    analytics.trackSupportOpen(analytics.GAMES.sudoku);
    analytics.trackFeedbackSent();

    expect(paramsOf(0)).toEqual({ game_name: 'vibe-sudoku' });
    // From the hub there is no game to name, and no parameter is better than a
    // placeholder that would read as one.
    expect(logEvent.mock.calls[1][2]).toBeUndefined();
  });

  it('never lets a failure in reporting reach the caller', async () => {
    const analytics = await ready();
    logEvent.mockImplementation(() => {
      throw new Error('the network is gone');
    });

    // Each of these sits somewhere a throw would be a broken game.
    expect(() => analytics.trackPageView('/trio')).not.toThrow();
    expect(() => analytics.trackGameStart(analytics.GAMES.trio, { mode: 'solo' })).not.toThrow();
    expect(() =>
      analytics.trackGameFinish(analytics.GAMES.trio, { mode: 'solo', outcome: 'completed' }),
    ).not.toThrow();
    expect(() => analytics.trackDonationTap()).not.toThrow();
  });
});
