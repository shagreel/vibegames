#!/usr/bin/env node
/**
 * Plays with the ways-to-help page the way a person would, and checks that the
 * feedback box really reaches the inbox.
 *
 * This is the only check that proves the form works: the page has no build step
 * and no test framework, and a form that only ever posts to a stub proves
 * nothing. It sends a real note to the live database, exactly as the browser
 * version's own form does.
 *
 * A client cannot delete what it wrote — the rules refuse a delete — so the note
 * is marked `[test]` and `Tools/feedback_to_issues.py` leaves marked notes alone.
 * That marker is typed by this script rather than remembered by a person, which
 * is the point: the first hand-written run of this check sent an unmarked note,
 * and an unmarked note becomes an issue on the repository.
 *
 * Defaults to the deployed page, which is the one the app opens:
 *
 *   node Tools/ways_to_help_e2e.mjs
 *   node Tools/ways_to_help_e2e.mjs http://127.0.0.1:8099/ways-to-help.html
 *
 * Exits non-zero on the first thing that is wrong.
 */
import puppeteer from "../.build/qrtool/node_modules/puppeteer-core/lib/puppeteer/puppeteer-core.js";

const url = process.argv[2] ?? "https://vibegames.party/ways-to-help";
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const DATABASE = "https://vibe-words-party-default-rtdb.firebaseio.com";
const TEST_MARKER = "[test]";
const NOTE = `${TEST_MARKER} The ways-to-help page check sends this. Ignore it.`;

