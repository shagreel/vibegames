/**
 * Plays real games of Similar Vibe with real browsers to check what happens when
 * people leave and come back.
 *
 * This exists because none of it is visible in one client. Presence is a
 * property of the *room*: a phone has to actually go away for the server to
 * clear it, and a second phone has to notice. There is no unit test that can
 * watch a socket drop, and the bugs this covers were all of the shape "it looks
 * right on the phone that stayed".
 *
 * Three scenarios, each with its own game:
 *
 *   1. Somebody leaves, somebody new arrives, the one who left comes back.
 *      Checks the leaver is dropped, the new arrival joins the smaller side *of
 *      the people who are here* — not of a team list that still counts the
 *      departed — and the returner gets their own team back.
 *   2. A round in progress when the person holding the word leaves. Checks the
 *      rotation never names a phone that is not in the room.
 *   3. A round that has *not* started when the person who is up leaves. Nothing
 *      is running, so no clock ends it: checks a team-mate is offered it, and
 *      that whoever starts it is written down as the describer.
 *   4. A connection that drops and comes back underneath a live page — a phone
 *      asleep, a laptop shut. Checks presence is re-announced without a reload,
 *      because a room that has stopped seeing a phone keeps a team slot for it
 *      and the rotation skips it forever.
 *
 * Run it after deploying, from the repository root:
 *
 *     node Tools/blurt_presence_e2e.mjs
 *
 * Or against a local build first, as the other two browser scripts do:
 *
 *     SITE=http://localhost:4173 node Tools/blurt_presence_e2e.mjs
 *
 * It leaves finished games behind in the database. There is no harm in that,
 * but the rooms are never pruned.
 */

import puppeteer from "/Users/pajones/projects/vibe_games/.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const SITE = process.env.SITE ?? "https://play.vibegames.party";
const DB = "https://vibe-words-party-default-rtdb.firebaseio.com";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const failures = [];
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures.push(what);
}

async function read(code, path) {
  const res = await fetch(`${DB}/blurt/${code}/${path}.json`);
  return res.ok ? await res.json() : null;
}

/** Waits for a condition on the database, because every write is asynchronous. */
async function until(fn, timeout = 15000) {
  const started = Date.now();
  for (;;) {
    const value = await fn();
    if (value) return value;
    if (Date.now() - started > timeout) return null;
    await sleep(500);
  }
}

/**
 * The room key for a code as it is *displayed*.
 *
 * The screen shows two words a space apart — the separator is a reading aid and
 * not part of the code — while the room in the database keeps a hyphen. Anything
 * that reads the code off the screen and then talks to the database has to put it
 * back, which is the mirror of `GameCode.normalise` and `normaliseGameCode`.
 */
function roomKey(displayed) {
  const cleaned = displayed.toLowerCase().replace(/[^a-z0-9-]/g, "");
  return /^[a-z]{8}$/.test(cleaned) ? `${cleaned.slice(0, 4)}-${cleaned.slice(4)}` : cleaned;
}

async function nameSelf(page, name) {
  try {
    await page.waitForSelector(".blurt__sheet input", { timeout: 6000 });
    await page.type(".blurt__sheet input", name);
    await page.click(".blurt__sheet .blurt__primary");
    await sleep(800);
  } catch {
    // Already named: the prompt only appears once per browser.
  }
}

const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: "new",
});

/** Four seats, each its own browser context so they are genuinely separate. */
async function seatsFor(names) {
  const seats = [];
  for (const name of names) {
    const context = await browser.createBrowserContext();
    seats.push({ name, context, page: await context.newPage() });
  }
  return seats;
}

async function has(seat, selector) {
  return seat.page.$(selector).then((el) => el !== null).catch(() => false);
}

