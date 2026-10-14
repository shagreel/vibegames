# Vibe Games — landing page

A static marketing page for the app. Plain HTML, CSS and one small script: no
build step, no dependencies, nothing to install.

```
site/
  index.html
  ways-to-help.html   what the app's "Ways to help" link opens
  styles.css
  main.js
  analytics.js   one page view; the id is filled in, so this is live
  assets/
    qr/        appstore.svg, playstore.svg   (real QR codes, placeholder URLs)
    screens/   app screenshots, light + dark
    people/    illustrations standing in for photos
```

## The ways-to-help page

`ways-to-help.html` is `/ways-to-help`, and the app opens it — from the sparkles
row in the support panel and from the button at the bottom of the hub. It is the
browser version's "Made with love" panel, in the open, as a list:

```
Made with love                        the title, and why the games exist
  How you can help the project
    1  Give feedback or suggest a game   the form
    2  Share it with others              the share sheet, or the link
    3  Buy us a treat                    Venmo, and copying the handle
```

It exists because of one rule: **an app must not point at a way to pay**, and
`support.waysToHelpURL` is the app's only route to the Venmo link. So the page
has to stay reachable, and it has to say the same things the panel says — if you
change the wording in one, change it in the other.

The words are the browser version's, from `web/src/hub/Support.tsx`, and the
feedback box is that panel's form written out in plain HTML: the same label, the
same placeholder, the same "no account, no email address" note, the same
four-character floor before Send lights up, and the same thank-you. It posts
`{text, source: "web", createdAt}` to the same write-only node in the Realtime
Database, with `fetch` rather than the Firebase SDK — this page has no build step
and no dependencies, and one POST is not worth a hundred kilobytes of client.

`Tools/check_app_no_payments.py` is the guard on the app side: it scans
`Sources/` and fails the build if a Venmo handle, a "Buy us a treat" or a
donation link reappears in code or copy. Its comments are exempt, which is how
`SupportView.swift` gets to explain what it is deliberately not doing.

**`node Tools/ways_to_help_e2e.mjs`** is the check that the form works, since
nothing else here can be: it opens the page in Chrome, sends a real note, and
reads it back out of the database. It also reads the `Cache-Control` of the page
and of the stylesheet, because the two being cached apart is the failure below
and nothing else would notice it. The note is marked `[test]`, which is what
`Tools/feedback_to_issues.py` ignores — a client cannot delete what it wrote, so
the marker is what keeps a check from becoming an issue. **An unmarked note
becomes an issue on the repository**, which is how the first hand-written run of
this check very nearly ended up.

The page is served at `/ways-to-help` rather than `/ways-to-help.html` because
`firebase.json` sets `cleanUrls`, so the address in the app carries no extension
for anyone to mistype and none to leak if the page is ever renamed.

## What is cached, and why the pages are not

`firebase.json` sends `no-cache` for everything, and a week for `assets/**`
(last rule wins). The screenshots under `assets/` are versioned with `?v=`, so
they can be held for as long as the browser likes; the markup, the stylesheet and
the two scripts revalidate every time.

That is not caution, it is a bug that shipped. The ways-to-help page was rebuilt
with new class names — `.help__way`, `.help__button` — while the stylesheet kept
its URL and its hour of cache. A visitor whose browser still had the old
`styles.css` and fetched the new markup got **a page with no styling at all**:
nothing in the document matched anything in the sheet, so the cards, the buttons
and the feedback form all came out as browser defaults.

Two files that have to agree cannot be cached apart. `no-cache` means "revalidate
before use", not "do not store", so an unchanged file costs a 304 and nothing
else. The images keep their week because nothing about them has to agree with
anything — and when one is regenerated, its `?v=` is bumped, which is the only
reason that number exists.

## Previewing it

It is static, so any server will do — the one thing you cannot do is open
`index.html` off the filesystem, because the QR and screenshot paths are
root-relative:

```sh
cd site
python3 -m http.server 8099 --bind 127.0.0.1
# then open http://127.0.0.1:8099
```

## The QR codes

`assets/qr/*.svg` are **genuine, scannable QR codes** — not decorative patterns —
but they encode placeholder store URLs, because there is no listing yet. Point a
camera at one today and it will 404.

To fix them, edit the two URLs at the top of `Tools/make_qr.mjs` and re-run:

```sh
node Tools/make_qr.mjs
```

The page needs no change; it just loads whatever is in `assets/qr/`.

## Swapping in real photos

The "Better with a crowd" strip uses generated geometric illustrations, because
this was built without access to real photographs. They are meant to go.

Drop photos into `site/assets/people/` using these exact names and the page picks
them up automatically:

| Replace | With |
| --- | --- |
| `playing-together.svg` | a group playing together |
| `vibe-five-crowd.svg` | people mid-round of Vibe Five |
| `vibe-sudoku-crowd.svg` | people solving Sudoku together |
| `vibe-trio-crowd.svg` | people hunting trios together |

If you use `.jpg` instead of `.svg`, update the `src` attributes in the
`people__strip` section of `index.html` — removed for now, but the images
and their styling are still there to restore. Landscape crops around 900×640 look
best.

To regenerate the illustrations after changing the palettes:

```sh
python3 Tools/make_illustrations.py
```

## Screenshots

Every app screenshot ships in both appearances. The markup uses `<picture>` so
the browser loads the one matching the visitor's system setting:

```html
<picture>
  <source srcset="assets/screens/x-dark.jpg" media="(prefers-color-scheme: dark)" />
  <img src="assets/screens/x-light.jpg" alt="…" />
</picture>
```

