#!/usr/bin/env node
/**
 * Screenshots the landing page for review.
 *
 * Uses the Chrome already on this machine rather than downloading one, so it
 * needs puppeteer-core (installed under .build). Serves nothing itself — start
 * a static server on the page first, e.g.
 *
 *   python3 -m http.server 8099 --bind 127.0.0.1    # from site/
 *   node Tools/shoot_site.mjs http://127.0.0.1:8099 .build/site-shots
 *
 * Captures each section at a realistic viewport in both colour schemes, which
 * is the only way to catch white-on-white text or a section that never reveals.
 */
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import puppeteer from "../.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const url = process.argv[2] ?? "http://127.0.0.1:8099";
const outDir = resolve(process.argv[3] ?? ".build/site-shots");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

mkdirSync(outDir, { recursive: true });

const SECTIONS = ["#play", "#vibe-five", "#vibe-words", "#vibe-sudoku", "#vibe-trio", "#people"];
const SCHEMES = ["light", "dark"];

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: "new",
  args: ["--hide-scrollbars", "--disable-gpu"],
});

try {
  for (const scheme of SCHEMES) {
    const page = await browser.newPage();
    await page.setViewport({ width: 1440, height: 900, deviceScaleFactor: 1 });
    await page.emulateMediaFeatures([
      { name: "prefers-color-scheme", value: scheme },
    ]);

    await page.goto(url, { waitUntil: "networkidle0" });

    // Hero, before any scrolling.
    await page.screenshot({ path: `${outDir}/hero-${scheme}.png` });

    for (const selector of SECTIONS) {
      // Scroll, then let the reveal finish before capturing.
      await page.evaluate((sel) => {
        document.querySelector(sel)?.scrollIntoView({ behavior: "instant", block: "start" });
      }, selector);

      await new Promise((r) => setTimeout(r, 1400));

      const name = selector.replace("#", "");
      await page.screenshot({ path: `${outDir}/${name}-${scheme}.png` });
      console.log(`  ${name}-${scheme}.png`);
    }

    await page.close();
  }
} finally {
  await browser.close();
}

console.log(`\nWritten to ${outDir}`);
