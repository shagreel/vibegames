/**
 * Plays a real game of Similar Vibe with four players, against the live site and
 * the live database, each in its own browser context so they have genuinely
 * separate identities.
 *
 * This exists because it is the only check that covers the whole game end to
 * end, and it has already earned its keep more than once: it caught a host whose
 * name was read from a stale closure, a player who followed a link never being
 * registered, and a rules hole that stopped the teams being dealt at all.
 *
 * Four players is the minimum the game allows, and it is the smallest table
 * where every screen is different: one describer, one team-mate guessing, and
 * two people on the other side watching for the word.
 *
 * The three things it checks that nothing else can:
 *
 *   1. The word reaches the describer and the opposing team, and **not** the
 *      team-mate who is guessing.
 *   2. Pressing "got it" moves the word to the *other* team.
 *   3. The clock keeps running across that pass. The timer belongs to the round,
 *      not to the word, and a reset would quietly turn the game back into the
 *      one-team-at-a-time version it is not meant to be.
 *
 * Run it after deploying, from the repository root:
 *
 *     node Tools/blurt_e2e.mjs
 *
 * Or against a local build, which is what to do before deploying — `npm run
 * build` then `npm run preview` in `web/` serves `dist` on port 4173 and the
 * game talks to the same live database either way:
 *
 *     SITE=http://127.0.0.1:4173 node Tools/blurt_e2e.mjs
 *
 * It leaves a finished game behind in the database. There is no harm in that,
 * but the room is never pruned.
 */

import puppeteer from "/Users/pajones/projects/vibe_games/.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const SITE = process.env.SITE ?? "https://play.vibegames.party";
const DB = "https://vibe-words-party-default-rtdb.firebaseio.com";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const say = (...a) => console.log("  ", ...a);

/** Reads a node straight from the database, for what the screens cannot show. */
async function read(code, path) {
  const res = await fetch(`${DB}/blurt/${code}/${path}.json`);
  return res.ok ? await res.json() : null;
}

/**
 * The room key for a code as it is *displayed*.
 *
 * The screen shows two words a space apart — the separator is a reading aid and
 * not part of the code — while the room in the database keeps a hyphen. Anything
 * that reads the code off the screen and then talks to the database has to put it
 * back. `Tools/blurt_presence_e2e.mjs` has the same helper.
 */
function roomKey(displayed) {
  const cleaned = displayed.toLowerCase().replace(/[^a-z0-9-]/g, "");
  return /^[a-z]{8}$/.test(cleaned) ? `${cleaned.slice(0, 4)}-${cleaned.slice(4)}` : cleaned;
}

const failures = [];
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures.push(what);
}

const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: "new",
});

const names = ["Alex", "Sam", "Jo", "Robin"];
const players = [];
for (const name of names) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.on("pageerror", (e) => console.log(`  [${name} error]`, String(e).slice(0, 120)));
  players.push({ name, page });
}

async function nameSelf(page, name) {
  await page.waitForSelector(".blurt__sheet input", { timeout: 15000 });
  await page.type(".blurt__sheet input", name);
  await page.click(".blurt__sheet .blurt__primary");
  await sleep(800);
}

/** What this screen is allowed to see, and what it can do. */
async function roleOf(page) {
  const text = (sel) => page.$eval(sel, (el) => el.textContent.trim()).catch(() => null);
  return {
    ownWord: await text(".blurt__word"),
    watchedWord: await text(".blurt__watched-word"),
    guessing: (await page.$(".blurt__guessing")) !== null,
    canBuzz: (await page.$(".blurt__buzz")) !== null,
    // There is no number on screen any more, by design: a round is a random
    // length so that nobody can count it down. The bar carries the round's own
    // start and end times, which is what lets this tell a running clock from a
    // stopped one without the game having to show one.
    clock: await page
      .$eval(".blurt__clock", (el) => {
        const endsAt = Number(el.dataset.endsAt);
        return Number.isFinite(endsAt) ? (endsAt - Date.now()) / 1000 : null;
      })
      .catch(() => null),
    roundLength: await page
      .$eval(".blurt__clock", (el) => {
        const endsAt = Number(el.dataset.endsAt);
        const startedAt = Number(el.dataset.startedAt);
        return Number.isFinite(endsAt) && Number.isFinite(startedAt)
          ? (endsAt - startedAt) / 1000
          : null;
      })
      .catch(() => null),
    scores: await page.$$eval(".blurt__score strong", (els) => els.map((e) => e.textContent.trim())),
    teamNames: await page.$$eval(".blurt__score-names", (els) => els.map((e) => e.textContent.trim())),
    teamsMine: await page.$$eval(".blurt__score-mine", (els) => els.length),
  };
}

