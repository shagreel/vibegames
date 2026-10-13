import { describe, it, expect, beforeEach } from 'vitest';
import { playerId, playerName, setPlayerName } from '../identity';

/**
 * One name for the whole suite.
 *
 * The point of it is that a player types their name once, not once per game, so
 * what matters is that it comes back on the next visit — and that a name saved
 * by Word Vibe before the games shared a key is not lost.
 */
describe('the player name', () => {
  beforeEach(() => localStorage.clear());

  it('is remembered between visits', () => {
    expect(playerName(), 'nothing saved yet').toBe('');
    setPlayerName('Alex');
    expect(playerName()).toBe('Alex');
  });

  it('is trimmed on the way in and on the way out', () => {
    setPlayerName('  Alex  ');
    expect(playerName()).toBe('Alex');
    localStorage.setItem('vibegames.playerName', '  Sam  ');
    expect(playerName()).toBe('Sam');
  });

  it('treats a name that is only spaces as no name at all', () => {
    // Otherwise a stray space would pass every `if (name)` check in the suite
    // and put a blank entry on a roster.
    setPlayerName('   ');
    expect(playerName()).toBe('');
  });

  it('adopts the name Word Vibe saved before the games shared one', () => {
    localStorage.setItem('vibewords.playerName', 'Jo');
    expect(playerName()).toBe('Jo');
    // And writes it where the shared key is read from, so it is adopted once
    // rather than every time.
    expect(localStorage.getItem('vibegames.playerName')).toBe('Jo');
  });

  it('prefers the shared name when there is one of each', () => {
    localStorage.setItem('vibewords.playerName', 'Jo');
    localStorage.setItem('vibegames.playerName', 'Robin');
    expect(playerName()).toBe('Robin');
  });

  it('does not adopt a legacy key that holds no name', () => {
    localStorage.setItem('vibewords.playerName', '   ');
    expect(playerName()).toBe('');
    expect(localStorage.getItem('vibegames.playerName')).toBeNull();
  });
});

describe('the player id', () => {
  beforeEach(() => localStorage.clear());

  it('is made once and then kept', () => {
    const id = playerId();
    expect(id).not.toBe('');
    expect(playerId()).toBe(id);
    expect(localStorage.getItem('vibegames.playerID')).toBe(id);
  });

  it('is different for a browser that has never been seen', () => {
    const first = playerId();
    localStorage.clear();
    expect(playerId()).not.toBe(first);
  });
});
