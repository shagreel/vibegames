import { describe, it, expect, beforeEach } from 'vitest';
import { normalise, navigate } from '../router';

/**
 * The router is what replaced "play.vibegames.party is Word Vibe" — a wrong
 * path here is a menu that lies about where it goes.
 */
describe('router', () => {
  beforeEach(() => {
    window.history.replaceState({}, '', '/');
  });

  it('treats the root and a trailing slash as the same place', () => {
    expect(normalise('/')).toBe('/');
    expect(normalise('')).toBe('/');
    expect(normalise('/words/')).toBe('/words');
    expect(normalise('//')).toBe('/');
  });

  it('leaves nested and unknown paths alone for the switch to handle', () => {
    expect(normalise('/words')).toBe('/words');
    expect(normalise('/nonsense')).toBe('/nonsense');
  });

  it('pushes a new entry by default', () => {
    navigate('/trio');
    expect(window.location.pathname).toBe('/trio');
    expect(window.history.length).toBeGreaterThan(1);
  });

  it('replaces when asked, so the back button is not polluted', () => {
    navigate('/words');
    const before = window.history.length;
    navigate('/sudoku', true);
    expect(window.location.pathname).toBe('/sudoku');
    expect(window.history.length).toBe(before);
  });

  it('drops a shared-game id when leaving the game it belongs to', () => {
    window.history.replaceState({}, '', '/words?game=abc12345');
    navigate('/');
    expect(window.location.pathname).toBe('/');
    expect(window.location.search).toBe('');
  });

  it('tells the app the path changed', () => {
    let heard = 0;
    const listener = () => { heard += 1; };
    window.addEventListener('popstate', listener);
    navigate('/words');
    window.removeEventListener('popstate', listener);
    expect(heard).toBe(1);
  });
});
