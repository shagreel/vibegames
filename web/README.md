# Vibe Games, in a browser

The web client for **play.vibegames.party** — React, TypeScript, Vite and the
Firebase Realtime Database. A menu, and a game at each path:

| Path | Game |
| --- | --- |
| `/` | the menu |
| `/words` | Vibe Words — solo and shared |
| `/trio` | Vibe Trio — solo and shared on one table |
| `/five` | Vibe Five — pass the phone; no server involved |
| `/sudoku` | Vibe Sudoku — solo and raced on one seed |

All three shared games use the same database schema as the iOS app, so a browser
and a phone can play together. Vibe Five has no server at all — it is one phone
handed round a table.

## ✨ Features

- 🎮 **Multiplayer Support** - Play with friends in real-time
- 📱 **Mobile Responsive** - Works on all devices
- 🔥 **Firebase Integration** - Real-time game synchronization
- 🎯 **14,855 Valid Words** - Comprehensive word dictionary
- 👥 **Player Tracking** - See how many players have joined
- 🏆 **Winner Announcements** - Celebrate victories together
- 🔄 **Play Again** - Restart games with countdown timer
- 📋 **Easy Sharing** - Copy game link to invite friends

## 🧪 Test Suite

**189 passing tests.**

```bash
✓ src/test/trioEngine.test.ts     (35 tests)   the rule, and agreement with iOS
✓ src/test/sudokuGenerator.test.ts (34 tests)  21 boards matched against iOS
✓ src/test/gameLogic.test.ts    (17 tests)
✓ src/test/fiveModel.test.ts    (16 tests)   rounds, the clock, the packs
✓ src/test/errors.test.ts       (13 tests)   the crash reporter
✓ src/test/analytics.test.ts    (16 tests)   what gets counted, and what does not
✓ src/test/blurtEngine.test.ts  (21 tests)  the deck, teams and scoring vs iOS
✓ src/test/localStorage.test.ts  (9 tests)
✓ src/test/integration.test.ts   (8 tests)
✓ src/test/multiDevice.test.ts   (7 tests)
✓ src/test/fiveSound.test.ts       (7 tests)   the synthesised cues
✓ src/test/router.test.ts        (6 tests)
```

`trioEngine.test.ts` is the one to keep green: a shared Vibe Trio game sends a
seed and the taken cards and nothing else, so if the browser and the phone
shuffled differently they would sit in the same game looking at different tables.
It checks the TypeScript engine against fixtures dumped from the Swift engine —
see `Tools/trio_fixtures/`.

See [TESTING.md](TESTING.md) for detailed test documentation.

## 🚀 Getting Started

### Prerequisites

- Node.js v20.9.0 or higher
- npm or yarn
- Firebase account (for multiplayer features)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```

3. Set up Firebase (see [FIREBASE_SETUP.md](FIREBASE_SETUP.md))

4. Create `.env.local` file with your Firebase credentials:
   ```
   VITE_FIREBASE_API_KEY=your_api_key
   VITE_FIREBASE_AUTH_DOMAIN=your_auth_domain
   VITE_FIREBASE_DATABASE_URL=your_database_url
   VITE_FIREBASE_PROJECT_ID=your_project_id
   VITE_FIREBASE_STORAGE_BUCKET=your_storage_bucket
   VITE_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
   VITE_FIREBASE_APP_ID=your_app_id
   ```

5. Start the development server:
   ```bash
   npm run dev
   ```

## 🧪 Running Tests

```bash
# Run tests in watch mode
npm test

# Run tests once (CI mode)
npm run test:run

# Run tests with UI
npm run test:ui
```

## 📚 Documentation

- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) - Firebase configuration guide
- [TESTING.md](TESTING.md) - Comprehensive test documentation
- [src/test/README.md](src/test/README.md) - Test suite overview

## 🏗️ Built With

- **React 19.2.0** - UI framework
- **TypeScript** - Type safety
- **Vite 7.2.2** - Build tool and dev server
- **Firebase Realtime Database** - Real-time synchronization
- **Vitest** - Testing framework

## 📱 Browser Support

Works on all modern browsers and devices:
- ✅ Chrome (desktop & mobile)
- ✅ Firefox
- ✅ Safari (desktop & mobile)
- ✅ Edge

## 💥 When Something Breaks

A crash is the one failure nobody can report: the page stops working, so there
is no form left to type in. `src/errors.ts` catches what escapes — a render that
throws, a promise nobody handled — and posts it down the same path as feedback,
where it becomes an issue on the repository with a `crash` label.

It is deliberately quiet and bounded. Each distinct failure is sent once per
session (keyed on the message, so the same exception at a hundred moments is one
report) and a session stops after five. Sends are fire-and-forget: if the report
itself cannot be posted, nothing is shown, because complaining about the failure
path would be a crash reporter crashing.

One caveat worth knowing: a failure inside a **cross-origin** script reaches the
handler as just `Script error.` with no stack. That is the browser withholding
detail, not the reporter losing it, and it does not apply to the app's own
bundle. The page and browser are still recorded, which is usually enough to
place it.

## 📈 What Gets Counted

`src/analytics.ts` reports four things that matter, into the same Google
Analytics property the iOS client uses, with the same event names and values:

| event | when | carries |
| --- | --- | --- |
| `page_view` | every route, including the first | `page_path`, `screen_name` |
| `game_start` | a round begins | `game_name`, `mode`, `grade`, `round` |
| `game_finish` | a round ends | `game_name`, `mode`, `outcome`, `score`, `seconds` |
| `share` | a game link or the app is shared | `content_type`, `item_id` |

Plus `support_open`, `donation_tap` and `feedback_sent` around the support panel.

Two things are deliberate rather than incidental:

- **The first page view is counted once.** gtag's automatic page views are
  switched off (`send_page_view: false`) and every route is logged here instead,
  so the load you land on is counted like every other one. Left alone, gtag
  counts the first load only, and a menu-based single-page app looks like
  exactly one page.
- **With no measurement id, nothing is loaded and nothing is sent.** The id is a
  *build-time* setting: without one the gtag script tag is never created. Add it
  to `.env.local` and rebuild, and it is live; there is nothing to toggle at
  runtime.

### Why gtag.js and not the Firebase SDK

The Firebase Analytics SDK was the obvious choice and did not work. It asks
`firebase.googleapis.com` for the app's web config at runtime and, where the
answer omits `measurementId`, trusts the omission — loading gtag with
`id=undefined` and sending nothing. It only falls back to the locally configured
id if the request *fails*, and a 200 with an incomplete body is not a failure.
That endpoint served a config with no `measurementId` while `apps:sdkconfig`
reported one, so the id was known and unused.

Since the id is known at build time anyway, it goes straight to gtag, which
removes the dependency rather than working around it. It also drops the SDK's
~19 kB from the bundle: gtag.js comes from Google's CDN, which every site using
it shares.

Routes are watched from `onPathChange` in `src/router.ts`, subscribed once at
startup rather than from a component. React runs effects twice in development,
and a page view counted twice is worse than one not counted at all, because it
looks like data. The same reasoning guards every effect-based event.

## 🔐 Privacy & Data

- User data stored in browser localStorage
- Each device gets a unique browser ID
- No personal information collected
- Game data stored in Firebase Realtime Database
- Crash reports carry the error, the page and the browser's user-agent string,
  and are published as public issues on the repository
- Analytics counts what happened — a route, a game started, a game finished —
  and never who did it: no names, no game codes, no feedback text

## 📄 License

MIT
