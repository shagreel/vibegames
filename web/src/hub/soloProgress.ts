/**
 * Solo games left in progress, kept in this browser.
 *
 * Leaving a game used to end it. A solo game is a sitting rather than a
 * commitment: pressing back should not throw the board away, and coming back
 * should ask whether to carry on or start again.
 *
 * One record per game. The game decides what goes in `payload` — a seed and what
 * has been done to it, as a rule — and what `summary` says, because only the
 * game knows what "in progress" looks like.
 */

export interface SavedSolo {
  summary: string;
  savedAt: number;
}

interface Record extends SavedSolo {
  game: string;
  payload: unknown;
}

const key = (game: string) => `vibegames.solo.${game}`;

/** Keeps a game so it can be picked up later. */
export function saveSolo<T>(game: string, payload: T, summary: string): void {
  try {
    const record: Record = { game, savedAt: Date.now(), summary, payload };
    localStorage.setItem(key(game), JSON.stringify(record));
  } catch {
    // A browser that will not store things is a browser that cannot resume:
    // nothing to say, and nothing the player could do about it.
  }
}

/** The state inside a saved game, if one can still be read. */
export function loadSolo<T>(game: string): (SavedSolo & { payload: T }) | null {
  const record = readRecord(game);
  if (!record) return null;
  if (record.payload === undefined || record.payload === null) {
    clearSolo(game);
    return null;
  }
  return { summary: record.summary, savedAt: record.savedAt, payload: record.payload as T };
}

/** What a resume dialog needs to know, without opening the state. */
export function savedSolo(game: string): SavedSolo | null {
  const record = readRecord(game);
  return record ? { summary: record.summary, savedAt: record.savedAt } : null;
}

export function clearSolo(game: string): void {
  localStorage.removeItem(key(game));
}

function readRecord(game: string): Record | null {
  const raw = localStorage.getItem(key(game));
  if (!raw) return null;
  try {
    const record = JSON.parse(raw) as Record;
    if (typeof record?.summary !== 'string' || typeof record?.savedAt !== 'number') return null;
    return record;
  } catch {
    clearSolo(game);
    return null;
  }
}
