#!/usr/bin/env node
/**
 * Renders the link preview for both sites: the card that appears when a link is
 * pasted into a message, a post or a search result.
 *
 * Both hosts point at the same file, because there is only one thing to show
 * someone: the games, a screen, and the name. It is drawn here rather than
 * exported from a design tool so that it can be regenerated when the copy or the
 * colours change, and so the text on it is the text in the repository.
 *
 *   node Tools/make_og_image.mjs
 *
 * Writes `site/assets/og/vibe-games.jpg` (1200x630, the size both Open Graph and
 * Twitter ask for) and `site/assets/og/ways-to-help.jpg` for the one other page
 * worth unfurling on its own.
 *
 * Chrome is the one already on this machine; puppeteer-core is under .build.
 */
import { mkdirSync, readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "../.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = resolve(ROOT, "site/assets/og");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

mkdirSync(OUT, { recursive: true });

/**
 * A screenshot as a data URI.
 *
 * `setContent` gives the page an `about:blank` origin, and Chrome refuses to
 * load a `file://` subresource from one — the picture comes out as a broken
 * frame, which is how the first version of this card was made.
 */
function screenshotDataURI(relative) {
  const bytes = readFileSync(resolve(ROOT, "site", relative));
  return `data:image/jpeg;base64,${bytes.toString("base64")}`;
}

/** The games, in the order the landing page presents them. */
const GAMES = [
  ["Vibe Five", "Name things before the buzzer", "#ff4757"],
  ["Word Vibe", "Guess the five-letter word", "#21b8a8"],
  ["Number Vibe", "Fill the grid, solo or raced", "#8549f0"],
  ["Vibe Pairings", "Find three cards that match", "#f7b929"],
  ["Similar Vibe", "Describe it, don't say it", "#f54d6b"],
];

/** The page, as data: one card per picture the card shows. */
const CARDS = {
  "vibe-games": {
    eyebrow: "Do you feel the vibe?",
    title: "Vibe Games",
    lede: "Quick party games, for any device you have to hand.",
    games: GAMES,
    shot: "assets/screens/hub-light.jpg",
  },
  "ways-to-help": {
    eyebrow: "Ways to help",
    title: "Made with love",
    lede: "Why the games exist, and the three things that help.",
    games: GAMES,
    shot: null,
  },
};

const html = (card) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<style>
  @font-face { font-family: system; src: local("SF Pro Rounded"); }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    width: 1200px;
    height: 630px;
    display: flex;
    align-items: center;
    gap: 48px;
    padding: 64px 72px;
    overflow: hidden;
    color: #fff;
    background: #0b0a17;
    font-family: ui-rounded, "SF Pro Rounded", -apple-system, "Helvetica Neue", sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  /* The landing page's own bloom, so a preview looks like the page it opens. */
  .glow {
    position: absolute;
    inset: -20% -10% auto -10%;
    height: 90%;
    background:
      radial-gradient(40% 60% at 22% 40%, rgb(255 71 87 / 0.55), transparent 70%),
      radial-gradient(40% 60% at 62% 30%, rgb(133 73 240 / 0.45), transparent 70%),
      radial-gradient(40% 60% at 88% 55%, rgb(33 184 168 / 0.4), transparent 70%);
    filter: blur(20px);
  }
  .copy { position: relative; flex: 1; min-width: 0; }
  .eyebrow {
    font-size: 21px;
    font-weight: 700;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: rgb(255 255 255 / 0.42);
    margin: 0 0 18px;
  }
  h1 {
    margin: 0 0 18px;
    font-size: 92px;
    line-height: 1.02;
    font-weight: 800;
    letter-spacing: -0.02em;
    background: linear-gradient(100deg, #ff4757, #ff8c33 30%, #4585f5 55%, #8549f0 78%, #85d647);
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }
  .lede {
    margin: 0 0 30px;
    font-size: 30px;
    line-height: 1.35;
    color: rgb(255 255 255 / 0.68);
    max-width: 30ch;
  }
  ul { margin: 0; padding: 0; list-style: none; display: flex; flex-wrap: wrap; gap: 10px 12px; }
  li {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 18px 10px 14px;
    border: 1px solid rgb(255 255 255 / 0.13);
    border-radius: 999px;
    background: rgb(255 255 255 / 0.05);
    font-size: 21px;
    font-weight: 700;
  }
  li i { width: 12px; height: 12px; border-radius: 999px; background: currentColor; }
  .shot {
    position: relative;
    flex: none;
    /* By height, not width: the screenshot is a whole phone screen (414x900),
       so a width would decide its own height and push the card's edges off. */
    height: 502px;
    width: auto;
    border-radius: 30px;
    border: 1px solid rgb(255 255 255 / 0.13);
    box-shadow: 0 24px 70px rgb(0 0 0 / 0.55);
  }
  .footer {
    position: absolute;
    left: 72px;
    bottom: 34px;
    font-size: 20px;
    font-weight: 700;
    color: rgb(255 255 255 / 0.42);
    letter-spacing: 0.02em;
  }
</style>
</head>
<body>
  <div class="glow"></div>
  <div class="copy">
    <p class="eyebrow">${card.eyebrow}</p>
    <h1>${card.title}</h1>
    <p class="lede">${card.lede}</p>
    <ul>
      ${card.games.map(([name, , colour]) => `<li style="color:${colour}"><i></i><span style="color:#fff">${name}</span></li>`).join("")}
    </ul>
  </div>
  ${card.shot ? `<img class="shot" src="${screenshotDataURI(card.shot)}" alt="" />` : ""}
  <p class="footer">vibegames.party</p>
</body>
</html>`;

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: "new",
  args: ["--hide-scrollbars", "--disable-gpu", "--force-device-scale-factor=1"],
});

try {
  for (const [name, card] of Object.entries(CARDS)) {
    const page = await browser.newPage();
    await page.setViewport({ width: 1200, height: 630, deviceScaleFactor: 1 });
    await page.setContent(html(card), { waitUntil: "networkidle0" });
    // JPEG rather than PNG: the card is a photograph of a dark screen with a
    // photo in it, and 1200x630 of that is a quarter of a megabyte as PNG.
    await page.screenshot({ path: `${OUT}/${name}.jpg`, type: "jpeg", quality: 88 });
    await page.close();
    console.log(`  site/assets/og/${name}.jpg`);
  }
} finally {
  await browser.close();
}
