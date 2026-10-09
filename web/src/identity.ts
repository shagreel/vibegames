/**
 * Who the browser thinks you are.
 *
 * One name and one id for the whole suite, so a player is the same person in
 * every game. Vibe Words predates this and keeps its own keys; new games use
 * these, and the ids are derived per game anyway so the two can share a table.
 */

const NAME_KEY = 'vibegames.playerName';
const ID_KEY = 'vibegames.playerID';

export function playerName(): string {
  return localStorage.getItem(NAME_KEY)?.trim() ?? '';
}

export function setPlayerName(name: string): void {
  localStorage.setItem(NAME_KEY, name.trim());
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
