#!/usr/bin/env node
/**
 * Generates the QR codes for the landing page.
 *
 * These are REAL, scannable codes — not decorative patterns. The browser one is
 * live; the two store ones are placeholders, because the app has no store
 * listing yet, so scanning those lands on a "not found" page. Replace those two
 * targets when the listings exist, re-run, and the page needs no other change.
 *
 *   node Tools/make_qr.mjs
 *
 * Outputs SVG, so the codes stay crisp at any size and cost almost nothing.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import QRCode from "../.build/qrtool/node_modules/qrcode/lib/index.js";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = resolve(root, "site/assets/qr");

// TODO: point these at the real store listings once they exist.
const TARGETS = [
  { file: "browser.svg", label: "Play in your browser", url: "https://play.vibegames.party" },
  { file: "appstore.svg", label: "App Store", url: "https://apps.apple.com/app/id0000000000" },
  { file: "playstore.svg", label: "Google Play", url: "https://play.google.com/store/apps/details?id=party.vibegames" },
];

mkdirSync(outDir, { recursive: true });

for (const { file, label, url } of TARGETS) {
  const svg = await QRCode.toString(url, {
    type: "svg",
    margin: 1,
    width: 480,
    errorCorrectionLevel: "M",
    color: { dark: "#0b0a17", light: "#ffffff" },
  });

  // The browser code is real; the store ones are not, and say so in the file
  // rather than only in the page.
  const placeholder = url.includes("id0000000000") || url.includes("play.google.com");
  const stamped = svg.replace(
    /<\/svg>/,
    `  <desc>${label} QR code${placeholder ? " (placeholder" + ": " + url + ")" : ": " + url}</desc>\n</svg>`
  );

  writeFileSync(resolve(outDir, file), stamped);
  console.log(`  ${file.padEnd(16)} -> ${url}`);
}

console.log("\nReminder: the two store codes encode placeholder URLs and will not resolve yet.");
