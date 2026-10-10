# Vibe Words — Firebase setup

> ## Already provisioned
>
> This project was set up on your behalf and is live:
>
> | | |
> | --- | --- |
> | Project ID | `vibe-words-party` |
> | iOS app | `1:426683702317:ios:4515914b8629b4749d2ca4` |
> | Bundle ID | `party.vibegames.VibeGames` |
> | Database URL | `https://vibe-words-party-default-rtdb.firebaseio.com` |
> | Location | `us-central1` (permanent) |
> | Web app | `1:426683702317:web:47d920832c9fd36a9d2ca4` |
> | Rules | deployed from `firebase/database.rules.json` (production set) |
> | Config | `Sources/GoogleService-Info.plist` (git-ignored) |
>
> **App Check is configured but NOT enforced.** See the section below — this is
> deliberate and it matters.
>
> The sections below are kept as a reference for re-provisioning or for doing it
> again from scratch. `Tools/firebase_setup.sh` automates the lot.

## App Check: configured, deliberately unenforced

App Check is registered for both clients:

| Client | Provider | State |
| --- | --- | --- |
| Web | reCAPTCHA v3 | provider registered; **secret key still needed** |
| iOS | App Attest (+ DeviceCheck fallback) | registered, 24h token TTL |

Enforcement is **off**, and that is not laziness:

> App Check enforcement is set **per API for the whole project**, not per
> platform. Turning it on for Realtime Database would immediately block the iOS
> app, because App Attest requires a **paid Apple Developer Program membership**
> and this project currently uses a free Apple ID (its provisioning profiles
> last 7 days).

So the order to follow is:

1. Join the Apple Developer Program.
2. Register the reCAPTCHA **secret** key for the web app (Firebase console →
   App Check → the web app → reCAPTCHA v3). The secret is write-only; it is in
   the reCAPTCHA admin console, not in the site key already in `.env.local`.
3. Test both clients with enforcement off but App Check debug tokens registered.
4. Then enforce: **App Check → APIs → Realtime Database**.

The rules in `firebase/database.rules.json` are the production set and do the
rest of the work in the meantime.

Vibe Words uses **Realtime Database** (not Firestore) because it shares its
schema with the existing web client. Both can sit in the same game, on the same
project.

There is a chicken-and-egg problem worth knowing about up front:

> **Cross-play needs one project.** The iOS app only reaches the web client's
> data if both point at the *same* Firebase project. Choosing a fresh, cleanly
> named project therefore means also repointing the web client at it — which is
> a one-file change, because the web app reads everything from `.env.local`.
> Section 6 covers that. **This has not been done yet**: the web client still
> points at its original project, so web ↔ iOS cross-play does not work until
> you complete section 6.

The app is usable before any of this: solo play needs no backend at all. If
`GoogleService-Info.plist` is ever missing, the lobby simply offers solo play and
explains why the multiplayer options are unavailable.

## Re-provisioning from scratch

```sh
# 1. Install the CLI (into the workspace, so nothing lands in your home dir)
npm_config_cache="$PWD/.build/npm-cache" \
  npm install --prefix "$PWD/.build/fbcli" firebase-tools

# 2. Sign in. This opens a browser; only you can complete it.
XDG_CONFIG_HOME="$PWD/.build/fbconfig" .build/fbcli/node_modules/.bin/firebase login

# 3. Create the project, app, database, config and rules
./Tools/firebase_setup.sh <project-id> us-central1

# 4. Bundle the new config
xcodegen generate
```

The script is idempotent, so re-running it is safe. Two ordering details it
handles for you, both of which cost a debugging cycle if missed:

- `GoogleService-Info.plist` is fetched **after** the database exists.
  Fetched first it omits `DATABASE_URL`, and the app falls back to a guessed
  host that never resolves.
- The Realtime Database management API has to be **enabled** before an instance
  can be created, and enabling it is eventually consistent — so the helper in
  `Tools/firebase_database.py` retries until it takes.

---

## 1. Create the project

1. <https://console.firebase.google.com> → **Add project**
2. Name it something without the trademarked term — `vibe-words` works well.
   The project ID becomes permanent and appears in your config file, so pick it
   deliberately.
3. **Google Analytics**: everything here works without it, but the app then
   reports crashes only, not which games get played. If you want the counts the
   README describes, turn Analytics **on** at this point. Adding it to a project
   created without it is possible later, under **Project settings →
   Integrations** — but the iOS config file must then be downloaded again (step
   3 below), because `IS_ANALYTICS_ENABLED` is written into it and is `false`
   for a project that had Analytics switched off.

