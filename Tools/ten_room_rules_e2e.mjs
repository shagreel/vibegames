#!/usr/bin/env node
/**
 * A Vibe Ten room is played by the host's rules: the rows, whether the rows join
 * end to end, and how a taken pair leaves the board. The web client reads them
 * from the room's meta, so a guest who has never opened the settings sheet still
 * has to get the host's game.
 *
 * This is the check that the rules really are shared: the host picks a short,
 * dim, joined room; the room's meta says so; the guest's sheet shows the same
 * rules disabled; both deal the identical board; and a pair the guest takes dims
 * rather than disappearing, which is the host's rule and not the guest's.
 *
 *   node Tools/ten_room_rules_e2e.mjs [origin]
 *
 * The default origin is the local preview build; pass https://play.vibegames.party
 * to check the live site.
 */
const origin = process.argv[2] ?? 'http://localhost:4173';
const mod = await import(
  '/Users/pajones/projects/vibe_games/.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js'
);
const puppeteer = mod.default;
const browser = await puppeteer.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: 'new',
  args: ['--hide-scrollbars'],
});
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const failures = [];
const check = (ok, what) => {
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`);
  if (!ok) failures.push(what);
};

async function nameIfAsked(page, name) {
  const field = await page.$('.ten__name-card input');
  if (!field) return;
  await page.type('.ten__name-card input', name);
  await page.click('.ten__name-card button[type="submit"]');
  await wait(500);
}

async function openSettings(page) {
  await page.click('button[aria-label="Game settings"]');
  await page.waitForSelector('.game-sheet');
}

async function closeSettings(page) {
  await page.evaluate(() => [...document.querySelectorAll('.game-sheet button')]
    .find((n) => (n.textContent ?? '').trim() === 'Done')?.click());
  await wait(250);
}

async function choose(page, group, value) {
  await page.evaluate(({ group, value }) => {
    const box = [...document.querySelectorAll('[role="group"]')]
      .find((node) => node.getAttribute('aria-label') === group);
    const button = [...(box?.querySelectorAll('button') ?? [])]
      .find((node) => (node.textContent ?? '').trim() === String(value));
    button?.click();
  }, { group, value });
  await wait(120);
}

async function sheetState(page) {
  return page.evaluate(() => {
    const group = (name) => [...document.querySelectorAll('.game-sheet [role="group"]')]
      .find((node) => node.getAttribute('aria-label') === name);
    const buttons = (name) => [...(group(name)?.querySelectorAll('button') ?? [])];
    const toggle = (name) => [...document.querySelectorAll('.game-sheet__switch')]
      .find((node) => node.getAttribute('aria-label') === name);
    const mode = buttons('When a pair is matched');
    const wrap = toggle('Rows join end to end');
    const note = document.querySelector('.game-sheet')?.textContent ?? '';
    return {
      mode: mode.map((node) => ({ label: node.textContent.trim(), on: node.dataset.on === 'true' })),
      modeDisabled: mode.length > 0 && mode.every((node) => node.disabled),
      wrapOn: wrap?.getAttribute('aria-checked') === 'true',
      wrapDisabled: Boolean(wrap?.disabled),
      note,
    };
  });
}

const cells = (page) => page.$$eval('.ten__cell', (nodes) => nodes.map((node) => {
  const label = node.getAttribute('aria-label') ?? '';
  const match = label.match(/Column (\d+) row (\d+): (\d+)(, taken)?/);
  return {
    column: Number(match[1]) - 1,
    row: Number(match[2]) - 1,
    value: Number(match[3]),
    dimmed: node.getAttribute('data-dimmed') === 'true',
  };
}));

const host = await (await browser.createBrowserContext()).newPage();
const guest = await (await browser.createBrowserContext()).newPage();
for (const page of [host, guest]) {
  await page.setViewport({ width: 402, height: 874 });
  await page.goto(`${origin}/ten`, { waitUntil: 'networkidle2' });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: 'networkidle2' });
  await wait(300);
}

// ── the host chooses the room's rules on the start screen ────────────────────
await openSettings(host);
let state = await sheetState(host);
check(state.modeDisabled === false, 'the host can choose the pair mode before the room');
check(state.wrapDisabled === false, 'and whether the rows join');
await choose(host, 'When a pair is matched', 'Dim');
await choose(host, 'Rows', 12);
await choose(host, 'Rows per press', 2);
await host.evaluate(() => {
  const toggle = [...document.querySelectorAll('.game-sheet__switch')]
    .find((node) => node.getAttribute('aria-label') === 'Rows join end to end');
  toggle?.click();
});
await wait(150);
state = await sheetState(host);
check(state.mode.some((b) => b.on && b.label === 'Dim'), 'dim is chosen');
check(state.wrapOn, 'and the rows join');
await closeSettings(host);

// ── the host makes the room; it is written once, from those choices ─────────
await host.evaluate(() => [...document.querySelectorAll('.lobby-card')]
  .find((node) => /play with others/i.test(node.textContent ?? ''))?.click());
await nameIfAsked(host, 'Host');
await host.waitForSelector('.ten__waiting', { timeout: 15000 });
const room = await host.evaluate(() => new URL(location.href).searchParams.get('game'));
check(Boolean(room), `the host made a room (${room})`);

const meta = await fetch(
  `https://vibe-words-party-default-rtdb.firebaseio.com/ten/${room}/meta.json`,
).then((response) => response.json());
check(meta?.wrap === true, 'the room remembers that the rows join');
check(meta?.mode === 'dim', 'and that a pair dims');
check(meta?.rows === 12, 'and the starting rows');
check(meta?.rowsPerAdd === 2, 'and how many rows a press adds');
check(!('columns' in (meta ?? {})) && !('difficulty' in (meta ?? {})),
  'the columns are always nine and there are no levels, so neither is in the room');

