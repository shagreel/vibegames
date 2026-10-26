#!/usr/bin/env node
/**
 * Vibe Ten's settings sheet, in a browser: nine columns always, and rows from
 * 12 to 18. The levels, the column choice and the part-filled start are gone,
 * and this is the check that they stay gone — a sheet with dead or missing
 * controls is worse than one with too few.
 *
 * It also plays the room half: the host picks fourteen rows, the guest has
 * eighteen on their own start screen, and both get the host's nine-by-fourteen
 * board.
 *
 *   node Tools/ten_settings_e2e.mjs [origin]
 *
 * The default origin is the local preview build; pass https://play.vibegames.party
 * to check the live site.
 */
// Vibe Ten's remaining board setting: nine columns always, rows 12–18.
const origin = process.argv[2] ?? 'http://localhost:4173';
const mod = await import(
  '../.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js'
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

const cells = (page) => page.$$eval('.ten__cell', (nodes) => nodes.map((node) => {
  const match = (node.getAttribute('aria-label') ?? '').match(/Column (\d+) row (\d+): (\d+)/);
  return { column: Number(match[1]) - 1, row: Number(match[2]) - 1 };
}));

async function choose(page, group, value) {
  await page.evaluate(({ group, value }) => {
    const box = [...document.querySelectorAll('.game-sheet [role="group"]')]
      .find((node) => node.getAttribute('aria-label') === group);
    [...(box?.querySelectorAll('button') ?? [])]
      .find((node) => (node.textContent ?? '').trim() === String(value))?.click();
  }, { group, value });
  await wait(120);
}

async function nameIfAsked(page, name) {
  const field = await page.$('.ten__name-card input');
  if (!field) return;
  await page.type('.ten__name-card input', name);
  await page.click('.ten__name-card button[type="submit"]');
  await wait(500);
}

const host = await (await browser.createBrowserContext()).newPage();
const guest = await (await browser.createBrowserContext()).newPage();
for (const page of [host, guest]) {
  await page.setViewport({ width: 402, height: 874 });
  await page.goto(`${origin}/ten`, { waitUntil: 'networkidle2' });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: 'networkidle2' });
  await wait(300);
}

// ── the sheet has rows, and nothing else that used to be there ──────────────
await host.click('button[aria-label="Game settings"]');
await host.waitForSelector('.game-sheet');
const groups = await host.evaluate(() => [...document.querySelectorAll('.game-sheet [role="group"]')]
  .map((node) => node.getAttribute('aria-label')));
check(groups.includes('Rows'), 'the sheet offers the rows');
check(!groups.includes('Difficulty'), 'there are no levels');
check(!groups.includes('Columns'), 'the columns are not a choice');
check(!groups.includes('Start with'), 'a board always starts full');
const rowsEnabled = await host.evaluate(() => {
  const box = [...document.querySelectorAll('.game-sheet [role="group"]')]
    .find((node) => node.getAttribute('aria-label') === 'Rows');
  return [...(box?.querySelectorAll('button') ?? [])].map((node) => ({
    label: node.textContent.trim(), disabled: node.disabled,
  }));
});
check(rowsEnabled.map((b) => b.label).join(',') === '12,14,16,18',
  'the rows on offer are 12, 14, 16 and 18');
check(rowsEnabled.every((b) => !b.disabled), 'and they can be chosen before a game');

await choose(host, 'Rows', 12);
await host.evaluate(() => [...document.querySelectorAll('.game-sheet button')]
  .find((node) => (node.textContent ?? '').trim() === 'Done')?.click());
await wait(250);

await host.evaluate(() => [...document.querySelectorAll('.lobby-card')]
  .find((node) => /play on this device/i.test(node.textContent ?? ''))?.click());
await host.waitForSelector('.ten__board');
await wait(400);
let grid = await cells(host);
check(grid.length === 108, `twelve rows of nine is 108 cells (${grid.length})`);
check(Math.max(...grid.map((cell) => cell.column)) === 8, 'nine columns');
check(Math.max(...grid.map((cell) => cell.row)) === 11, 'twelve rows');