## 2. Create the Realtime Database

1. **Build → Realtime Database → Create Database**
2. Pick the region closest to your players. This is permanent.
3. Start in **locked mode**. The rules go in at step 4.

Copy the database URL shown at the top of the Data tab. It looks like
`https://<project-id>-default-rtdb.firebaseio.com`.

> US-region databases are `…-default-rtdb.firebaseio.com`; other regions get a
> regional prefix. Take the exact string from the console rather than guessing.

## 3. Register the iOS app

1. **Project settings → General → Your apps → Add app → iOS**
2. Bundle ID: `party.vibegames.VibeGames`
   — must match `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` exactly.
3. Nickname: anything. App Store ID: leave blank.
4. **Download `GoogleService-Info.plist`.**

Then:

```sh
cp ~/Downloads/GoogleService-Info.plist Sources/
xcodegen generate
```

It must live in `Sources/` so it is copied into the app bundle. The file is
git-ignored — it is per-project configuration, not source. A placeholder
showing the expected keys is at `Support/GoogleService-Info.plist.example`.

## 4. Deploy the database rules

The rules in `firebase/database.rules.json` are the balanced set the web client
has always used: anybody can read a game (required for multiplayer and for
cross-play), a game can only be created once, the word cannot change mid-round,
and the winner can only be set once.

Either paste `firebase/database.rules.json` into **Realtime Database → Rules**,
or deploy it:

```sh
npm install -g firebase-tools
firebase login
cd firebase
firebase deploy --only database --project YOUR_PROJECT_ID
```

## 5. App Check

The web client uses reCAPTCHA v3. A native app cannot, so the iOS client uses
**App Attest**, falling back to **DeviceCheck**, and Firebase's debug provider in
the simulator. `FirebaseBootstrapper` picks automatically.

1. **Build → App Check → Apps → VibeGames (iOS) → Register**
2. Choose **App Attest**, and add **DeviceCheck** as the fallback.
3. Leave **enforcement off** until you have tested.

> **App Attest and DeviceCheck both require a paid Apple Developer Program
> membership.** With a free Apple ID, leave App Check unenforced — the app works
> fine, it just has no attestation. Registering the provider without enforcement
> causes no harm.

**For the simulator**, the debug provider prints a token to the Xcode console on
first run:

```
[AppCheck] App Check debug token: 12345678-1234-1234-1234-1234567890AB
```

Register that in **App Check → Apps → ⋯ → Manage debug tokens** before turning
enforcement on, or the simulator will start getting rejected.

Once enforcement is on and everything is verified, enforce for Realtime
Database under **App Check → APIs → Realtime Database**.

## 6. Keep the web client in sync (for cross-play)

If you moved to a new project, point the web client at it. In the web project's
`.env.local`, update these to the new project's values (Firebase console →
Project settings → General → Your apps → the web app's config):

```
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_AUTH_DOMAIN=...
VITE_FIREBASE_DATABASE_URL=https://<new-project>-default-rtdb.firebaseio.com
VITE_FIREBASE_PROJECT_ID=<new-project>
VITE_FIREBASE_STORAGE_BUCKET=...
VITE_FIREBASE_MESSAGING_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
VITE_FIREBASE_APP_CHECK_SITE_KEY=...
VITE_FIREBASE_MEASUREMENT_ID=...
```

No code change is needed — the web client reads all of it from the environment.
Add a web app under **Project settings → Your apps** if you have not already.

Then `npm run build && firebase deploy --only hosting` in the web project.

## 7. Switching Analytics on

Analytics is optional at every level: with it off, nothing is loaded, nothing is
sent, and every game works.

1. **Enable it on the project.** **Project settings → Integrations → Google
   Analytics → Enable.** This creates the GA4 property the events land in. Note
   that a Firebase project can only be linked to an Analytics property once, and
   the link is not something this repository can do for you.

   Nothing else is needed on iOS. The app starts reporting as soon as the project
   has a property — the `IS_ANALYTICS_ENABLED` flag written into
   `GoogleService-Info.plist` is **not** a gate: a plist carrying `false` still
   starts Analytics, enables collection and uploads. That was measured rather than
   assumed, after an earlier reading of it here was wrong. Re-downloading the
   plist is harmless but not required.

