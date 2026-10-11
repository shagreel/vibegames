/**
 * Plays a real two-player game of Vibe Blurt, against the live site and the
 * live database, in two isolated browser contexts so the two players have
 * separate storage and genuinely different identities.
 *
 * This exists because it is the only check that covers the whole game: the
 * rules, the transaction that ends a turn, the deck both clients derive from the
 * seed, and the one property the game depends on above all — that the word
 * reaches the describer's screen and no other.
 *
 * It has already earned its keep twice. It caught a host whose name was read
 * from a stale closure, so the game was created with a blank creator and the
 * rules refused it; and it caught a player who followed a link never being
 * registered at all. Neither was reachable from the unit tests.
 *
 * Run it after deploying, from the repository root:
 *
 *     node Tools/blurt_e2e.mjs
 *
 * It leaves a finished game behind in the database. There is no harm in that,
 * but the room is never pruned.
 */

import puppeteer from "/Users/pajones/projects/vibe_games/.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: "new",
});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const say = (...a) => console.log("  ", ...a);

// Two isolated contexts: separate localStorage, so two different players.
const ctxA = await browser.createBrowserContext();
const ctxB = await browser.createBrowserContext();
const A = await ctxA.newPage();
const B = await ctxB.newPage();
for (const [p, label] of [[A, "A"], [B, "B"]]) {
  p.on("pageerror", (e) => console.log(`  [${label} error]`, String(e).slice(0, 120)));
}

async function nameSelf(page, name) {
  await page.waitForSelector(".blurt__sheet input", { timeout: 10000 });
  await page.type(".blurt__sheet input", name);
  await page.click(".blurt__sheet .blurt__primary");
  await sleep(700);
}

// ── A creates the game ────────────────────────────────────────────────
await A.goto("https://play.vibegames.party/blurt", { waitUntil: "networkidle0" });
await sleep(1500);
await A.click(".blurt__lobby .blurt__primary");
await nameSelf(A, "Alex");
await A.waitForSelector(".blurt__code-value", { timeout: 15000 });
const code = await A.$eval(".blurt__code-value", (el) => el.textContent.trim());
say("code shown to the host:", code);

// ── B joins with it ───────────────────────────────────────────────────
await B.goto(`https://play.vibegames.party/blurt?game=${code.toLowerCase()}`, { waitUntil: "networkidle0" });
await sleep(2500);
await nameSelf(B, "Sam");
await sleep(1500);

const roster = await A.$$eval(".blurt__roster li", (els) => els.map((e) => e.textContent.trim()));
say("host sees the room:", JSON.stringify(roster));

// ── A deals the teams ─────────────────────────────────────────────────
await A.click(".blurt__lobby .blurt__primary");
await sleep(2500);

const stateOf = async (page) => {
  const word = await page.$eval(".blurt__word", (el) => el.textContent.trim()).catch(() => null);
  const canBlurt = (await page.$(".blurt__blurt")) !== null;
  const handover = await page.$eval(".blurt__handover h2", (el) => el.textContent.trim()).catch(() => null);
  const scores = await page.$$eval(".blurt__score strong", (els) => els.map((e) => e.textContent.trim()));
  return { word, canBlurt, handover, scores };
};
say("after the deal — A:", JSON.stringify(await stateOf(A)));
say("after the deal — B:", JSON.stringify(await stateOf(B)));

// ── whoever is describing starts the clock ────────────────────────────
const describer = (await A.$(".blurt__word")) ? A : B;
const other = describer === A ? B : A;
await describer.click(".blurt__handover .blurt__primary");
await sleep(2000);

const mid = await stateOf(describer);
say("describer sees a word:", JSON.stringify(mid.word), "| clock/bar present:", (await describer.$(".blurt__bar")) !== null);
say("other player sees the word?", JSON.stringify((await stateOf(other)).word));
say("other player can call a blurt:", (await stateOf(other)).canBlurt);

// ── the other team calls it ───────────────────────────────────────────
await other.click(".blurt__blurt");
await sleep(2500);
say("scores after the blurt — A:", JSON.stringify((await stateOf(A)).scores));
say("scores after the blurt — B:", JSON.stringify((await stateOf(B)).scores));
say("result banner:", await A.$eval(".blurt__result", (el) => el.textContent.trim()).catch(() => "(none)"));

await browser.close();
