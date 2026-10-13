# Vibe Games — landing page

A static marketing page for the app. Plain HTML, CSS and one small script: no
build step, no dependencies, nothing to install.

```
site/
  index.html
  styles.css
  main.js
  analytics.js   one page view; a no-op until a measurement id is filled in
  assets/
    qr/        appstore.svg, playstore.svg   (real QR codes, placeholder URLs)
    screens/   app screenshots, light + dark
    people/    illustrations standing in for photos
```

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
the room's seed to one whose first word is "Rainbow", so the screenshots show a
word worth reading rather than whatever came up. Like the other back-end tests it
skips itself when the database is unreachable.

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