/** Assembles a room of four and leaves it on the handover screen. */
async function assembleRoom(seats) {
  await seats[0].page.goto(`${SITE}/blurt`, { waitUntil: "networkidle0" });
  await sleep(1500);
  await seats[0].page.click(".blurt__lobby .blurt__primary");
  await nameSelf(seats[0].page, seats[0].name);
  await seats[0].page.waitForSelector(".blurt__code-value", { timeout: 20000 });
  const shown = await seats[0].page.$eval(".blurt__code-value", (el) => el.textContent.trim());
  // What is on screen is for a person to read out; the key is what the database
  // is filed under.
  const code = roomKey(shown);

  for (const seat of seats.slice(1)) {
    await seat.page.goto(`${SITE}/blurt?game=${code}`, { waitUntil: "networkidle0" });
    await sleep(2000);
    await nameSelf(seat.page, seat.name);
    await sleep(900);
  }
  await seats[0].page.waitForFunction(
    () => document.querySelectorAll(".blurt__roster li").length === 4,
    { timeout: 20000 },
  );
  await seats[0].page.click(".blurt__lobby .blurt__primary");
  await sleep(3000);
  return code;
}

const teamCounts = (players, teams) => {
  const counts = { 1: 0, 2: 0 };
  for (const id of Object.keys(players)) if (teams[id]) counts[teams[id]] += 1;
  return counts;
};

// ── 1. Leaving, arriving, and coming back ─────────────────────────────────

console.log("\n1. a leaver, a new arrival, and a return");

{
  const names = ["Alex", "Sam", "Jo", "Robin"];
  const seats = await seatsFor(names);
  const code = await assembleRoom(seats);
  console.log(`   room ${code}`);

  const players = await read(code, "players") ?? {};
  const teams = await read(code, "teams") ?? {};
  const idOf = (name, list = players) => Object.keys(list).find((k) => list[k] === name);

  const robinId = idOf("Robin");
  const robinTeam = teams[robinId];

  const leaver = seats.find((s) => s.name === "Robin");
  await leaver.page.close();
  const dropped = await until(async () => !(robinId in ((await read(code, "players")) ?? {})));
  check(Boolean(dropped), "a phone going away drops that player from the room");

  // And drops them from what everybody else can read. The slot in `teams` is
  // what brings them back to their own side later, so it stays — but the name
  // must go with the player, not with the slot. This used to render "Jo,
  // Someone" on the scoreboard of a room with three people in it.
  const watch = (seats.find((s) => s.name === "Alex") ?? seats[0]).page;
  const boardNames = await until(async () => {
    const shown = await watch
      .$$eval(".blurt__score-names", (els) => els.map((el) => el.textContent.trim()))
      .catch(() => []);
    return shown.length > 0 && !shown.some((text) => text.includes("Robin")) ? shown : null;
  });
  check(Boolean(boardNames),
        `the scoreboard drops the player who left (now ${JSON.stringify(boardNames)})`);
  check(!(boardNames ?? ["Someone"]).some((text) => text.includes("Someone")),
        "and no empty slot is given a name");

  const here = await read(code, "players") ?? {};
  const teamsNow = await read(code, "teams") ?? {};
  const counts = teamCounts(here, teamsNow);
  check(robinId in teamsNow, "the team list still remembers which side they were on");
  check(counts[1] !== counts[2], `so one side is now short (${counts[1]}-${counts[2]})`);
  const shorter = counts[1] < counts[2] ? 1 : 2;

  const freshContext = await browser.createBrowserContext();
  const fresh = await freshContext.newPage();
  await fresh.goto(`${SITE}/blurt?game=${code}`, { waitUntil: "networkidle0" });
  await sleep(2500);
  await nameSelf(fresh, "Casey");
  const casey = await until(async () => {
    const list = await read(code, "players") ?? {};
    const id = idOf("Casey", list);
    if (!id) return null;
    const side = (await read(code, "teams") ?? {})[id];
    return side ? { id, side } : null;
  });
  check(Boolean(casey), "a new arrival is given a team");
  if (casey) {
    check(casey.side === shorter,
          `and it is the shorter side of the people here (${casey.side}, expected ${shorter})`);
  }

  const back = await leaver.context.newPage();
  await back.goto(`${SITE}/blurt?game=${code}`, { waitUntil: "networkidle0" });
  await sleep(2500);
  await nameSelf(back, "Robin");
  const returned = await until(async () =>
    robinId in ((await read(code, "players")) ?? {}) ? (await read(code, "teams") ?? {})[robinId] : null);
  check(returned === robinTeam,
        `and a returning player is put back on their own team (${robinTeam} -> ${returned})`);
}