// ── one player starts a game, the other three join it ───────────────────
await players[0].page.goto(`${SITE}/blurt`, { waitUntil: "networkidle0" });
await sleep(1500);
await players[0].page.click(".blurt__lobby .blurt__primary");
await nameSelf(players[0].page, players[0].name);
await players[0].page.waitForSelector(".blurt__code-value", { timeout: 20000 });
const code = await players[0].page.$eval(".blurt__code-value", (el) => el.textContent.trim());
say("code shown to the host:", code);
// The display sets the two halves apart with a dot, so the code does not read as
// three words in a row. The separator is a reading aid, not part of the code.
check(/^[A-Z]{4}·[A-Z]{4}$/.test(code),
  `the code reads as two words, a dot apart (got ${code})`);

// The other three arrive on a link whose code has been retyped by hand rather
// than copied: lower case, with a hyphen where the screen showed a space. That
// is how a code gets shared in practice — read out loud, typed from memory — and
// it is the only thing that checks the code is normalised on the way in. The
// screen shows eight capitals and a space, so the interesting case is somebody
// reaching for the wrong separator.
const letters = code.replace(/[^A-Za-z]/g, "").toLowerCase();
const [wordOne, wordTwo] = [letters.slice(0, 4), letters.slice(4)];
const retyped = `${wordOne}-${wordTwo}`;
say("the others retype it as:", retyped);

for (const player of players.slice(1)) {
  await player.page.goto(`${SITE}/blurt?game=${retyped}`, { waitUntil: "networkidle0" });
  await sleep(2200);
  await nameSelf(player.page, player.name);
  await sleep(1200);
}

// ── the host deals the teams ────────────────────────────────────────────
await players[0].page.waitForFunction(
  () => document.querySelectorAll(".blurt__roster li").length === 4,
  { timeout: 20000 },
);
await players[0].page.click(".blurt__lobby .blurt__primary");
await sleep(3000);

// The word is not dealt until the round's clock starts, so at this point
// exactly one person has the button that starts it, and that is the describer.
const starters = [];
for (const player of players) {
  if (await player.page.$(".blurt__handover .blurt__primary")) starters.push(player);
}
check(starters.length === 1, `exactly one person can start the round (got ${starters.length})`);

// The handover names the person whose turn it is, and says nothing about which
// team that is. It used to carry a coloured "TEAM ONE" tag, which people read as
// saying they were on that team — the scoreboard says who is on what, and this
// screen is not supposed to be about that at all.
const tagged = [];
for (const player of players) {
  if (await player.page.$(".blurt__handover .blurt__team-tag")) tagged.push(player.name);
}
check(tagged.length === 0, `the handover names the next person and no team (${tagged.join(", ")})`);

// ── the describer starts the round's clock ──────────────────────────────
const firstDescriber = { player: starters[0] };
await firstDescriber.player.page.click(".blurt__handover .blurt__primary");
await sleep(2500);

// Now every screen should be one of the three roles.
const dealt = [];
for (const player of players) dealt.push({ player, role: await roleOf(player.page) });
const describers = dealt.filter((d) => d.role.ownWord !== null);
const guessers = dealt.filter((d) => d.role.guessing);
const watchers = dealt.filter((d) => d.role.canBuzz);

check(describers.length === 1, `exactly one describer (got ${describers.length})`);
check(guessers.length === 1, `exactly one team-mate guessing (got ${guessers.length})`);
check(watchers.length === 2, `both of the other team can buzz (got ${watchers.length})`);
check(
  watchers.length > 0 && watchers.every((w) => w.role.watchedWord !== null),
  "the other team is shown the word so the buzz is a judgement",
);
check(
  guessers.length > 0 && guessers.every((g) => g.role.ownWord === null && g.role.watchedWord === null),
  "the guesser cannot see the word",
);

// Every player can see who is on which team, and which one is theirs.
for (const player of players) {
  const role = await roleOf(player.page);
  const listed = role.teamNames
    .flatMap((names) => names.split(","))
    .map((name) => name.trim())
    .filter(Boolean)
    .sort();
  check(
    JSON.stringify(listed) === JSON.stringify([...names].sort()),
    `${player.name} can see who is on each team`,
  );
  check(role.teamsMine === 1, `${player.name} has exactly one team marked as theirs`);
  check(
    role.scores.length === 2,
    `${player.name} can see both team names and scores`,
  );
}

const secs = (value) => (value === null ? 'none' : value.toFixed(1));

const before = await roleOf(firstDescriber.player.page);
check(before.clock !== null, `the clock is running (${secs(before.clock)}s left)`);
check(
  before.roundLength !== null && before.roundLength >= 50 && before.roundLength <= 70,
  `the round length is a random 50-70 seconds (${secs(before.roundLength)}s)`,
);
check(before.ownWord !== null, `the describer has a word: ${JSON.stringify(before.ownWord)}`);

