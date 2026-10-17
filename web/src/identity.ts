/**
 * Who the browser thinks you are.
 *
 * One name and one id for the whole suite, so a player is the same person in
 * every game. Word Vibe predates this and keeps its own keys; new games use
 * these, and the ids are derived per game anyway so the two can share a table.
 */

const NAME_KEY = 'vibegames.playerName';

/**
 * The longest name anybody may have.
 *
 * The database has always capped a name at 24 characters — every room's
 * validation says so — and the clients did not, so a name typed past the cap
 * quietly failed every write it was part of: a player could join a room, be
 * shown in the list, and be refused with "Permission denied". One number, said
 * once here and once in the app, and the same one as the rules.
 */
export const MAX_NAME_LENGTH = 24;

/**
 * Takes out what a name must not carry: control characters, the invisible
 * bidi overrides that can make one player's name read as another's, and the
 * zero-width joiners.
 */
export function cleanName(raw: string): string {
  const kept: string[] = [];
  for (const character of raw) {
    const code = character.codePointAt(0) ?? 0;
    // C0 and C1 control characters, and the invisible ones: zero-width
    // characters, the bidi overrides that let one name render as another's,
    // and the isolate marks around them.
    const control = code < 0x20 || (code >= 0x7f && code <= 0x9f);
    const invisible = code >= 0x200b && code <= 0x200f;
    const bidi = code >= 0x202a && code <= 0x202e;
    const isolates = code >= 0x2066 && code <= 0x2069;
    if (!control && !invisible && !bidi && !isolates) kept.push(character);
  }
  return kept.join('').trim().slice(0, MAX_NAME_LENGTH);
}
const ID_KEY = 'vibegames.playerID';
/** Where Word Vibe kept the name before the games shared one. */
const LEGACY_NAME_KEY = 'vibewords.playerName';

export function playerName(): string {
  const name = cleanName(localStorage.getItem(NAME_KEY) ?? '');
  if (name) return name;

  // Word Vibe kept its own copy of the name before the suite shared one, so
  // somebody who has only ever played that has a name in the old place. Adopt it
  // rather than asking them for it a second time.
  //
  // The old key is deliberately left where it is: a browser still running a
  // cached copy of the previous bundle is still reading it, and a few bytes of
  // duplicate costs nothing next to losing somebody's name.
  const legacy = cleanName(localStorage.getItem(LEGACY_NAME_KEY) ?? '');
  if (legacy) {
    localStorage.setItem(NAME_KEY, legacy);
    return legacy;
  }
  return '';
}

export function setPlayerName(name: string): void {
  localStorage.setItem(NAME_KEY, cleanName(name));
}

/**
 * Forgets the name, leaving everything else alone.
 *
 * The privacy page tells people they can clear it, and until now the only way
 * was to type a different one — a promise with no button behind it.
 */
export function forgetPlayerName(): void {
  localStorage.removeItem(NAME_KEY);
}

export function playerId(): string {
  let id = localStorage.getItem(ID_KEY);
  if (!id) {
    // Random rather than a timestamp: two tabs opened in the same millisecond
    // must not become the same player.
    const values = new Uint32Array(2);
    crypto.getRandomValues(values);
    id = `${values[0].toString(36)}${values[1].toString(36)}`;
    localStorage.setItem(ID_KEY, id);
  }
  return id;
}

/** Which game this browser is hosting, so a reload does not lose the room. */
export function hostedGame(gameId: string): void {
  localStorage.setItem('vibegames.hostedGameID', gameId);
}

export function isHosting(gameId: string): boolean {
  return localStorage.getItem('vibegames.hostedGameID') === gameId;
}