2. **The measurement id, in two places.** Find it under **Project settings →
   Integrations → Google Analytics →** the web data stream, or ask the CLI:

   ```bash
   firebase apps:sdkconfig WEB <web-app-id> --project <project-id>
   ```

   It is the `G-…` value. Put it in:

   - `web/.env.local` → `VITE_FIREBASE_MEASUREMENT_ID`, then rebuild and redeploy
     (`npm run build && firebase deploy --only hosting`). It is a *build-time*
     value: with none set, nothing is loaded and nothing is sent, and that is the
     default state of a fresh checkout.
   - `site/analytics.js` → `MEASUREMENT_ID`.

   Leave either blank and that one stays off.

   > **The web client does not use the Firebase Analytics SDK**, and this is
   > deliberate. That SDK asks `firebase.googleapis.com` for the app's web config
   > at runtime and, where the answer omits `measurementId`, trusts the omission —
   > loading gtag with `id=undefined` and sending nothing, while only falling back
   > to the locally configured id if the request *fails*. That endpoint served a
   > config with no `measurementId` for a while after Analytics was enabled, while
   > `apps:sdkconfig` reported one. Using gtag.js directly removes the dependency
   > on that endpoint rather than working around it. If the web client ever stops
   > reporting, check this first:
   >
   > ```bash
   > curl -s "https://firebase.googleapis.com/v1alpha/projects/-/apps/<web-app-id>/webConfig?key=<api-key>" | grep measurementId
   > ```

To confirm it is working, open the GA4 **Realtime** report and play a round: a
`page_view` arrives on load, then `game_start`, then `game_finish`. On iOS the
same events appear, attributed to the app rather than the web stream.

A quicker check for the web client, without opening the console: in the browser's
Network tab, filter for `collect`. Playing a round should produce a request to
`google-analytics.com/g/collect` carrying `tid=` your measurement id, and an
`en=` for each of `page_view`, `game_start` and `game_finish`.

## 8. Verify

Run the app, open Vibe Words, and the lobby's multiplayer options should become
available (the "Add GoogleService-Info.plist" notice disappears).

1. **Start a game with friends** on one device → note the code.
2. **Join with a code** on a second device (or the web client).
3. Both should show the same player count, and the word should be identical.
4. Solve it on one device: the other should announce the winner.
5. **Play again** should start a countdown on both.

### How the two clients agree

```
games/{gameId}            <- Vibe Words
  word        "CRANE"      uppercase, exactly 5 letters
  creator     "Alex"
  createdAt   1737052800000        milliseconds since epoch
  started     true
  winner      { name, timestamp }
  restartTime 1737052810000        milliseconds since epoch
  players/{playerId} { name, joinedAt }
```

```
sudoku/{gameId}           <- Vibe Sudoku
  seed        1234567890   UInt32; the whole puzzle is derived from this
  difficulty  "hard"       "easy" | "medium" | "hard", chosen by the host
  creator     "Alex"
  createdAt   1737052800000
  started     true
  winner      { name, timestamp }
  restartTime 1737052810000
  players/{playerId} { name, joinedAt }
```

```
trio/{gameId}             <- Vibe Trio
  seed        1234567890   UInt32; the whole table is derived from this
  target      6            trios needed to win, 1-20
  creator     "Alex"
  createdAt   1737052800000
  started     true
  winner      { name, timestamp }
  restartTime 1737052810000
  players/{playerId} { name, joinedAt }
```

Each game has its own root node, so they share the project without colliding, and
each shared game stores **only a seed** — never the grid, the solution or a single
card — so a game costs a handful of bytes and there is nothing for a client to
read out.

Timestamps are **milliseconds**, matching JavaScript's `Date.now()`. The iOS
client converts on read and write. `Tools/check_branding.py` and the unit tests
both guard this shape via `GameSnapshotTests`.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| Lobby says "Add GoogleService-Info.plist" | The file is missing, or you did not re-run `xcodegen generate` after adding it |
| `Permission denied` on read/write | Rules not deployed, or App Check enforcing without a registered token |
| App Check debug token rejected | Register the token from the Xcode console in the Firebase console |
| Web and iOS cannot see each other's games | They are pointed at different Firebase projects — see section 6 |
| Player lingers after force-quitting | `onDisconnect` needs the rules to allow writes to `players`; check the rules deployed |