const failures = [];
const check = (ok, what) => {
  console.log(`${ok ? "  ok  " : " FAIL "} ${what}`);
  if (!ok) failures.push(what);
};

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: "new",
  args: ["--hide-scrollbars", "--disable-gpu"],
});

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 414, height: 900, deviceScaleFactor: 1 });

  const noise = [];
  page.on("pageerror", (error) => noise.push(`page error: ${error.message}`));
  page.on("console", (message) => {
    // Resource failures are reported below by URL, which is where the missing
    // favicon every page here 404s on can be allowed for; Chrome's own line for
    // one does not name the file it could not fetch.
    if (message.type() === "error" && !message.text().includes("Failed to load resource")) {
      noise.push(`console: ${message.text()}`);
    }
  });
  page.on("response", (response) => {
    if (response.status() >= 400 && !response.url().endsWith("/favicon.ico")) {
      noise.push(`${response.status()} ${response.url()}`);
    }
  });

  console.log(`\nThe page — ${url}`);
  await page.goto(url, { waitUntil: "networkidle0" });

  const heading = await page.$eval("h1", (el) => el.textContent.trim());
  check(heading === "Made with love", `the title reads "Made with love" (got "${heading}")`);

  const steps = await page.$$eval(".help__way h3", (els) =>
    els.map((el) => el.textContent.replace(/^\s*\d\s*/, "").trim().toLowerCase()),
  );
  check(steps.length === 3, `there are three ways to help (got ${steps.length})`);
  check(
    steps[0]?.includes("feedback") &&
      steps[1]?.includes("share") &&
      steps[2]?.includes("treat"),
    `and they are the three asked for (${steps.join(" | ")})`,
  );

  // The button greys out while there is nothing to send, like the browser
  // version's form: the same four-character floor, from the same rules.
  const sendDisabled = () => page.$eval("[data-feedback-send]", (el) => el.disabled);
  check(await sendDisabled(), "Send starts disabled on an empty box");
  await page.type("[data-feedback-text]", "abc");
  check(await sendDisabled(), "and stays disabled at three characters");

  console.log("\nThe form");
  await page.$eval("[data-feedback-text]", (el) => {
    el.value = "";
  });
  await page.type("[data-feedback-text]", NOTE);
  check(!(await sendDisabled()), "four characters is enough to send");

  const posted = [];
  page.on("request", (request) => {
    if (request.method() === "POST" && request.url().includes("/feedback.json")) {
      posted.push(JSON.parse(request.postData() ?? "null"));
    }
  });

  await page.click("[data-feedback-send]");
  await page.waitForFunction(() => !document.querySelector("[data-feedback-sent]").hidden, {
    timeout: 30_000,
  });

  const body = posted[posted.length - 1] ?? null;
  check(body !== null, "the note went to the database");
  check(body?.source === "web", `marked as coming from a browser (source: ${body?.source})`);
  check(typeof body?.createdAt === "number", "and stamped with the time");
  check(body?.text === NOTE, "and carries what was typed");

  const thanks = await page.$eval("[data-feedback-sent]", (el) =>
    el.textContent.replace(/\s+/g, " ").trim(),
  );
  check(thanks.startsWith("Thank you"), `the page says thank you (got "${thanks}")`);
  check(
    await page.$eval("[data-feedback-form]", (el) => el.hidden),
    "and the form gets out of the way",
  );

  // Read it back. A 200 from the POST is the database saying it has it; this is
  // the same thing asked a second way, through the read the rules do allow.
  const inbox = await (await fetch(`${DATABASE}/feedback.json`)).json();
  check(
    Object.values(inbox).some((entry) => entry.text === NOTE),
    "and it is in the inbox when the inbox is read",
  );

  console.log("\nThe buttons");
  await page.setViewport({ width: 1280, height: 1000, deviceScaleFactor: 1 });
  await page.reload({ waitUntil: "networkidle0" });

  // The Venmo link is left unfollowed on purpose — following it would take
  // Chrome to venmo.com — so this counts the tap it reports instead. The share
  // sheet is stubbed for the same reason: it would take over the machine.
  await page.evaluate(() => {
    window.__events = [];
    window.gtag = (...args) => window.__events.push(args);
    Object.defineProperty(navigator, "share", {
      value: () => Promise.resolve(),
      configurable: true,
    });
    document.querySelectorAll("a").forEach((anchor) =>
      anchor.addEventListener("click", (event) => event.preventDefault()),
    );
  });

  await page.click("[data-donation]");
  await page.click("[data-copy-venmo]");
  await page.click("[data-share]");
  await new Promise((done) => setTimeout(done, 300));

  const events = await page.evaluate(() => window.__events);
  const named = (name) => events.some(([kind, event]) => kind === "event" && event === name);

  const copy = await page.$eval("[data-copy-venmo]", (el) => el.textContent.trim());
  check(copy.includes("@chill-gelato"), `the handle copies (the button reads "${copy}")`);
  check(named("donation_tap"), "the Venmo tap is counted, under the browser version's name");
  check(named("share"), "and so is the share");

  console.log("\nThe caching");
  // The markup and the stylesheet have to come from the same deploy. Cached
  // apart, a visitor can hold one that is an hour older than the other — and a
  // class named in one and not the other is a page with no styling at all, which
  // is exactly what shipped once: the page was rebuilt, the sheet kept its URL,
  // and the two met. `no-cache` means "check before use", so this is cheap.
  const caching = await page.evaluate(async () => {
    const sheet = document.querySelector('link[rel="stylesheet"]').href;
    const [page, css] = await Promise.all([fetch(location.href), fetch(sheet)]);
    return {
      page: page.headers.get("cache-control"),
      sheet: css.headers.get("cache-control"),
    };
  });
  const revalidates = (value) => (value ?? "").includes("no-cache");
  check(revalidates(caching.page), `the page revalidates (${caching.page})`);
  check(revalidates(caching.sheet), `and so does the stylesheet (${caching.sheet})`);

  check(noise.length === 0, `nothing failed to load (${noise.join("; ") || "clean"})`);
} finally {
  await browser.close();
}

console.log(
  failures.length
    ? `\n${failures.length} thing(s) wrong:\n  ${failures.join("\n  ")}\n`
    : "\nThe ways-to-help page works.\n",
);
process.exit(failures.length ? 1 : 0);
