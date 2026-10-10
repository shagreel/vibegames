import { useEffect, useState } from 'react';

/**
 * A router in thirty lines.
 *
 * The whole app is four screens behind a catch-all rewrite, so there is nothing
 * for a routing library to do that `history` and `popstate` do not already do —
 * and the games keep their shared-game id in the query string, which is the part
 * that actually needs preserving.
 */

/** The current path, always normalised: no trailing slash, `/` for the root. */
export function normalise(path: string): string {
  const trimmed = path.replace(/\/+$/, '');
  return trimmed === '' ? '/' : trimmed;
}

/**
 * Navigate without a reload. `replace` keeps the back button clean.
 *
 * Any query string is dropped: a shared game's id belongs to the game that is
 * being left, and a menu carrying `?game=abc12345` would be nonsense — and would
 * hand that id to whatever game was opened next.
 */
export function navigate(to: string, replace = false): void {
  const url = normalise(to);
  if (replace) {
    window.history.replaceState({}, '', url);
  } else {
    window.history.pushState({}, '', url);
  }
  // The history API has no change event of its own, so tell the hook. A plain
  // Event, not a PopStateEvent: nothing reads the payload, and the real
  // constructor is missing in the test environment.
  window.dispatchEvent(new Event('popstate'));
}

/** The path the app should be showing, re-rendering on back and forward. */
export function usePath(): string {
  const [path, setPath] = useState(() => normalise(window.location.pathname));

  useEffect(() => {
    const onPop = () => setPath(normalise(window.location.pathname));
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, []);

  return path;
}

const listeners = new Set<(path: string) => void>();

/**
 * Told about every path change, including the first one and back/forward.
 *
 * Subscribed to once at startup rather than from a component, which keeps it
 * out of React's reach and so out of the double-invoke that StrictMode does to
 * effects in development. A page view counted twice is worse than one not
 * counted at all, because it looks like data.
 *
 * `navigate` announces itself through `popstate`, the same event the browser
 * sends for the back button, so there is only one thing to listen for.
 */
export function onPathChange(listener: (path: string) => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function announce(): void {
  const path = normalise(window.location.pathname);
  listeners.forEach((listener) => listener(path));
}

window.addEventListener('popstate', announce);
