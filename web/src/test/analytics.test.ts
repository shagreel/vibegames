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
 *
 * The transport is gtag.js rather than the Firebase Analytics SDK, for the
 * reason set out in `src/analytics.ts` — so these assert on the script tag that
 * gets appended and on what reaches `dataLayer`, which is exactly what gtag
 * itself consumes.
 */

// Mocked so that importing the analytics module does not drag in a real Firebase
// app built from environment variables a test environment does not have.
vi.mock('../firebase', () => ({ app: { name: 'test' } }));

interface ScriptTag { tag: string; src: string }

let appended: ScriptTag[] = [];

/** A fresh copy of the module, with the measurement id set or not. */
async function fresh(measurementId: string) {
  vi.resetModules();
  vi.stubEnv('VITE_FIREBASE_MEASUREMENT_ID', measurementId);
  return import('../analytics');
}

/**
 * Everything queued for gtag, in order. This is read from `window.dataLayer`
 * rather than from a mock, so it is the same queue the real library would drain.
 */
function dataLayer(): unknown[][] {
  return (window.dataLayer ?? []).map((entry) => Array.from(entry as ArrayLike<unknown>));
}

/** Every `event` command that reached the data layer. */
function events(): { name: string; params?: Record<string, unknown> }[] {
  return dataLayer()
    .filter((args) => args[0] === 'event')
    .map((args) => ({
      name: args[1] as string,
      params: args[2] as Record<string, unknown> | undefined,
    }));
}

/** The `config` command, which is what turns the property on. */
function configCall(): unknown[] | undefined {
  return dataLayer().find((args) => args[0] === 'config');
}

beforeEach(() => {
  appended = [];
  delete window.dataLayer;
  delete window.gtag;
  vi.spyOn(document.head, 'appendChild').mockImplementation(((tag: ScriptTag) => {
    appended.push(tag);
  }) as never);
  vi.spyOn(document, 'createElement').mockImplementation(
    ((tag: string) => ({ tag, src: '' })) as never,
  );
  window.history.replaceState({}, '', '/');
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
  vi.resetModules();
});

describe('installAnalytics', () => {
  it('does nothing at all without a measurement id', async () => {
    const analytics = await fresh('');

    analytics.installAnalytics();

    expect(analytics.isTracking()).toBe(false);
    // Not merely quiet: gtag is never fetched, and no data layer is created.
    expect(appended).toHaveLength(0);
    expect(window.dataLayer).toBeUndefined();
  });

  it('loads gtag with the configured id', async () => {
    const analytics = await fresh('G-TEST123');

    analytics.installAnalytics();

    expect(analytics.isTracking()).toBe(true);
    expect(appended).toHaveLength(1);
    expect(appended[0].src).toBe('https://www.googletagmanager.com/gtag/js?id=G-TEST123');
  });

  it('switches off the automatic page view, so the first load is not counted twice', async () => {
    const analytics = await fresh('G-TEST123');

    analytics.installAnalytics();

    expect(configCall()?.[1]).toBe('G-TEST123');
    expect(configCall()?.[2]).toEqual({ send_page_view: false });
  });

  it('reports the page already on screen', async () => {
    window.history.replaceState({}, '', '/trio');
    const analytics = await fresh('G-TEST123');

    analytics.installAnalytics();

    expect(events()).toHaveLength(1);
    expect(events()[0].name).toBe('page_view');
    expect(events()[0].params).toMatchObject({ page_path: '/trio', screen_name: 'vibe-trio' });
  });

  it('survives a browser that will not let the script load', async () => {
    vi.spyOn(document, 'createElement').mockImplementation(() => {
      throw new Error('blocked by an extension');
    });
    const analytics = await fresh('G-TEST123');

    expect(() => analytics.installAnalytics()).not.toThrow();
    expect(analytics.isTracking()).toBe(false);
  });

  it('sends nothing before it has been installed', async () => {
    const analytics = await fresh('G-TEST123');

    analytics.trackGameStart(analytics.GAMES.trio, { mode: 'solo' });
    analytics.trackPageView('/trio');

    expect(events()).toHaveLength(0);
  });
});

