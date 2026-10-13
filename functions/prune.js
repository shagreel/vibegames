/**
 * Which games are old enough to delete.
 *
 * Kept apart from the scheduled function so the rule can be tested without a
 * database, a deploy or a credential — the operation deletes things, and the one
 * thing worth being sure of is which things.
 *
 * The same rule is in `Tools/prune_games.py`, which is the command-line twin:
 * that one authenticates as you and reports unless told `--apply`, this one runs
 * as the project's own service account. If you change one, change the other.
 */

/** A game is old once it is a day old. */
const MAX_AGE_HOURS = 24;

/**
 * The game trees, and where each keeps the time it was made.
 *
 * Vibe Words and Vibe Sudoku write `createdAt` on the room; Vibe Trio and Vibe
 * Blurt keep it in `meta`. All four are milliseconds.
 */
const TREES = {
  games: "createdAt",
  sudoku: "createdAt",
  trio: "meta/createdAt",
  blurt: "meta/createdAt",
};

/**
 * When a game was made, in milliseconds, or `null` if it cannot be told.
 *
 * A missing or unreadable timestamp must not be mistaken for 1970: that would
 * delete every game whose shape this does not understand, which is the one
 * mistake here that cannot be undone.
 */
function createdAt(game, field) {
  let node = game;
  for (const step of field.split("/")) {
    if (node === null || typeof node !== "object") return null;
    node = node[step];
  }
  return typeof node === "number" && Number.isFinite(node) ? node : null;
}

/**
 * The games older than `maxAgeHours`, as a map of code to `null`.
 *
 * The nulls are the point: `update()` treats a null value as a delete, so one
 * write clears the whole tree's worth of stale rooms rather than one request per
 * room. Anything whose age cannot be read is kept.
 */
function doomed(games, field, now, maxAgeHours = MAX_AGE_HOURS) {
  if (games === null || typeof games !== "object") return {};

  const cutoff = now - maxAgeHours * 60 * 60 * 1000;
  const out = {};
  for (const [code, game] of Object.entries(games)) {
    if (!game || typeof game !== "object") continue;
    const made = createdAt(game, field);
    if (made === null || made >= cutoff) continue;
    out[code] = null;
  }
  return out;
}

module.exports = { MAX_AGE_HOURS, TREES, createdAt, doomed };