They were captured from the iOS simulator by the UI test suite, which attaches a
screenshot at each step. The appearance suites (`AppearanceUITests`, and the
`testLightAppearance` / `testDarkAppearance` pair in `VibeTrioUITests`) pass
`-vibegames.appearance light|dark` as a launch argument, so one run covers both:

```sh
xcodebuild -project VibeGames.xcodeproj -scheme VibeGames \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VibeGamesUITests/AppearanceUITests \
  -only-testing:VibeGamesUITests/VibeTrioUITests/testLightAppearance \
  -only-testing:VibeGamesUITests/VibeTrioUITests/testDarkAppearance \
  -resultBundlePath .build/TestResults.xcresult test
xcrun xcresulttool export attachments --path .build/TestResults.xcresult --output-path .build/attachments
```

The attachment names are listed in the exported `manifest.json`, and each one has
to be resized into `site/assets/screens/` — the simulator shoots at 1206×2622 and
the page expects 414×900:

```sh
sips -z 900 414 --setProperty format jpeg --setProperty formatOptions 84 in.png --out out.jpg
```

**Bump the `?v=` in `index.html` when you regenerate them.** The screenshots keep
their file names, and Hosting serves them with a week's `max-age`, so a returning
visitor would otherwise keep the old picture for up to seven days.

**Word Vibe and Number Vibe take no appearance argument**, so those captures
follow the *simulator's* appearance instead. Set it, and uninstall the app first
so a preference left behind by an earlier run cannot override it:

```sh
xcrun simctl ui booted appearance dark
xcrun simctl uninstall booted party.vibegames.VibeGames
xcodebuild test -project VibeGames.xcodeproj -scheme VibeGames \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VibeGamesUITests/VibeWordsUITests \
  -only-testing:VibeGamesUITests/VibeSudokuUITests \
  -resultBundlePath .build/shots-dark.xcresult
```

Which attachment becomes which file, for the ones the page actually uses:

| Site file | Attachment | From |
| --- | --- | --- |
| `hub-light` / `hub-dark` | `40-light-hub` / `44-dark-hub` | `AppearanceUITests` |
| `vibewords-shared-*` | `24-words-shared-host` | `VibeWordsUITests` |
| `vibewords-solved-*` | `22-words-scored` | `VibeWordsUITests` |
| `vibesudoku-grid-*` | `31-sudoku-solo` | `VibeSudokuUITests` |
| `vibesudoku-shared-*` | `33-sudoku-shared-host` | `VibeSudokuUITests` |
| `vibetrio-board-*` | `60-trio-board-light` / `62-trio-board-dark` | `VibeTrioUITests` |
| `vibetrio-leaderboard-*` | `64-trio-leaderboard-light` / `65-…-dark` | `VibeTrioUITests` |
| `vibeblurt-word`, `-guessing`, `-buzz` | `light-blurt-…` / `dark-blurt-…` | `VibeBlurtScreenshots` |
| `vibefive-counting`, `-revealed`, `-buzzed` | `03-`, `09-`, `04-` | `VibeFiveUITests` |

The **file names keep the games' original names** — `vibewords-shared-light.jpg`
is Word Vibe. They are paths rather than anything a visitor reads, and renaming
them would mean touching every `srcset` in `index.html` for no gain.

Similar Vibe needs four players, which one simulator cannot be, so
`VibeBlurtScreenshots` assembles the room by writing it straight into the
database: the app makes the game, the test fills the other three seats, deals the
teams and sets the turn to whichever screen is being photographed. It also pins
the room's seed to one whose first word is "Game Night", so the screenshots show a
word worth reading rather than whatever came up — and `Tools/find_blurt_seed.swift`
is how that seed is found, since adding one word to a pack reshuffles every deal.
Like the other back-end tests it skips itself when the database is unreachable.

    xcodebuild test -project VibeGames.xcodeproj -scheme VibeGames \
      -only-testing:VibeGamesUITests/VibeBlurtScreenshots \
      -resultBundlePath .build/BlurtShots.xcresult
    xcrun xcresulttool export attachments --path .build/BlurtShots.xcresult \
      --output-path .build/blurt-attachments

## Reviewing changes

`Tools/shoot_site.mjs` drives the Chrome already on this machine (via
puppeteer-core, installed under `.build`) and captures every section in both
colour schemes. Useful for catching white-on-white text or a section that never
reveals:

```sh
node Tools/shoot_site.mjs http://127.0.0.1:8099 .build/site-shots
```

## Deploying

The page is static, so it can go anywhere. To put it on Firebase Hosting
alongside the web game, as a second site on the same project:

```sh
firebase hosting:sites:create vibe-games --project vibe-words-party
```

Then add a `site` key to the hosting config and deploy:

```json
{
  "hosting": [
    { "site": "vibe-words-party", "public": "dist", "ignore": ["firebase.json", "**/.*", "**/node_modules/**"], "rewrites": [{ "source": "**", "destination": "/index.html" }] },
    { "site": "vibe-games", "public": "../site", "ignore": ["firebase.json", "**/.*"] }
  ]
}
```

`firebase.json` lives in `web/`, so the landing page path is relative to that.

## Accessibility and motion

The page follows `prefers-color-scheme` and honours `prefers-reduced-motion` —
the scroll reveals, the floating phone and the backdrop bloom are all disabled
for anyone who has asked for less movement, and content is shown immediately
rather than left hidden.