// ── 2. A round in progress when the holder leaves ─────────────────────────

console.log("\n2. the word is never handed to a phone that has gone");

{
  const names = ["Alex", "Sam", "Jo", "Robin"];
  const seats = await seatsFor(names);
  const code = await assembleRoom(seats);
  console.log(`   room ${code}`);

  const alive = () => seats.filter((s) => !s.gone);
  const holder = async () => {
    for (const seat of alive()) if (await has(seat, ".blurt__describer .blurt__primary")) return seat;
    return null;
  };

  let starter = null;
  for (const seat of alive()) if (await has(seat, ".blurt__handover .blurt__primary")) starter = seat;
  check(Boolean(starter), "one phone is asked to start the round");
  await starter.page.click(".blurt__handover .blurt__primary");
  await sleep(2500);

  const players = await read(code, "players") ?? {};
  const idOf = (name) => Object.keys(players).find((k) => players[k] === name);

  const seen = new Set();
  let turns = 0;
  for (let i = 0; i < 9; i += 1) {
    const play = await read(code, "play");
    if (play?.describer) seen.add(play.describer);
    const who = await holder();
    if (!who) break;
    await who.page.click(".blurt__describer .blurt__primary");
    await sleep(1800);
    turns += 1;
  }
  check(seen.size >= 3, `the rotation works its way round (${seen.size} people over ${turns} turns)`);

  const leaverId = [...seen][0];
  const leaver = seats.find((s) => idOf(s.name) === leaverId);
  console.log(`   ${leaver?.name ?? leaverId} leaves, having had a turn`);
  leaver.gone = true;
  await leaver.page.close();
  const gone = await until(async () => !(leaverId in ((await read(code, "players")) ?? {})));
  check(Boolean(gone), "and is dropped from the room");

  const after = [];
  for (let i = 0; i < 5; i += 1) {
    const who = await holder();
    if (!who) break;
    await who.page.click(".blurt__describer .blurt__primary");
    await sleep(1800);
    const play = await read(code, "play");
    const here = await read(code, "players") ?? {};
    after.push(play?.describer);
    if (play?.describer && !(play.describer in here)) {
      check(false, `the word was handed to ${play.describer}, who is not in the room`);
    }
  }
  check(after.length > 0, `the round carried on without them (${after.length} more turns)`);
  check(!after.includes(leaverId), `the departed was never named again (${JSON.stringify(after)})`);
}

// ── 3. A round nobody can start ───────────────────────────────────────────

console.log("\n3. a team-mate can take over a round whose describer has left");

{
  const names = ["Alex", "Sam", "Jo", "Robin"];
  const seats = await seatsFor(names);
  const code = await assembleRoom(seats);
  console.log(`   room ${code}`);

  let starter = null;
  for (const seat of seats) if (await has(seat, ".blurt__handover .blurt__primary")) starter = seat;
  check(Boolean(starter), "the round is waiting for one phone to start it");

  const players = await read(code, "players") ?? {};
  const teams = await read(code, "teams") ?? {};
  const idOf = (name) => Object.keys(players).find((k) => players[k] === name);
  const starterId = idOf(starter.name);
  const mate = seats.find((s) => s !== starter && teams[idOf(s.name)] === teams[starterId]);

  starter.gone = true;
  await starter.page.close();
  const gone = await until(async () => !(starterId in ((await read(code, "players")) ?? {})));
  check(Boolean(gone), `${starter.name} is dropped when their phone goes`);

  let offered = false;
  for (let i = 0; i < 10; i += 1) {
    if (await has(mate, ".blurt__handover .blurt__primary")) { offered = true; break; }
    await sleep(1000);
  }
  check(offered, `${mate.name} is offered the round their team-mate left`);

  if (offered) {
    await mate.page.click(".blurt__handover .blurt__primary");
    await sleep(2500);
    const play = await read(code, "play");
    const here = await read(code, "players") ?? {};
    check(play?.state === "running", `the round started (state ${play?.state})`);
    check(play?.describer === idOf(mate.name), "and the word is on the phone that started it");
    check(play?.describer in here, "so the describer is somebody in the room");
  }
}

