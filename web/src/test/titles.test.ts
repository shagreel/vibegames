import { describe, expect, it } from 'vitest';
import { titleFor } from '../titles';

/**
 * The tab title is the only piece of the page's head the app can change, and it
 * is the one a person sees in a bookmark, a history entry or a row of tabs.
 *
 * That every route *has* one is checked against the router by
 * `Tools/check_seo.py`; what is checked here is what happens to a route that is
 * not one — the app shows the hub for anything it does not recognise, so the
 * title has to say the same.
 */
describe('the tab title', () => {
  it('names the game first, so a narrow tab still says which one it is', () => {
    expect(titleFor('/words')).toMatch(/^Word Vibe/);
    expect(titleFor('/trio')).toMatch(/^Vibe Pairings/);
    expect(titleFor('/sudoku')).toMatch(/^Number Vibe/);
    expect(titleFor('/five')).toMatch(/^Vibe Five/);
    expect(titleFor('/blurt')).toMatch(/^Similar Vibe/);
  });

  it('gives the hub the suite name', () => {
    expect(titleFor('/')).toMatch(/^Vibe Games/);
  });

  it('falls back to the hub, because that is the screen it shows', () => {
    expect(titleFor('/nonsense')).toBe(titleFor('/'));
    expect(titleFor('/words/')).toBe(titleFor('/'));
  });

  it('says something different for every screen', () => {
    const titles = ['/', '/five', '/words', '/sudoku', '/trio', '/blurt'].map(titleFor);
    expect(new Set(titles).size).toBe(titles.length);
  });
});
