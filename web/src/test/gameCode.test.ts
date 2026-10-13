import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { GAME_CODE_WORDS } from '../lib/gameCodeWords.generated';
import { displayGameCode, makeGameCode, normaliseGameCode } from '../lib/gameCode';

/**
 * The code that shares a game.
 *
 * It is read out loud and typed in by somebody who only heard it, so what
 * matters is that it is sayable and that a mistyped one still lands in the
 * right room. Both of those are easy to break by accident and invisible until
 * somebody cannot join.
 *
 * This mirrors `Tests/GameCodeTests.swift`: the app and the browser have to
 * agree on both the words and the forgiveness, or a room made on a phone
 * cannot be joined from a laptop.
 */
describe('the game code', () => {
  it('is two four-letter words', () => {
    for (let i = 0; i < 200; i += 1) {
      const code = makeGameCode();
      const parts = code.split('-');

      expect(parts, `Unexpected code: ${code}`).toHaveLength(2);
      expect(parts[0], `Unexpected code: ${code}`).toHaveLength(4);
      expect(parts[1], `Unexpected code: ${code}`).toHaveLength(4);
      expect(code, `Unexpected code: ${code}`).toMatch(/^[a-z]{4}-[a-z]{4}$/);
    }
  });

  it('only ever uses word-list words', () => {
    const known = new Set(GAME_CODE_WORDS);
    for (let i = 0; i < 200; i += 1) {
      for (const part of makeGameCode().split('-')) {
        expect(known.has(part), `${part} is not a word from the list`).toBe(true);
      }
    }
  });

  it('never repeats a word', () => {
    // "dock-dock" reads like a mistake when it is said aloud.
    for (let i = 0; i < 400; i += 1) {
      const parts = makeGameCode().split('-');
      expect(parts[0]).not.toBe(parts[1]);
    }
  });

  it('has a space big enough to share in', () => {
    // Counted, not sampled. Collisions are what this is really about — two
    // rooms landing on the same name — but a sample cannot answer it: 500 codes
    // drawn from 57,360 expect 2.2 collisions by the birthday problem and see
    // six or more about 2% of the time, so "no collisions in 500 draws" is a
    // coin toss rather than a property. The size of the space can be checked.
    const words = GAME_CODE_WORDS.length;
    expect(words * (words - 1)).toBeGreaterThanOrEqual(40_000);
  });

  it('spreads across the word list', () => {
    // What a collision count was reaching for: a generator that has quietly
    // collapsed onto a handful of words. 200 draws from 240 words land on about
    // 136 distinct first words; 100 is far below that and still out of reach
    // for a generator stuck on a small pool.
    const firstWords = new Set(Array.from({ length: 200 }, () => makeGameCode().slice(0, 4)));
    expect(firstWords.size).toBeGreaterThan(100);
  });
});

describe('the word list', () => {
  it('is worth drawing from', () => {
    expect(GAME_CODE_WORDS.length).toBeGreaterThanOrEqual(200);
    expect(new Set(GAME_CODE_WORDS).size).toBe(GAME_CODE_WORDS.length);
    for (const word of GAME_CODE_WORDS) {
      // Read out loud and typed back in: anything but four plain lowercase
      // letters is a code somebody cannot share.
      expect(word).toMatch(/^[a-z]{4}$/);
    }
  });

  it('is the same list the app draws from', () => {
    // The web list is generated from the Swift one, and this is what notices
    // when somebody edits the Swift list and forgets to regenerate: the two
    // clients would quietly stop sharing a vocabulary, and the symptom would
    // be "the code from your phone does not work on my laptop".
    const swiftPath = fileURLToPath(new URL('../../../Sources/Model/GameCodeWords.swift', import.meta.url));
    const swift = readFileSync(swiftPath, 'utf8');
    const words = [...swift.matchAll(/^\s*"([^"]+)",\s*$/gm)].map((match) => match[1]);

    expect(words.length).toBeGreaterThanOrEqual(200);
    expect(words).toEqual(GAME_CODE_WORDS);
  });
});

// MARK: - What somebody typed

describe('a code somebody typed', () => {
  it('survives the round trip', () => {
    for (let i = 0; i < 100; i += 1) {
      const code = makeGameCode();
      expect(normaliseGameCode(code)).toBe(code);
    }
  });

  it('is forgiven the ways people actually type it', () => {
    // Heard across a room, typed from memory: capitals, a stray space, the
    // hyphen forgotten, the whole thing pasted with whitespace round it.
    // Keep in step with the same table in `Tests/GameCodeTests.swift`.
    const wanted = 'cars-feed';
    const typed = [
      'cars-feed',
      'CARS-FEED',
      'Cars-Feed',
      'carsfeed',
      'CARSFEED',
      'cars feed',
      'cars_feed',
      ' cars-feed ',
      'cars-feed.',
      'cars–feed',
    ];
    for (const input of typed) {
      expect(normaliseGameCode(input), `typed as ${JSON.stringify(input)}`).toBe(wanted);
    }
  });

  it('leaves a code from before the words changed alone', () => {
    // Digits are not stripped, so an old code still names the room it named.
    // Nobody has to care, but a code that silently became a different one
    // would be worse than one that does not resolve.
    expect(normaliseGameCode('abc12345')).toBe('abc12345');
    expect(normaliseGameCode('ab12cd34')).toBe('ab12cd34');
  });

  it('turns nonsense into nothing rather than something else', () => {
    // Every game refuses an empty code, so rubbish must not turn into a
    // plausible room.
    for (const input of ['', '   ', '!!!', '-', '--', '🙂', 'a']) {
      expect(normaliseGameCode(input)).toMatch(/^[a-z0-9-]*$/);
    }
    expect(normaliseGameCode('!!!')).toBe('');
  });

  it('puts a space between the two words', () => {
    // The space is a reading aid: it is what stops `carsfeed` reading as one long
    // noise. It is not part of the code, and typing it is optional — but it is
    // what the screen shows, because the code is read out loud. Matches
    // `GameCode.display` in Swift, and the table in `Tests/GameCodeTests.swift`.
    expect(displayGameCode('cars-feed')).toBe('CARS FEED');
    expect(displayGameCode('dock-time')).toBe('DOCK TIME');

    // Harmless on a code that never had one, and on the older numeric codes: the
    // display is applied to whatever the room happens to hold.
    expect(displayGameCode('CARS FEED')).toBe('CARS FEED');
    expect(displayGameCode('carsfeed')).toBe('CARSFEED');
    expect(displayGameCode('abc12345')).toBe('ABC12345');
    expect(displayGameCode('')).toBe('');
  });

  it('shows something that can be typed straight back', () => {
    // Whatever the screen shows has to work when it is typed in as it appears.
    // The space and the hyphen are both dropped on the way in, so the separator
    // is genuinely optional rather than something to get right.
    for (const code of ['cars-feed', 'dock-time', 'game-code']) {
      expect(normaliseGameCode(displayGameCode(code)), code).toBe(code);
    }
  });

  it('shows two words of four letters, and never a dash', () => {
    for (let i = 0; i < 200; i += 1) {
      expect(displayGameCode(makeGameCode())).toMatch(/^[A-Z]{4} [A-Z]{4}$/);
    }
  });
});
