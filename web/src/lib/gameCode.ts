import { GAME_CODE_WORDS } from './gameCodeWords.generated';

/**
 * The code that shares a game.
 *
 * Two four-letter words joined by a hyphen — `cars-feed`, `dock-time` — rather
 * than eight characters of noise. A code is read out loud across a room and
 * typed in by somebody who only heard it, and nobody can say `k3f9xq2p` twice
 * the same way. Two words that already exist in the language are remembered
 * after one hearing.
 *
 * It is a name, not a secret: the code only has to be hard to guess, not
 * impossible, and a few hundred words squared is tens of thousands of rooms.
 *
 * Matches `GameCode.swift`, so a room made in the app can be joined in a
 * browser and the other way round.
 */
export function makeGameCode(): string {
  const words = GAME_CODE_WORDS;
  if (words.length === 0) return 'game-code';

  const first = words[Math.floor(Math.random() * words.length)];

  // The same word twice reads like a mistake when it is said aloud, and like a
  // bug when it is seen.
  let second = first;
  while (second === first && words.length > 1) {
    second = words[Math.floor(Math.random() * words.length)];
  }
  return `${first}-${second}`;
}

/**
 * Turns whatever somebody typed into what the database holds.
 *
 * Deliberately forgiving, because these arrive second-hand: somebody hears the
 * code, types it into their phone, and lands here with capitals, a stray space,
 * or no hyphen at all. Everything that is not a letter, a digit or a hyphen is
 * dropped — which also disposes of the space in `cars feed` — and eight letters
 * with no hyphen in them get one put back.
 *
 * Digits are kept rather than stripped so that a code from before the words
 * changed still resolves to the room it names.
 */
export function normaliseGameCode(typed: string): string {
  const cleaned = typed.toLowerCase().replace(/[^a-z0-9-]/g, '');
  if (cleaned.length === 8 && /^[a-z]{8}$/.test(cleaned)) {
    return `${cleaned.slice(0, 4)}-${cleaned.slice(4)}`;
  }
  return cleaned;
}

/**
 * How a code is shown to a person: two words, a space apart.
 *
 * The separator is a reading aid and nothing more. It is what stops `carsfeed`
 * reading as one long noise, and it is why somebody who hears the code can hold
 * it in their head long enough to type it. It is *not* part of the code: nothing
 * has to type it, `normaliseGameCode` drops whatever punctuation arrives with
 * it, and a hyphen, a space, or nothing at all all resolve to the same room. So
 * the display can show the words the way they are said — and what is on screen
 * is not a format anybody has to reproduce exactly.
 *
 * Matches `GameCode.display` in Swift.
 */
export function displayGameCode(code: string): string {
  return code.replace(/-/g, ' ').toUpperCase();
}
