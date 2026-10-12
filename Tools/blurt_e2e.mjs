/**
 * Plays a real game of Vibe Blurt with four players, against the live site and
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
 * It leaves a finished game behind in the database. There is no harm in that,
 * but the room is never pruned.
 */

import puppeteer from "/Users/pajones/projects/vibe_games/.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const SITE = "https://play.vibegames.party";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const say = (...a) => console.log("  ", ...a);

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
    clock: await page
      .$eval(".blurt__clock > span", (el) => Number(el.textContent.trim()))
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

// The other three arrive on a link whose code has been retyped by hand rather
// than copied: capitalised, and without the hyphen. That is how a code gets
// shared in practice — read out loud, typed from memory — and it is the only
// thing that checks the code is normalised on the way in. The host's screen
// shows it in capitals, so this is also the exact string somebody would copy
// down.
const retyped = code.toUpperCase().replace(/-/g, "");
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

const before = await roleOf(firstDescriber.player.page);
check(before.clock !== null, `the clock is running (${before.clock}s)`);
check(before.ownWord !== null, `the describer has a word: ${JSON.stringify(before.ownWord)}`);

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
  .$eval(".blurt__clock > span", (el) => Number(el.textContent.trim()))
  .catch(() => null);
check(
  clockNow !== null && clockNow <= startedAt,
  `the clock did not reset across the pass (${startedAt}s -> ${clockNow}s)`,
);
check(stillGuessing.length === 1, `one person is still guessing (${stillGuessing.length})`);
say("scores mid-round:", JSON.stringify((await roleOf(players[0].page)).scores));

// ── the team facing the word buzzes ─────────────────────────────────────
const buzzer = afterPass.find((d) => d.role.canBuzz);
if (buzzer) {
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
  check(next.clock !== null, `the next round started (clock at ${next.clock}s)`);
}

await browser.close();

console.log(
  failures.length === 0
    ? "\nAll checks passed.\n"
    : `\n${failures.length} check(s) failed:\n${failures.map((f) => `  - ${f}`).join("\n")}\n`,
);
process.exitCode = failures.length === 0 ? 0 : 1;