// ── the guest arrives with none of those choices and plays anyway ────────────
await guest.goto(`${origin}/ten?game=${room}`, { waitUntil: 'networkidle2' });
await nameIfAsked(guest, 'Guest');
await wait(800);

// The guest's own start screen says remove and no join; the room overrides it.
await openSettings(guest);
state = await sheetState(guest);
check(state.mode.some((b) => b.on && b.label === 'Dim'),
  "the guest's sheet shows the host's pair mode");
check(state.modeDisabled, "and it is not the guest's to change");
check(state.wrapOn, "and the guest's sheet shows the host's join");
check(state.wrapDisabled, "which is also not the guest's to change");
check(/host's rules are the game's rules/i.test(state.note),
  "the sheet says whose rules these are");
await closeSettings(guest);

await host.evaluate(() => [...document.querySelectorAll('button')]
  .find((node) => (node.textContent ?? '').trim() === 'Start')?.click());
await wait(1400);

const hostCells = await cells(host);
const guestCells = await cells(guest);
check(hostCells.length === 108, `the room starts nine by twelve (${hostCells.length} cells)`);
check(JSON.stringify(hostCells) === JSON.stringify(guestCells),
  'the guest deals the identical board');

// ── a pair taken on the guest dims: the host's rules, not the guest's ───────
const pair = guestCells.flatMap((a) => guestCells
  .filter((b) => (a.value === b.value || a.value + b.value === 10)
    && (a.column !== b.column || a.row !== b.row)
    && Math.abs(a.column - b.column) <= 1 && Math.abs(a.row - b.row) <= 1
    && !a.dimmed && !b.dimmed)
  .map((b) => [a, b]))[0];
check(Boolean(pair), 'the guest has a pair to take');
if (pair) {
  const selector = (cell) => `.ten__cell[aria-label="Column ${cell.column + 1} row ${cell.row + 1}: ${cell.value}"]`;
  await guest.click(selector(pair[0]));
  await guest.click(selector(pair[1]));
  await wait(600);
  const after = await cells(guest);
  const dimmed = after.filter((cell) => cell.dimmed);
  check(after.length === 108, `dim mode leaves every digit on the guest's board (${after.length})`);
  check(dimmed.length === 2, `and the pair is greyed out (${dimmed.length})`);
  const hostBoard = await cells(host);
  check(hostBoard.filter((cell) => cell.dimmed).length === 0,
    "the host's board is untouched");
  const scoreline = await guest.evaluate(() =>
    document.querySelector('.ten__scoreline')?.textContent ?? '');
  check(/Guest\s*1/.test(scoreline), `the room counts the guest's pair: ${JSON.stringify(scoreline)}`);
}

// ── every player can grow their own board, by the host's rows per press ─────
const guestAddRow = await guest.$('.ten__add-row');
check(Boolean(guestAddRow), 'the guest is offered a new row in the room');
const hostAddRow = await host.$('.ten__add-row');
check(Boolean(hostAddRow), 'and so is the host');
if (guestAddRow) {
  const before = (await cells(guest)).length;
  await guestAddRow.click();
  await wait(500);
  const after = await cells(guest);
  check(after.length === before + 18,
    `a press adds the host's two rows of nine (${before} → ${after.length})`);
  check(after.filter((cell) => cell.dimmed).length === 2,
    'and the taken pair stays dimmed as the board grows');
  const hostAfter = await cells(host);
  check(hostAfter.length === 108, `the host's board did not grow (${hostAfter.length})`);
  check(Boolean(await guest.$('.ten__add-row')), 'and the guest can grow again');
}

await guest.screenshot({ path: '/tmp/ten_room_rules_guest.png' });
await browser.close();
console.log(failures.length ? `\n${failures.length} CHECK(S) FAILED` : '\nAll room-rules checks passed.');
process.exit(failures.length ? 1 : 0);
