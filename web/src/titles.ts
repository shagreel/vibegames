import { onPathChange } from './router';

/**
 * The tab title, per screen.
 *
 * Every route serves the same file, so without this every tab, bookmark and
 * history entry in the suite says the same thing — and so does every one of them
 * in a browser's "recently closed" list, which is the moment somebody is trying
 * to find the game they were in the middle of.
 *
 * The game's own name first, the suite second: a tab is about a centimetre wide
 * and the first word is the only one that survives.
 */
const TITLES: Record<string, string> = {
  '/': 'Vibe Games — five party games',
  '/five': 'Vibe Five — name three things, fast',
  '/words': 'Word Vibe — guess the five-letter word',
  '/sudoku': 'Number Vibe — fill the grid',
  '/trio': 'Vibe Pairings — find three that match',
  '/blurt': 'Similar Vibe — describe it, don\u2019t say it',
};

/** What a path is called. Unknown paths are the hub, because the app shows it. */
export function titleFor(path: string): string {
  return TITLES[path] ?? TITLES['/'];
}

/**
 * Follows the route. Subscribed once at startup, next to the page views and for
 * the same reason: one thing watching the path rather than every screen
 * remembering to say its own name.
 */
export function installTitles(): void {
  onPathChange((path) => {
    document.title = titleFor(path);
  });
}
