#!/usr/bin/env node
/**
 * Opens the settings sheet on every screen and checks what is in it.
 *
 * The agreement is the feature: whatever the game, the two things that belong to
 * the player — the name and the light/dark choice — are the same sheet in the
 * same place, and the game's own settings are underneath them. A game that grows
 * its own settings screen, or loses the shared half of one, is what this would
 * notice.
 *
 *   node Tools/settings_e2e.mjs                                 # the deployed app
 *   node Tools/settings_e2e.mjs http://localhost:4173            # a local preview
 *
 * Use it against a local build before deploying — `npm run build && npm run
 * preview` in `web/`.
 */
import puppeteer from "../.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const site = (process.argv[2] ?? "https://play.vibegames.party").replace(/\/$/, "");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

/** Every screen that carries the button, and the headings only it should have. */
const SCREENS = [
  { route: "/", prefix: "hub", own: [] },
  { route: "/five", prefix: "five", own: ["Category packs"] },
  { route: "/words", prefix: "words", own: [] },
  { route: "/sudoku", prefix: "sudoku", own: ["Notes per square"] },
  { route: "/trio", prefix: "trio", own: [] },
  { route: "/blurt", prefix: "blurt", own: ["Turn length", "Words"] },
];

const failures = [];
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures.push(what);
};

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: "new",
  args: ["--hide-scrollbars", "--disable-gpu", "--force-device-scale-factor=1"],
});

try {
  for (const screen of SCREENS) {
    const page = await browser.newPage();
    await page.setViewport({ width: 414, height: 900 });
    // One browser profile is shared by the whole run, so each screen would open
    // with the name the last one typed already in the field — and a click in the
    // middle of a filled field puts the caret in the middle of the old name,
    // which is what a person would get too. The name is cleared per document to
    // start from the state a new player is in.
    await page.evaluateOnNewDocument(() => {
      try {
        localStorage.removeItem("vibegames.playerName");
      } catch (error) {
        /* no storage: the field starts empty anyway */
      }
    });
    await page.goto(`${site}${screen.route}`, { waitUntil: "networkidle0" });
    await new Promise((done) => setTimeout(done, 700));

    console.log(`\n${screen.route}`);

    const button = await page.evaluate((prefix) => {
      const found = document.querySelector(`.${prefix}__settings-button`);
      if (!found) return { found: false };
      const box = found.getBoundingClientRect();
      const at = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
      return {
        found: true,
        inWindow: box.top >= 0 && box.left >= 0 && box.bottom <= window.innerHeight,
        reachable: !!(at && (at === found || found.contains(at))),
      };
    }, screen.prefix);

    check(button.found, "the screen carries the settings button");
    if (!button.found) {
      await page.close();
      continue;
    }
    check(button.inWindow, "and it is inside the window");
    check(button.reachable, "and a tap in the middle of it lands on the button");

    await page.click(`.${screen.prefix}__settings-button`);
    await new Promise((done) => setTimeout(done, 400));

    const sheet = await page.evaluate(() => {
      const panel = document.querySelector(".game-sheet");
      if (!panel) return null;
      const box = panel.getBoundingClientRect();
      return {
        headings: [...panel.querySelectorAll("h3")].map((h) => h.textContent.trim()),
        name: !!panel.querySelector(".game-sheet__field"),
        appearances: [...panel.querySelectorAll(".game-sheet__choice")].map((b) => b.textContent.trim()),
        done: !!panel.querySelector(".game-sheet__done"),
        inside: box.top >= 0 && box.left >= 0 && box.bottom <= window.innerHeight + 1,
      };
    });

    check(!!sheet, "the sheet opens");
    if (!sheet) {
      await page.close();
      continue;
    }
    check(sheet.inside, "and it fits inside the window");
    check(sheet.name, "it asks for the player's name");
    check(sheet.appearances.join(",") === "System,Light,Dark",
          `it offers the three appearances (got ${sheet.appearances.join(",")})`);
    check(sheet.done, "and it has a way out");
    for (const heading of ["Your name", "Appearance", ...screen.own]) {
      check(sheet.headings.includes(heading), `it has the "${heading}" section`);
    }
    if (screen.own.length === 0) {
      check(sheet.headings.length === 2, "and nothing that is not the game's or the player's");
    }

    // The name is written as it is typed, not on the way out.
    await page.click(".game-sheet__field");
    await page.type(".game-sheet__field", "E2E Player");
    // React handles the input event on its own turn, so the store is a moment
    // behind the keystroke.
    await new Promise((done) => setTimeout(done, 250));
    const typed = await page.evaluate(() => ({
      field: document.querySelector(".game-sheet__field").value,
      stored: localStorage.getItem("vibegames.playerName"),
    }));
    check(typed.field === "E2E Player", `the field keeps what was typed (got ${typed.field})`);
    check(typed.stored === "E2E Player", `typing a name stores it straight away (got ${typed.stored})`);

    // The appearance, and that it survives a reload — `index.html` sets the
    // attribute before the bundle runs, so a reload must not flash back.
    await page.evaluate(() => {
      [...document.querySelectorAll(".game-sheet__choice")].find((b) => b.textContent.trim() === "Dark").click();
    });
    await new Promise((done) => setTimeout(done, 250));
    const dark = await page.evaluate(() => ({
      applied: document.documentElement.dataset.theme,
      stored: localStorage.getItem("vibegames.theme"),
    }));
    check(dark.applied === "dark" && dark.stored === "dark", "choosing Dark applies and stores it");

    await page.reload({ waitUntil: "networkidle0" });
    await new Promise((done) => setTimeout(done, 500));
    const afterReload = await page.evaluate(() => document.documentElement.dataset.theme);
    check(afterReload === "dark", "and it is still dark after a reload");

    // Back to the default, so the run leaves nothing behind in the page it used.
    await page.evaluate(() => localStorage.setItem("vibegames.theme", "system"));
    await page.close();
  }
} finally {
  await browser.close();
}

console.log();
if (failures.length) {
  console.log(`${failures.length} check(s) failed:`);
  for (const failure of failures) console.log(`  - ${failure}`);
  process.exit(1);
}
console.log(`The settings sheet opens on screen, with the same two settings, on all ${SCREENS.length} screens.`);
