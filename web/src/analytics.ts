import { app } from './firebase';

/**
 * What the site tells Analytics, in one place.
 *
 * The event names and values match the iOS client's exactly, so a report can be
 * read across both without a translation table: `game_start`, `game_finish`,
 * `game_name`, `mode`, `outcome`.
 *
 * **Nothing here identifies anybody.** No names, no game codes, no free text
 * from the feedback box. These are counts of things happening.
 *
 * Two deliberate choices:
 *
 *   * Analytics is loaded with a dynamic import, and only when a measurement id
 *     is configured. A checkout without one never downloads the library at all,
 *     which is the honest behaviour for a setting nobody has filled in.
 *   * Page views are switched off in the SDK and logged here instead, so the
 *     first load and every route change are counted exactly once. Left to
 *     itself the SDK reports the first load only, and a menu-based single-page
 *     app would look like one page.
 *
 * Every call is wrapped: Analytics must never be able to break a game.
 */

const MEASUREMENT_ID = import.meta.env.VITE_FIREBASE_MEASUREMENT_ID as string | undefined;

/** The four games. The strings are the routes, and match the iOS client. */
export const GAMES = {
  five: 'vibe-five',
  words: 'vibe-words',
  sudoku: 'vibe-sudoku',
  trio: 'vibe-trio',
} as const;

export type GameName = (typeof GAMES)[keyof typeof GAMES];

export type Mode = 'solo' | 'shared';

export type Outcome =
  | 'won'
  | 'lost'
  /** The game reached its own end without anybody winning it — Vibe Trio,
   *  where the deck runs out and the score is the result. */
  | 'completed';

/**
 * The screen each route is, named as the iOS client names it, so a screen can
 * be followed across both apps. Unknown paths fall through to the menu.
 */
const SCREENS: Record<string, string> = {
  '/': 'hub',
  '/five': GAMES.five,
  '/words': GAMES.words,
  '/sudoku': GAMES.sudoku,
  '/trio': GAMES.trio,
};

type Sender = (name: string, params?: Record<string, unknown>) => void;

let send: Sender | null = null;
let lastPath: string | null = null;

/**
 * Brings Analytics up, if it is configured and the browser can support it.
 *
 * Resolves either way: nothing downstream waits on it, and a browser that
 * refuses cookies should still get a working game.
 */
export async function installAnalytics(): Promise<void> {
  if (!MEASUREMENT_ID) return;

  try {
    const mod = await import('firebase/analytics');
    if (!(await mod.isSupported())) return;

    const analytics = mod.initializeAnalytics(app, {
      // Page views are logged from `trackPageView` instead, so that the first
      // load is not the only one counted.
      config: { send_page_view: false },
    });
    mod.setAnalyticsCollectionEnabled(analytics, true);
    send = (name, params) => mod.logEvent(analytics, name, params);
  } catch {
    // An ad blocker, a hardened browser, a bad id. Solo play is unaffected and
    // there is nothing useful to say to the player about it.
    send = null;
    return;
  }

  // The load that is already on screen. Later ones arrive through
  // `onPathChange`, which stops this from being counted twice.
  trackPageView(window.location.pathname);
}

/** True once events are actually going somewhere. For tests. */
export function isTracking(): boolean {
  return send !== null;
}

/** A visit, and every route change after it. */
export function trackPageView(path: string): void {
  // Nothing is recorded until Analytics is ready, and `installAnalytics` logs
  // the current path itself — so a route change during startup is not lost, it
  // is simply reported by the later of the two.
  if (!send) return;
  // A `popstate` that lands on the same path is not a second visit.
  if (path === lastPath) return;
  lastPath = path;

  track('page_view', () => ({
    page_path: path,
    page_location: window.location.href,
    page_title: document.title,
    screen_name: SCREENS[path] ?? 'unknown',
  }));
}

export function trackGameStart(
  game: GameName,
  options: { mode: Mode; pack?: string; grade?: string; round?: number } = { mode: 'solo' },
): void {
  track('game_start', {
    game_name: game,
    mode: options.mode,
    ...(options.pack ? { pack: options.pack } : {}),
    ...(options.grade ? { grade: options.grade } : {}),
    ...(options.round != null ? { round: options.round } : {}),
  });
}

export function trackGameFinish(
  game: GameName,
  options: { mode: Mode; outcome: Outcome; score?: number; seconds?: number; round?: number },
): void {
  track('game_finish', {
    game_name: game,
    mode: options.mode,
    outcome: options.outcome,
    ...(options.score != null ? { score: options.score } : {}),
    ...(options.seconds != null ? { seconds: options.seconds } : {}),
    ...(options.round != null ? { round: options.round } : {}),
  });
}

export function trackFeedbackSent(game?: GameName): void {
  track('feedback_sent', game ? { game_name: game } : undefined);
}

export function trackSupportOpen(game?: GameName): void {
  track('support_open', game ? { game_name: game } : undefined);
}

export function trackDonationTap(): void {
  track('donation_tap');
}

/**
 * A link was shared, through Analytics' own `share` event so it lands in the
 * built-in reporting rather than only in a custom report.
 *
 * `what` separates a shared *game* — the invite that makes multiplayer
 * happen — from a shared *app*, which is someone recommending the whole thing.
 */
export function trackShare(game?: GameName, what: 'game' | 'app' = 'game'): void {
  track('share', { content_type: what, item_id: game ?? 'vibe-games' });
}

function track(
  name: string,
  params?: Record<string, unknown> | (() => Record<string, unknown>),
): void {
  if (!send) return;
  try {
    // The parameters may be built lazily so that reading a global which happens
    // to be unavailable is caught here too. `trackPageView` runs inside the
    // router's announce, and a throw from there would break navigation — which
    // is exactly the sort of thing a counter must never be able to do.
    send(name, typeof params === 'function' ? params() : params);
  } catch {
    // Deliberately silent. A game must not be able to fail because a counter
    // did, and there is nothing a player could do about it.
  }
}
