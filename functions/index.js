/**
 * The daily cleanup: anything still in the database from more than a day ago.
 *
 * Nothing in the app can delete a game — the rules hand out writes to whoever
 * gets there first and never a delete, so one phone cannot wipe a game out from
 * under everybody else — and the Realtime Database has no expiry of its own, the
 * way Firestore has TTL policies. So the rooms accumulate until something outside
 * the app clears them, which is this.
 *
 * A daily job rather than an instant one: a room is cheap to keep for a few hours
 * longer, and a game someone is still playing is a game nobody wants deleted
 * underneath them. Nothing here is time-critical, which is why it can run at three
 * in the morning and why it does not matter if GitHub or Google runs it late.
 *
 * This is the same rule as `Tools/prune_games.py`, which does the same job from a
 * command line as you, and reports rather than deletes unless it is told to. See
 * `prune.js` for the rule itself, and keep the two in step.
 */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getDatabase } = require("firebase-admin/database");

const { FEEDBACK_MAX_AGE_HOURS, MAX_AGE_HOURS, TREES, doomed } = require("./prune");

initializeApp();

/**
 * Clears the stale rooms, one write per tree.
 *
 * Returns what it did, which is what the log line is made of. Not exported: the
 * CLI deploys every export in this file as a function, and this is not one.
 */
async function prune(now = Date.now()) {
  // The modular API, not `admin.database()`: firebase-admin 14 dropped the
  // namespaced one, and the call fails at run time rather than at deploy time —
  // which is how this shipped once as a job that ran daily and did nothing.
  const database = getDatabase();
  let deleted = 0;
  let kept = 0;

  for (const [tree, field] of Object.entries(TREES)) {
    const snapshot = await database.ref(tree).get();
    if (!snapshot.exists()) {
      logger.info(`/${tree}: nothing there`);
      continue;
    }

    const games = snapshot.val();
    const stale = doomed(games, field, now);
    const count = Object.keys(stale).length;
    kept += Object.keys(games).length - count;

    if (count === 0) {
      logger.info(`/${tree}: nothing older than ${MAX_AGE_HOURS}h`);
      continue;
    }

    await database.ref(tree).update(stale);
    deleted += count;
    logger.info(`/${tree}: deleted ${count}`, { codes: Object.keys(stale) });
  }

  // The feedback inbox: every note in it is already an issue, so a month-old
  // entry is a public copy of something permanent that nobody needs to keep.
  const inbox = await database.ref("feedback").get();
  if (inbox.exists()) {
    const stale = doomed(inbox.val(), "createdAt", now, FEEDBACK_MAX_AGE_HOURS);
    const count = Object.keys(stale).length;
    if (count > 0) {
      await database.ref("feedback").update(stale);
      deleted += count;
      logger.info(`/feedback: deleted ${count}`);
    }
  }

  logger.info(`done: deleted ${deleted}, kept ${kept}, older than ${MAX_AGE_HOURS}h`);
  return { deleted, kept };
}

exports.pruneGames = onSchedule(
  {
    // Three in the morning, the machine's own timezone — a quiet hour, and a
    // named zone so the clock does not drift across daylight saving.
    schedule: "every day 03:00",
    timeZone: "America/Denver",
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async () => {
    await prune();
  },
);
