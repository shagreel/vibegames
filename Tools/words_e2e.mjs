/**
 * Plays a game of Word Vibe in a browser, against the live database.
 *
 * This exists because Word Vibe is the one game on the web with no end-to-end
 * check at all: Blurt has `Tools/blurt_e2e.mjs`, but the browser version of Words
 * is only covered by unit tests of its scoring rules. That was survivable while
 * the component was left alone. It stopped being survivable when the component's
 * *initialisation* was rewritten — the room is now worked out in a lazy state
 * initialiser rather than in a mount effect, the remembered name comes from the
 * same place, and the restart countdown is derived rather than cleared in an
 * effect. None of that is visible to a unit test, and all of it is load-bearing.
 *
 * What it checks, in order:
 *
 *   1. A visit with no code in the address bar gets one, and it is written back
 *      into the bar — a refresh has to come back to the same room.
 *   2. Reloading keeps that room rather than minting another one. This is the
 *      thing React's double-invoked initialiser would break, and it would look
 *      like a game that silently moved to a new room on refresh.
 *   3. A name, once given, is not asked for again.
 *   4. Creating and starting a game leaves a board that actually accepts input —
 *      which is what the removed "solo game is always started" branch used to
 *      paper over.
 *   5. A pending restart shows a countdown, counts it down, and clears it when
 *      the restart time is spent.
 *
 * Run it after deploying, from the repository root:
 *
 *     node Tools/words_e2e.mjs
 *
 * Or against a local build first, which is what to do before deploying:
 *
 *     SITE=http://localhost:4173 node Tools/words_e2e.mjs
 *
 * It leaves a finished game behind in the database, like the Blurt one does.
 */

import puppeteer from "/Users/pajones/projects/vibe_games/.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const SITE = process.env.SITE ?? "https://play.vibegames.party";
const DATABASE = "https://vibe-words-party-default-rtdb.firebaseio.com";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const say = (...a) => console.log("  ", ...a);

const failures = [];
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures.push(what);
}

/** Writes straight to the room, the way the players' own phones do. */
async function write(path, body) {
  const response = await fetch(`${DATABASE}/games/${path}.json`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return response.status;
}

const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: "new",
});

const page = await browser.newPage();
page.on("pageerror", (e) => console.log("  [page error]", String(e).slice(0, 160)));

// ── a visit with no code is a menu, not a room ───────────────────────────
//
// It used to mint a code on arrival, which made solo play a room that was never
// written: the listeners for it told the solo round it had not started, and
// "play again" tried to write a word into a room that did not exist.
await page.goto(`${SITE}/words`, { waitUntil: "networkidle0" });
await page.waitForSelector(".lobby-card", { timeout: 15000 });

const bareUrl = new URL(page.url());
check(!bareUrl.searchParams.get("game"),
  `a first visit is not put in a room (got ${JSON.stringify(bareUrl.search)})`);
check(await page.$(".name-input") === null,
  "and it does not ask for a name before there is anybody to tell it to");

// ── choosing a room is what makes one ────────────────────────────────────
await clickByText(".lobby-card", "Race your friends");
await page.waitForSelector(".name-input", { timeout: 15000 });

// ── a name is asked for once ─────────────────────────────────────────────
await page.type(".name-input", "Tester");
await page.click(".name-submit-button");
await page.waitForSelector(".start-game-button", { timeout: 10000 });

const firstUrl = new URL(page.url());
check(!firstUrl.searchParams.get("game"),
  "the room is not minted until the game is created");

await clickByText(".start-game-button", "Create Game");
await sleep(2500);
const firstCode = new URL(page.url()).searchParams.get("game") ?? "";
say("the address bar gained:", firstCode);
check(/^[a-z]{4}-[a-z]{4}$/.test(firstCode),
  `creating a game puts its code in the address bar (got ${JSON.stringify(firstCode)})`);

// ── and a refresh comes back to the same room ────────────────────────────
await page.reload({ waitUntil: "networkidle0" });
await sleep(1200);
const afterReload = new URL(page.url()).searchParams.get("game") ?? "";
check(afterReload === firstCode,
  `a reload keeps the room (was ${firstCode}, now ${afterReload || "nothing"})`);


// ── create it, then start it ─────────────────────────────────────────────
async function clickByText(selector, text) {
  const clicked = await page.evaluate(
    (sel, wanted) => {
      const button = [...document.querySelectorAll(sel)].find((b) =>
        b.textContent.includes(wanted),
      );
      if (!button) return false;
      button.click();
      return true;
    },
    selector,
    text,
  );
  if (!clicked) throw new Error(`no ${selector} saying ${text}`);
}

await clickByText(".start-game-button", "Start Game");
await sleep(2500);

// The board has to accept input. "ZZZZZ" is not in the list, so the reply is the
// word-list message — which only appears if the round is live.
await page.keyboard.type("ZZZZZ");
await page.keyboard.press("Enter");
await sleep(600);
const refusal = await page.$eval(".game-message__text", (el) => el.textContent.trim()).catch(() => null);
check(refusal === "Not in word list",
  `the started board accepts input (got ${JSON.stringify(refusal)})`);

// ── a pending restart shows a countdown, and clears it ───────────────────
const restartAt = Date.now() + 6000;
const writeStatus = await write(`${firstCode}/restartTime`, restartAt);
check(writeStatus === 200, `the restart time was written (HTTP ${writeStatus})`);

const counted = await page
  .waitForSelector(".countdown-container", { timeout: 8000 })
  .then(() => true)
  .catch(() => false);
check(counted, "a pending restart shows a countdown");

if (counted) {
  const readNumber = () =>
    page.$eval(".countdown-number", (el) => Number(el.textContent.trim())).catch(() => null);
  const before = await readNumber();
  await sleep(1500);
  const after = await readNumber();
  say("countdown", before, "->", after);
  check(
    before !== null && after !== null && after < before,
    `the countdown counts down (${before} -> ${after})`,
  );
}

// Spent: the number has to go, not sit at zero for the rest of the game.
await sleep(6000);
const stillShowing = await page.$(".countdown-container");
check(stillShowing === null, "the countdown clears once the restart time is spent");

// ── and the name is not asked for again ─────────────────────────────────
await page.reload({ waitUntil: "networkidle0" });
await sleep(1200);
const askedAgain = await page.$(".name-input");
check(askedAgain === null, "the remembered name is not asked for again");

// ── a code retyped from the screen lands in the same room ───────────────
// Capitals, and a space where the screen showed one.
const retyped = firstCode.replace("-", " ").toUpperCase();
await page.goto(`${SITE}/words?game=${encodeURIComponent(retyped)}`, { waitUntil: "networkidle0" });
await sleep(1500);
const normalised = new URL(page.url()).searchParams.get("game") ?? "";
check(normalised === firstCode,
  `a code retyped from the screen lands in the room it names (got ${JSON.stringify(normalised)})`);
check(await page.$(".grid") !== null,
  "and arriving that way goes straight back to the live board");

await browser.close();

if (failures.length) {
  console.log(`\n${failures.length} check(s) failed:`);
  for (const failure of failures) console.log(`  - ${failure}`);
  process.exit(1);
}
console.log("\nAll checks passed.");
