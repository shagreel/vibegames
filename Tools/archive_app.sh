#!/usr/bin/env bash
#
# Archives the app and exports the .ipa that goes to App Store Connect.
#
#   Tools/archive_app.sh
#
# Writes `.build/release/VibeGames.xcarchive`, an `.ipa` beside it, and then opens
# the .ipa up and checks what is inside it — the privacy manifest, the icon, the
# version and the export-compliance flag. That check is the point of the script:
# those are the things App Store Connect rejects a build for after it has been
# uploaded and you have waited, so it is better to know here.
#
# The upload itself is deliberately not here. It needs credentials, and a
# credential in a script is a credential anybody can read:
#
#   Xcode → Window → Organizer → Distribute App → App Store Connect → Upload
#
# **Bump CURRENT_PROJECT_VERSION in project.yml before every upload.** App Store
# Connect refuses a build number it has already seen, and the export is told not
# to manage that for you — the project is the source of truth.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT=".build/release"
ARCHIVE="$OUT/VibeGames.xcarchive"
EXPORT="$OUT/export"
OPTIONS="$OUT/ExportOptions.plist"
TEAM=$(awk '/DEVELOPMENT_TEAM:/ {print $2; exit}' project.yml)
VERSION=$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' project.yml)
BUILD=$(awk -F'"' '/CURRENT_PROJECT_VERSION:/ {print $2; exit}' project.yml)

if [ -z "$TEAM" ] || [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
  echo "Could not read the team, version and build number out of project.yml." >&2
  exit 1
fi

echo "Archiving Vibe Games $VERSION ($BUILD) for team $TEAM"

rm -rf "$ARCHIVE" "$EXPORT"
mkdir -p "$OUT"

# `manageAppVersionAndBuildNumber` is false on purpose: Xcode would otherwise
# pick its own build number at export time, and the number in the repository is
# the one the support page and this script both quote.
cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>export</string>
  <key>teamID</key>
  <string>$TEAM</string>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST

xcodebuild -project VibeGames.xcodeproj -scheme VibeGames \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates archive \
  | tail -5

# The archive is checked before anything is exported. It is the same app either
# way, so a machine that cannot sign for the App Store — no account signed into
# Xcode, no distribution certificate — still says whether what was built is
# submittable.
APP=$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name "*.app" | head -1)

echo
echo "Checking what was built"

PROBLEMS=0
check() { # present, what it is
  if [ "$1" = "1" ]; then
    echo "  ok       $2"
  else
    echo "  MISSING  $2" >&2
    PROBLEMS=$((PROBLEMS + 1))
  fi
}

check "$([ -f "$APP/PrivacyInfo.xcprivacy" ] && echo 1 || echo 0)" "privacy manifest"

PLIST="$APP/Info.plist"
value() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null || echo ""; }

check "$([ "$(value ITSAppUsesNonExemptEncryption)" = "false" ] && echo 1 || echo 0)" \
  "export compliance answered in the app (no encryption question at upload)"
check "$([ "$(value CFBundleShortVersionString)" = "$VERSION" ] && echo 1 || echo 0)" \
  "version $VERSION"
check "$([ "$(value CFBundleVersion)" = "$BUILD" ] && echo 1 || echo 0)" \
  "build $BUILD"
check "$([ -n "$(ls "$APP"/AppIcon*.png 2>/dev/null)" ] && echo 1 || echo 0)" "app icon"
check "$(codesign --verify --deep --strict "$APP" 2>/dev/null && echo 1 || echo 0)" "code signature"

if [ "$PROBLEMS" -gt 0 ]; then
  echo
  echo "$PROBLEMS thing(s) wrong with the build." >&2
  exit 1
fi

echo
echo "Exporting"

if ! EXPORT_LOG=$(xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$OPTIONS" -exportPath "$EXPORT" -allowProvisioningUpdates 2>&1); then
  echo "$EXPORT_LOG" | grep -E "^error:" | head -4 >&2
  echo >&2
  # The two ways this fails on a machine that is otherwise fine, said in terms of
  # what to do rather than what Xcode called it.
  if echo "$EXPORT_LOG" | grep -q "No Accounts"; then
    echo "Xcode has no Apple ID signed in, so it cannot make a distribution" >&2
    echo "certificate or an App Store profile. Sign in once, then run this again:" >&2
    echo >&2
    echo "  Xcode → Settings → Accounts → + → Apple ID" >&2
    echo >&2
    echo "It has to be the Apple ID that holds the Apple Developer Program" >&2
    echo "membership for team $TEAM — a free account cannot sign for the store." >&2
  elif echo "$EXPORT_LOG" | grep -q "No profiles for"; then
    echo "There is no App Store provisioning profile yet. With the account signed" >&2
    echo "in Xcode makes one on the next run, but the app record has to exist" >&2
    echo "first: App Store Connect → My Apps → + → New App, with the bundle id" >&2
    echo "party.vibegames.VibeGames. APP_STORE.md has the whole order." >&2
  fi
  echo >&2
  echo "The archive itself is fine and is at $ARCHIVE" >&2
  exit 1
fi

IPA=$(find "$EXPORT" -name "*.ipa" | head -1)
if [ -z "$IPA" ]; then
  echo "No .ipa came out of the export." >&2
  exit 1
fi

echo
echo "Ready to upload: $IPA"
echo "Next: Xcode → Window → Organizer → Distribute App → App Store Connect → Upload."