describe('trackPageView', () => {
  async function ready() {
    const analytics = await fresh('G-TEST123');
    analytics.installAnalytics();
    // Drop the initial page view, so each test sees only what it caused.
    window.dataLayer = [];
    return analytics;
  }

  it('counts a route once, however often it is announced', async () => {
    const analytics = await ready();

    analytics.trackPageView('/trio');
    analytics.trackPageView('/trio');
    analytics.trackPageView('/trio');

    expect(events()).toHaveLength(1);
  });

  it('counts leaving and coming back as two visits', async () => {
    const analytics = await ready();

    analytics.trackPageView('/trio');
    analytics.trackPageView('/');
    analytics.trackPageView('/trio');

    expect(events().map((event) => event.params?.page_path)).toEqual(['/trio', '/', '/trio']);
  });

  it('names each screen the way the iOS app names it', async () => {
    const analytics = await ready();

    for (const path of ['/five', '/words', '/sudoku', '/trio', '/']) {
      analytics.trackPageView(path);
    }

    expect(events().map((event) => event.params?.screen_name)).toEqual([
      'vibe-five',
      'vibe-words',
      'vibe-sudoku',
      'vibe-trio',
      'hub',
    ]);
  });

  it('calls an unrecognised path unknown rather than guessing', async () => {
    const analytics = await ready();

    analytics.trackPageView('/nonsense');

    expect(events()[0].params?.screen_name).toBe('unknown');
  });
});

describe('game events', () => {
  async function ready() {
    const analytics = await fresh('G-TEST123');
    analytics.installAnalytics();
    // Drop the initial page view, so each test sees only what it caused.
    window.dataLayer = [];
    return analytics;
  }

  it('reports a start with its mode and round', async () => {
    const analytics = await ready();

    analytics.trackGameStart(analytics.GAMES.five, { mode: 'solo', round: 3 });

    expect(events()[0].name).toBe('game_start');
    expect(events()[0].params).toEqual({ game_name: 'vibe-five', mode: 'solo', round: 3 });
  });

  it('reports a finish with its outcome and score', async () => {
    const analytics = await ready();

    analytics.trackGameFinish(analytics.GAMES.words, {
      mode: 'shared',
      outcome: 'won',
      score: 4,
    });

    expect(events()[0].name).toBe('game_finish');
    expect(events()[0].params).toEqual({
      game_name: 'vibe-words',
      mode: 'shared',
      outcome: 'won',
      score: 4,
    });
  });

  it('leaves out what a game does not know, rather than sending zero', async () => {
    const analytics = await ready();

    // Word Vibe tracks no elapsed time; a zero would read as instant.
    analytics.trackGameFinish(analytics.GAMES.words, { mode: 'solo', outcome: 'lost', score: 6 });

    expect(events()[0].params).not.toHaveProperty('seconds');
  });

  it('tells a shared game from a shared app', async () => {
    const analytics = await ready();

    analytics.trackShare(analytics.GAMES.trio, 'game');
    analytics.trackShare(undefined, 'app');

    expect(events()[0].params).toEqual({ content_type: 'game', item_id: 'vibe-trio' });
    expect(events()[1].params).toEqual({ content_type: 'app', item_id: 'vibe-games' });
  });

  it('carries the game on the support and feedback events, when there is one', async () => {
    const analytics = await ready();

    analytics.trackSupportOpen(analytics.GAMES.sudoku);
    analytics.trackFeedbackSent();

    expect(events()[0].params).toEqual({ game_name: 'vibe-sudoku' });
    // From the hub there is no game to name, and an empty object is not a name.
    expect(events()[1].params).toEqual({});
  });

  it('never lets a failure in reporting reach the caller', async () => {
    const analytics = await ready();
    // gtag present but failing, which is the case that actually needs the guard.
    // An absent one is already harmless through optional chaining, so deleting
    // it here would test nothing at all — as a mutation showed.
    window.gtag = () => {
      throw new Error('the network is gone');
    };

    // Each of these sits somewhere a throw would be a broken game: the first
    // inside the router's announce, the rest inside React effects.
    expect(() => analytics.trackPageView('/trio')).not.toThrow();
    expect(() => analytics.trackGameStart(analytics.GAMES.trio, { mode: 'solo' })).not.toThrow();
    expect(() =>
      analytics.trackGameFinish(analytics.GAMES.trio, { mode: 'solo', outcome: 'completed' }),
    ).not.toThrow();
    expect(() => analytics.trackDonationTap()).not.toThrow();
    expect(() => analytics.trackShare(analytics.GAMES.trio)).not.toThrow();
  });
});
