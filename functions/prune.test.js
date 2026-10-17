/**
 * The deletion rule, tested without a database.
 *
 * `node --test` and nothing else: this is the one piece of the function worth
 * being sure about, and it needs no credential, no emulator and no deploy to
 * check. Run it from `functions/`.
 */
const test = require("node:test");
const assert = require("node:assert/strict");

const { MAX_AGE_HOURS, TREES, createdAt, doomed } = require("./prune");

const HOUR = 60 * 60 * 1000;
const NOW = Date.UTC(2026, 0, 15, 12, 0, 0);

test("a game older than a day is doomed, and a newer one is not", () => {
  const games = {
    "old-room": { createdAt: NOW - 25 * HOUR },
    "yesterday": { createdAt: NOW - (MAX_AGE_HOURS + 0.1) * HOUR },
    "just-under": { createdAt: NOW - (MAX_AGE_HOURS - 0.1) * HOUR },
    "fresh": { createdAt: NOW - 2 * HOUR },
  };

  assert.deepEqual(Object.keys(doomed(games, "createdAt", NOW)).sort(),
                   ["old-room", "yesterday"]);
});

test("a room stamped in the far future is still doomed", () => {
  // A client can write the timestamp, and a room stamped in the year 3000 was
  // never going to be pruned by a rule that only looks backwards.
  const games = {
    "year-3000": { createdAt: Date.UTC(3000, 0, 1) },
    "a-day-ahead": { createdAt: NOW + 25 * HOUR },
    "wrong-clock": { createdAt: NOW + 2 * HOUR },
  };
  assert.deepEqual(Object.keys(doomed(games, "createdAt", NOW)).sort(),
                   ["a-day-ahead", "year-3000"]);
});

test("a game exactly a day old is kept", () => {
  // The boundary is "older than", not "at least as old as": a room made exactly
  // 24 hours ago may still have somebody in it.
  const games = { "edge": { createdAt: NOW - MAX_AGE_HOURS * HOUR } };
  assert.deepEqual(doomed(games, "createdAt", NOW), {});
});

test("what is doomed is a null, because that is what deletes it", () => {
  // One `update()` per tree, and a null value is how RTDB spells delete.
  const games = { "old": { createdAt: NOW - 48 * HOUR } };
  assert.deepEqual(doomed(games, "createdAt", NOW), { old: null });
});

test("a game whose age cannot be read is kept", () => {
  // The one mistake here that cannot be undone. An unreadable shape is far more
  // likely to be a schema change than rubbish.
  const games = {
    "no-timestamp": { word: "THICK" },
    "null-timestamp": { createdAt: null },
    "string-timestamp": { createdAt: "1763605843476" },
    "nan": { createdAt: Number.NaN },
    "missing-meta": {},
    "meta-not-an-object": { meta: "nope" },
    "not-an-object": "nope",
  };

  assert.deepEqual(doomed(games, "createdAt", NOW), {});
  assert.deepEqual(doomed(games, "meta/createdAt", NOW), {});
});

test("the nested field a tree uses is the one that is read", () => {
  // Trio and Blurt keep theirs under meta; Words and Sudoku on the room.
  const games = {
    "trio-room": { meta: { createdAt: NOW - 48 * HOUR } },
    "blurt-room": { meta: { createdAt: NOW - 48 * HOUR, seed: 1 } },
  };

  assert.deepEqual(Object.keys(doomed(games, TREES.trio, NOW)).sort(),
                   ["blurt-room", "trio-room"]);
  assert.deepEqual(doomed(games, TREES.games, NOW), {},
                   "nothing here has a top-level createdAt");
});

test("an empty or missing tree is not an error", () => {
  for (const empty of [null, undefined, {}, []]) {
    assert.deepEqual(doomed(empty, "createdAt", NOW), {});
  }
});

test("createdAt reads a path and refuses anything that is not a number", () => {
  assert.equal(createdAt({ meta: { createdAt: 5 } }, "meta/createdAt"), 5);
  assert.equal(createdAt({ createdAt: 5 }, "createdAt"), 5);
  assert.equal(createdAt({ createdAt: "5" }, "createdAt"), null);
  assert.equal(createdAt({}, "meta/createdAt"), null);
  assert.equal(createdAt(null, "createdAt"), null);
});

test("every tree has a field named after where the timestamp really lives", () => {
  // Pinned against the app: if a game starts writing its creation time somewhere
  // else, this is what says so rather than the room quietly living forever.
  assert.deepEqual(TREES, {
    games: "createdAt",
    sudoku: "createdAt",
    trio: "meta/createdAt",
    blurt: "meta/createdAt",
  });
});