// ── 4. A connection that drops and comes back ─────────────────────────────

console.log("\n4. a dropped connection puts the player back on the roster");

{
  const names = ["Alex", "Sam", "Jo", "Robin"];
  const seats = await seatsFor(names);
  const code = await assembleRoom(seats);
  console.log(`   room ${code}`);

  const players = await read(code, "players") ?? {};
  const idOf = (name, list = players) => Object.keys(list).find((k) => list[k] === name);
  const victim = seats.find((s) => s.name === "Jo");
  const victimId = idOf("Jo");

  // Not a page close: the socket has to die underneath a page that is still
  // running, which is what a phone going to sleep does. Closing the tab would
  // exercise the join path instead.
  const cdp = await victim.page.target().createCDPSession();
  await cdp.send("Network.enable");
  await cdp.send("Network.emulateNetworkConditions",
    { offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0 });

  const cleared = await until(async () => !(victimId in ((await read(code, "players")) ?? {})), 40000);
  check(Boolean(cleared), "a dropped connection takes the player off the roster");
  check(victimId in ((await read(code, "teams")) ?? {}),
        "and the team list still remembers their side");

  await cdp.send("Network.emulateNetworkConditions",
    { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });

  const restored = await until(async () => (await read(code, "players"))?.[victimId], 30000);
  check(restored === "Jo",
        `the page re-announces itself on reconnect, without a reload (${JSON.stringify(restored)})`);

  const here = await read(code, "players") ?? {};
  const teams = await read(code, "teams") ?? {};
  const orphans = Object.keys(teams).filter((id) => !(id in here));
  check(orphans.length === 0,
        `so no seat is left belonging to nobody (${orphans.length} orphaned)`);
}

// ── 5. A round whose describer leaves with the clock running ──────────────

console.log("\n5. the word moves to somebody still in the room");

{
  const names = ["Alex", "Sam", "Jo", "Robin"];
  const seats = await seatsFor(names);
  const code = await assembleRoom(seats);
  console.log(`   room ${code}`);

  let starter = null;
  for (const seat of seats) if (await has(seat, ".blurt__handover .blurt__primary")) starter = seat;
  check(Boolean(starter), "one phone is asked to start the round");
  await starter.page.click(".blurt__handover .blurt__primary");
  await sleep(2500);

  const players = await read(code, "players") ?? {};
  const teams = await read(code, "teams") ?? {};
  const idOfSeat = (seat) => Object.keys(players).find((id) => players[id] === seat.name);
  const sideOf = (seat) => teams[idOfSeat(seat)];

  const starterId = idOfSeat(starter);
  const side = sideOf(starter);
  const mate = seats.find((s) => s !== starter && sideOf(s) === side);
  const other = seats.find((s) => s !== starter && sideOf(s) !== side);
  check(Boolean(mate) && Boolean(other), "with a team-mate and an opponent in the room");

  // The describer's own team-mate starts as the one guessing, so the word
  // appearing on that phone is unambiguous.
  check(!(await has(mate, ".blurt__word")), `${mate.name} starts as the one guessing`);

  // The phone holding the word goes, with the clock running.
  starter.gone = true;
  await starter.page.close();
  const cleared = await until(async () => !(starterId in ((await read(code, "players")) ?? {})));
  check(Boolean(cleared), "the describer is dropped from the room");

  const took = await until(async () => ((await has(mate, ".blurt__word")) ? true : null));
  check(Boolean(took), `${mate.name} is given the word rather than left guessing`);

  // The other side is watching for somebody who is actually here.
  const rule = await other.page
    .$eval(".blurt__buzz-rule", (el) => el.textContent.trim())
    .catch(() => "");
  console.log("   the buzz rule now reads:", JSON.stringify(rule));
  check(!rule.includes("Someone"), "and nobody is told to watch for a person who is not here");
  check(rule.includes(mate.name), `the rule names ${mate.name}, who is`);
}

await browser.close();
console.log(failures.length ? `\n${failures.length} CHECK(S) FAILED` : "\nAll checks passed.");
process.exit(failures.length ? 1 : 0);
