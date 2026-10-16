#!/usr/bin/env node
/**
 * Opens the support panel on every screen and checks it is actually on screen.
 *
 * This exists because the panel was broken on Word Vibe for a day and every
 * check passed. The heart opened it, the panel was in the DOM, the form was
 * enabled — and it laid itself out inside a 40x40 corner box off the side of the
 * screen, because `position: fixed` resolves against the nearest ancestor with a
 * transform and that screen's header corner has a `translateY`. From the outside
 * it looked exactly like a button that does nothing.
 *
 * So this measures rather than counts: the panel has to cover a sensible part of
 * the window, sit inside it, and be the thing a tap at its centre lands on.
 *
 *   node Tools/panel_e2e.mjs                                   # the deployed app
 *   node Tools/panel_e2e.mjs http://127.0.0.1:4173              # a local preview
 *
 * Use it against a local build before deploying — `npm run build && npm run
 * preview` in `web/` — because a broken panel is invisible from the deploy log.
 */
import puppeteer from "../.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const site = (process.argv[2] ?? "https://play.vibegames.party").replace(/\/$/, "");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

/** Every screen that carries the heart. */
const ROUTES = ["/", "/five", "/words", "/sudoku", "/trio", "/blurt"];

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
  for (const route of ROUTES) {
    const page = await browser.newPage();
    // A phone, because that is what the panel is designed for and where the
    // sliver hid.
    await page.setViewport({ width: 414, height: 900 });
    await page.goto(`${site}${route}`, { waitUntil: "networkidle0" });
    await new Promise((done) => setTimeout(done, 700));

    console.log(`\n${route}`);

    const heart = await page.evaluate(() => {
      const button = document.querySelector(".hub__heart");
      if (!button) return { found: false };
      const box = button.getBoundingClientRect();
      const at = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
      return { found: true, reachable: !!(at && (at === button || button.contains(at))) };
    });
    check(heart.found, "the screen carries the heart");
    if (!heart.found) {
      await page.close();
      continue;
    }
    check(heart.reachable, "and a tap in the middle of it lands on the button");

    await page.click(".hub__heart").catch(() => {});
    await new Promise((done) => setTimeout(done, 500));

    const panel = await page.evaluate(() => {
      const el = document.querySelector(".support-panel");
      if (!el) return { open: false };
      const box = el.getBoundingClientRect();
      const window_ = { w: window.innerWidth, h: window.innerHeight };
      const inside = box.left >= -1 && box.top >= -1 &&
        box.right <= window_.w + 1 && box.bottom <= window_.h + 1;
      const point = [box.left + box.width / 2, Math.min(box.top + 30, box.bottom - 10)];
      const at = document.elementFromPoint(point[0], point[1]);
      return {
        open: true,
        inside,
        // A third of the width is a floor no real phone layout falls below; the
        // broken one was half that.
        wideEnough: box.width >= window_.w * 0.6,
        onTop: !!(at && (at === el || el.contains(at))),
        box: `${Math.round(box.left)},${Math.round(box.top)} ${Math.round(box.width)}x${Math.round(box.height)}`,
        sendVisible: !!document.querySelector(".feedback__send"),
      };
    });

    check(panel.open, "the heart opens the panel");
    if (panel.open) {
      check(panel.inside, `and it is inside the window (${panel.box})`);
      check(panel.wideEnough, `and a sensible width (${panel.box})`);
      check(panel.onTop, "and it is what a tap on it lands on");
      check(panel.sendVisible, "and the feedback box is in it");
    }

    await page.close();
  }
} finally {
  await browser.close();
}

console.log(
  failures.length
    ? `\n${failures.length} thing(s) wrong:\n  ${failures.join("\n  ")}\n`
    : `\nThe support panel opens on screen on all ${ROUTES.length} screens.\n`,
);
process.exit(failures.length ? 1 : 0);
