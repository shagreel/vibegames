#!/usr/bin/env bash
#
# Provisions the Firebase backend for Vibe Words.
#
# Run this after `firebase login`. Safe to re-run: every step checks whether the
# thing already exists before creating it.
#
#   ./Tools/firebase_setup.sh <project-id> [database-location]
#
# Example:
#   ./Tools/firebase_setup.sh vibe-words-party us-central1
#
# The project id and the database location are both PERMANENT, so choose them
# deliberately. The location cannot be changed later without a new project.
#
# Note on ordering: GoogleService-Info.plist is fetched *after* the database
# exists. Fetched earlier it omits DATABASE_URL, and the app falls back to a
# guessed URL that does not resolve.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIREBASE="$ROOT/.build/fbcli/node_modules/.bin/firebase"
BUNDLE_ID="party.vibegames.VibeGames"
APP_DISPLAY_NAME="Vibe Games"
CONFIG_DIR="$ROOT/.build/fbconfig"

# Keep CLI credentials and caches inside the workspace, so everything this
# script does is self-contained and easy to revoke.
export XDG_CONFIG_HOME="$CONFIG_DIR"
export NO_UPDATE_NOTIFIER=1

PROJECT_ID="${1:-}"
LOCATION="${2:-us-central1}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "usage: $0 <project-id> [database-location]" >&2
  exit 64
fi

if [[ ! -x "$FIREBASE" ]]; then
  echo "Firebase CLI not found at $FIREBASE" >&2
  echo "Install it with:" >&2
  echo "  npm_config_cache=\"\$PWD/.build/npm-cache\" npm install --prefix \"\$PWD/.build/fbcli\" firebase-tools" >&2
  exit 69
fi

say() { printf '\n==> %s\n' "$1"; }

# The CLI prints an update-notice box that would otherwise pollute the output.
fb() { "$FIREBASE" "$@" 2>&1 | grep -v "update check\|sudo chown\|^│\|^┌\|^└\|^$" || true; }

# An app id looks like 1:426683702317:ios:4515914b8629b4749d2ca4 -- the leading
# number is part of it and must not be trimmed.
APP_ID_PATTERN='[0-9]\+:[0-9]\+:ios:[a-f0-9]\+'

say "Checking authentication"
if ! fb login:list | grep -q "@"; then
  echo "Not signed in. Run this first, then re-run the script:" >&2
  echo "  XDG_CONFIG_HOME=\"$CONFIG_DIR\" \"$FIREBASE\" login" >&2
  exit 77
fi
fb login:list

say "Project: $PROJECT_ID"
if fb projects:list | grep -q "$PROJECT_ID"; then
  echo "Already exists, reusing it."
else
  echo "Creating it (this takes a moment)..."
  fb projects:create "$PROJECT_ID" -n "$APP_DISPLAY_NAME"
fi

say "iOS app for bundle id $BUNDLE_ID"
APP_ID="$(fb apps:list IOS --project "$PROJECT_ID" | grep -o "$APP_ID_PATTERN" | head -1 || true)"

if [[ -z "$APP_ID" ]]; then
  fb apps:create IOS "$APP_DISPLAY_NAME" -b "$BUNDLE_ID" --project "$PROJECT_ID"
  APP_ID="$(fb apps:list IOS --project "$PROJECT_ID" | grep -o "$APP_ID_PATTERN" | head -1 || true)"
  if [[ -z "$APP_ID" ]]; then
    echo "Could not determine the iOS app id; check the console." >&2
    exit 1
  fi
fi
echo "App id: $APP_ID"

say "Realtime Database instance"
python3 "$ROOT/Tools/firebase_database.py" "$PROJECT_ID" "$LOCATION" "$CONFIG_DIR"

say "GoogleService-Info.plist"
# apps:sdkconfig refuses to overwrite, so clear the way first. The file must sit
# in Sources/ for XcodeGen to copy it into the bundle.
rm -f "$ROOT/Sources/GoogleService-Info.plist"
fb apps:sdkconfig IOS "$APP_ID" -o "$ROOT/Sources/GoogleService-Info.plist" >/dev/null || true
if [[ -f "$ROOT/Sources/GoogleService-Info.plist" ]]; then
  if /usr/libexec/PlistBuddy -c "Print :DATABASE_URL" \
       "$ROOT/Sources/GoogleService-Info.plist" >/dev/null 2>&1; then
    echo "Wrote Sources/GoogleService-Info.plist (includes DATABASE_URL)"
  else
    echo "WARNING: the plist has no DATABASE_URL. Multiplayer will not work." >&2
  fi
else
  echo "Could not write the plist. Run manually:" >&2
  echo "  \"$FIREBASE\" apps:sdkconfig IOS $APP_ID -o Sources/GoogleService-Info.plist" >&2
  exit 1
fi

say "Deploying database rules"
mkdir -p "$ROOT/firebase"
cat > "$ROOT/firebase/firebase.json" <<'JSON'
{
  "database": {
    "rules": "database.rules.json"
  }
}
JSON
cat > "$ROOT/firebase/.firebaserc" <<JSON
{
  "projects": {
    "default": "$PROJECT_ID"
  }
}
JSON
( cd "$ROOT/firebase" && "$FIREBASE" deploy --only database --project "$PROJECT_ID" --non-interactive 2>&1 \
    | grep -v "update check\|sudo chown\|^│\|^┌\|^└\|^$" )

say "Done"
cat <<SUMMARY
Project:    $PROJECT_ID
iOS app id: $APP_ID
Bundle id:  $BUNDLE_ID
Database:   $LOCATION
Rules:      firebase/database.rules.json (deployed)
Config:     Sources/GoogleService-Info.plist

Next:
  1. xcodegen generate   (so the new plist is bundled)
  2. Build and run, then open Vibe Words -- the lobby should offer multiplayer.
  3. To play against the web client, point its .env.local at this project
     (see FIREBASE_SETUP.md, section 6).
  4. App Check is NOT enforced. See FIREBASE_SETUP.md, section 5.
SUMMARY