// In a game the rows are shown and inert.
await host.click('button[aria-label="Game settings"]');
await host.waitForSelector('.game-sheet');
const locked = await host.evaluate(() => {
  const box = [...document.querySelectorAll('.game-sheet [role="group"]')]
    .find((node) => node.getAttribute('aria-label') === 'Rows');
  return {
    disabled: [...(box?.querySelectorAll('button') ?? [])].every((node) => node.disabled),
    on: [...(box?.querySelectorAll('button') ?? [])]
      .find((node) => node.getAttribute('aria-pressed') === 'true')?.textContent.trim(),
  };
});
check(locked.disabled, 'in a game the rows are locked');
check(locked.on === '12', 'and the sheet shows the rows in play');
await host.evaluate(() => [...document.querySelectorAll('.game-sheet button')]
  .find((node) => (node.textContent ?? '').trim() === 'Done')?.click());
await wait(200);
await host.screenshot({ path: '/tmp/ten_web_rows.png' });

// ── two digits that do not pair: no message, and the highlight moves ───────
const mismatch = await host.$$eval('.ten__cell', (nodes) => {
  const read = (node) => {
    const match = (node.getAttribute('aria-label') ?? '').match(/Column (\d+) row (\d+): (\d+)/);
    return match ? { column: Number(match[1]), row: Number(match[2]), value: Number(match[3]) } : null;
  };
  const all = nodes.map(read).filter(Boolean);
  for (const a of all) {
    for (const b of all) {
      if (a === b) continue;
      if (a.value !== b.value && a.value + b.value !== 10) return [a, b];
    }
  }
  return null;
});
check(Boolean(mismatch), 'there are two digits that do not pair');
if (mismatch) {
  const selector = (cell) => `.ten__cell[aria-label="Column ${cell.column} row ${cell.row}: ${cell.value}"]`;
  const before = (await cells(host)).length;
  await host.click(selector(mismatch[0]));
  await host.click(selector(mismatch[1]));
  await wait(300);
  const selected = await host.evaluate((cell) => {
    const node = document.querySelector(
      `.ten__cell[aria-label="Column ${cell.column} row ${cell.row}: ${cell.value}"]`,
    );
    return node?.getAttribute('data-selected') === 'true';
  }, mismatch[1]);
  const message = await host.$('.game-message');
  check(!message, 'a pair that does not match says nothing');
  check(selected, 'and the highlight moves to the number just picked');
  check((await cells(host)).length === before, 'with every digit still on the board');
}

// ── a room plays the host's rows, though the guest's own setting is 18 ──────
await host.goto(`${origin}/ten`, { waitUntil: 'networkidle2' });
await wait(400);
await host.click('button[aria-label="Game settings"]');
await host.waitForSelector('.game-sheet');
await choose(host, 'Rows', 14);
await host.evaluate(() => [...document.querySelectorAll('.game-sheet button')]
  .find((node) => (node.textContent ?? '').trim() === 'Done')?.click());
await wait(200);
await host.evaluate(() => [...document.querySelectorAll('.lobby-card')]
  .find((node) => /play with others/i.test(node.textContent ?? ''))?.click());
await nameIfAsked(host, 'Host');
await host.waitForSelector('.ten__waiting', { timeout: 15000 });
const room = await host.evaluate(() => new URL(location.href).searchParams.get('game'));
check(Boolean(room), 'the host made a room');

await guest.goto(`${origin}/ten?game=${room}`, { waitUntil: 'networkidle2' });
await nameIfAsked(guest, 'Guest');
await wait(800);
await host.evaluate(() => [...document.querySelectorAll('button')]
  .find((node) => (node.textContent ?? '').trim() === 'Start')?.click());
await wait(1400);

const hostCells = await cells(host);
const guestCells = await cells(guest);
check(hostCells.length === 126, `the room is nine by fourteen (${hostCells.length})`);
check(guestCells.length === 126,
  `and the guest, whose own setting is eighteen rows, gets fourteen (${guestCells.length})`);
check(JSON.stringify(hostCells) === JSON.stringify(guestCells), 'both deals are the same board');

await browser.close();
console.log(failures.length ? `\n${failures.length} CHECK(S) FAILED` : '\nAll row checks passed.');
process.exit(failures.length ? 1 : 0);
