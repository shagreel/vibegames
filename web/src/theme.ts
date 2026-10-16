/**
 * Light or dark, for the whole suite.
 *
 * The games were dark-only, which is a choice the player never got to make. The
 * preference is one value for every game — a player who turns the lights on in
 * Word Vibe does not want Number Vibe to disagree — and it is stored under one
 * key so the settings sheet in any game can read and write the same thing.
 *
 * `system` is the default and is not the same as `dark`: it follows the device,
 * including a device that changes its mind at sunset while a game is open.
 */

export type ThemePreference = 'system' | 'light' | 'dark';
export type Theme = 'light' | 'dark';

export const THEME_KEY = 'vibegames.theme';

/** The colours the `theme-color` meta tag takes, matching `--page` below. */
export const DARK_CHROME = '#121213';
export const LIGHT_CHROME = '#f4f4f6';

const listeners = new Set<() => void>();

function isPreference(value: string | null): value is ThemePreference {
  return value === 'system' || value === 'light' || value === 'dark';
}

/** What the player chose. Anything unrecognised is `system`. */
export function themePreference(): ThemePreference {
  const stored = localStorage.getItem(THEME_KEY);
  return isPreference(stored) ? stored : 'system';
}

/** What the device is asking for, when nobody has overridden it. */
export function systemTheme(): Theme {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return 'dark';
  return window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
}

/** The appearance actually in force: the choice, or the device's when it is `system`. */
export function resolvedTheme(preference: ThemePreference = themePreference()): Theme {
  return preference === 'system' ? systemTheme() : preference;
}

/**
 * Puts the resolved appearance on the document.
 *
 * `data-theme` is what the stylesheets key off; the inline `color-scheme` is
 * what makes the parts the browser draws itself — scrollbars, the caret, form
 * controls — agree with them.
 */
export function applyTheme(): Theme {
  const theme = resolvedTheme();
  const root = typeof document === 'undefined' ? undefined : document.documentElement;
  if (root) {
    root.dataset.theme = theme;
    root.style.colorScheme = theme;
  }
  // The strip the browser paints above the page, on the phones where there is
  // one. The meta tag ships dark; a player in light should not be looking at a
  // dark bar above a white page.
  const meta =
    typeof document?.querySelector === 'function'
      ? document.querySelector('meta[name="theme-color"]')
      : null;
  meta?.setAttribute('content', theme === 'light' ? LIGHT_CHROME : DARK_CHROME);
  return theme;
}

function announce() {
  for (const listener of listeners) listener();
}

export function setThemePreference(preference: ThemePreference): void {
  localStorage.setItem(THEME_KEY, preference);
  applyTheme();
  announce();
}

/** Components that show the current choice listen here. */
export function subscribeTheme(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/**
 * Follows the device for as long as the preference is `system`.
 *
 * A phone that turns dark at sunset should turn the games dark with it, which
 * only happens if something is listening; and a listener that is not needed is
 * harmless, so it is installed unconditionally and reads the preference when it
 * fires.
 */
export function watchTheme(): () => void {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
    return () => {};
  }
  const query = window.matchMedia('(prefers-color-scheme: light)');
  const onChange = () => {
    if (themePreference() === 'system') {
      applyTheme();
      announce();
    }
  };
  query.addEventListener('change', onChange);
  return () => query.removeEventListener('change', onChange);
}