// ── the code is still reachable now the game is under way ───────────────
// It used to be out of reach from a running game: the big card only lives in
// the lobby, and the join field only exists before a game starts. That is
// exactly when somebody new turns up, and Blurt puts a late arrival on the
// smaller team.
const gear = await firstDescriber.player.page.$(".blurt__code-button");
check(gear !== null, "a running game offers the code");
if (gear) {
  await firstDescriber.player.page.click(".blurt__code-button");
  await sleep(400);
  const shown = await firstDescriber.player.page
    .$eval(".blurt__sheet .blurt__code-value", (el) => el.textContent.trim())
    .catch(() => null);
  const sameCode = (shown ?? "").replace(/[^A-Za-z]/g, "") === code.replace(/[^A-Za-z]/g, "");
  check(sameCode, `the sheet shows the room's code (got ${JSON.stringify(shown)})`);
  // Closed again, so the round carries on underneath it.
  await firstDescriber.player.page.click(".blurt__sheet .blurt__skip");
  await sleep(400);
}

// ── "got it" passes the word to the other team, and the clock keeps going ─
const startedAt = before.clock;
const firstDescriberName = firstDescriber.player.name;
await firstDescriber.player.page.click(".blurt__describer .blurt__primary");
await sleep(2500);

const afterPass = [];
for (const player of players) afterPass.push({ player, role: await roleOf(player.page) });
const newDescribers = afterPass.filter((d) => d.role.ownWord !== null);
const stillGuessing = afterPass.filter((d) => d.role.guessing);

check(newDescribers.length === 1, `still exactly one describer after the pass (${newDescribers.length})`);
check(
  newDescribers[0]?.player.name !== firstDescriberName,
  `the word moved to the other team (was ${firstDescriberName}, now ${newDescribers[0]?.player.name})`,
);

const clockNow = await firstDescriber.player.page
  .$eval(".blurt__clock", (el) => {
    const endsAt = Number(el.dataset.endsAt);
    return Number.isFinite(endsAt) ? (endsAt - Date.now()) / 1000 : null;
  })
  .catch(() => null);
check(
  clockNow !== null && clockNow <= startedAt,
  `the clock did not reset across the pass (${secs(startedAt)}s -> ${secs(clockNow)}s left)`,
);
check(stillGuessing.length === 1, `one person is still guessing (${stillGuessing.length})`);
say("scores mid-round:", JSON.stringify((await roleOf(players[0].page)).scores));

// ── the team facing the word buzzes ─────────────────────────────────────
const buzzer = afterPass.find((d) => d.role.canBuzz);
if (buzzer) {
  // Who is holding the word as the round ends, and which word they were on.
  const beforeBuzz = await read(roomKey(code), "play");

  await buzzer.player.page.click(".blurt__buzz");
  await sleep(2500);
  const result = await roleOf(players[0].page);
  say(
    "result:",
    await players[0].page
      .$eval(".blurt__result", (el) => el.textContent.trim())
      .catch(() => "(none)"),
  );
  say("scores after the buzz:", JSON.stringify(result.scores));

  // The holder keeps the word into the next round. It used to move on to the
  // next person in the rotation, which meant somebody handed the word seconds
  // before the clock stopped never got to describe it — their turn was spent on
  // a word they never read out.
  const afterBuzz = await read(roomKey(code), "play");
  check(
    afterBuzz.describer === beforeBuzz.describer,
    `whoever is left holding the word starts the next round (${beforeBuzz.describer} -> ${afterBuzz.describer})`,
  );
  check(
    afterBuzz.word === beforeBuzz.word + 1,
    `with a new word, not the same one (${beforeBuzz.word} -> ${afterBuzz.word})`,
  );
  check(
    afterBuzz.team === beforeBuzz.team,
    `and on the same side, which is the side that lost the point (${beforeBuzz.team})`,
  );

  check(
    result.scores.reduce((sum, value) => sum + Number(value), 0) === 1,
    "the buzz scored exactly one point",
  );
} else {
  check(false, "somebody could buzz");
}

// ── and the round after it can be started ───────────────────────────────
//
// A finished round leaves the state as "ended" with the next round's rotation
// already set up behind it, so the app refused to start round two while round
// one had started fine. The browser has the same shape of handover, so it is
// checked for it too.
let starter = null;
for (const player of players) {
  if (await player.page.$(".blurt__handover .blurt__primary")) {
    starter = player;
    break;
  }
}
check(starter !== null, "somebody is asked to start the next round");

if (starter) {
  await starter.page.click(".blurt__handover .blurt__primary");
  await sleep(2500);
  const next = await roleOf(starter.page);
  check(next.clock !== null, `the next round started (${secs(next.clock)}s left)`);
  check(
    next.roundLength !== null && next.roundLength >= 50 && next.roundLength <= 70,
    `and is its own random length (${secs(next.roundLength)}s)`,
  );
}

await browser.close();

console.log(
  failures.length === 0
    ? "\nAll checks passed.\n"
    : `\n${failures.length} check(s) failed:\n${failures.map((f) => `  - ${f}`).join("\n")}\n`,
);
process.exitCode = failures.length === 0 ? 0 : 1;
