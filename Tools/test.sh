#!/usr/bin/env bash
#
# Runs the test suites, with a fast default and everything behind --all.
#
# Why this exists: the iOS suite is dominated by what a UI test costs before it
# asserts anything. Measured from the test logs, each test method spends about six
# seconds launching the app and setting up the automation session, and about half
# a second per interaction after that — 47 of them came to 644 seconds, and the
# figures barely move for anything the app does. Three things that sound like they
# should help, and do not:
#
#   * Running them in parallel. `-parallel-testing-enabled YES` with four
#     simulator clones took 717 seconds, against 644 serially: four simulators and
#     their apps do not fit on one Mac, and every test ran about half again as
#     slow.
#   * Making the animations instant. The Trio board's one-second spring looked
#     like the obvious cost — it is paid three times a round — and turning it off
#     changed nothing at all (51.6s against 53s). XCUITest does not wait on
#     SwiftUI's implicit animations, and only the third tap of a round changes the
#     table anyway.
#   * Making the board read one query instead of 24. That was real, and worth
#     doing, but it is seconds rather than minutes.
#
# What is left is running less: eight tests exist only to produce the landing
# page's screenshots, and they are the slowest in the suite — the Vibe Trio
# leaderboard pair alone plays two complete games of two dozen rounds each, and
# the two of them came to 100 seconds. They are skipped by default here and run by
# `--all`, which is what to use before deploying the site or when the screenshots
# need regenerating.
#
# Usage:
#   Tools/test.sh              unit tests, then the functional UI tests
#   Tools/test.sh --all        everything, including the screenshot fixtures
#   Tools/test.sh --unit       unit tests only (about 30 seconds)
#   Tools/test.sh --ui         UI tests only
#
# A different simulator:
#   SIMULATOR='iPhone 15' Tools/test.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
DESTINATION="platform=iOS Simulator,name=$SIMULATOR"
PROJECT="VibeGames.xcodeproj"
SCHEME="VibeGames"

# Tests whose only job is to shoot the landing page's screenshots. Named one by
# one rather than by class, because `VibeBlurtScreenshots` also holds functional
# tests about presence and the scoreboard that belong in the fast run.
SCREENSHOT_ONLY=(
  "VibeGamesUITests/AppearanceUITests"
  "VibeGamesUITests/VibeTrioUITests/testLightAppearance"
  "VibeGamesUITests/VibeTrioUITests/testDarkAppearance"
  "VibeGamesUITests/VibeTrioUITests/testLeaderboardLight"
  "VibeGamesUITests/VibeTrioUITests/testLeaderboardDark"
  "VibeGamesUITests/VibeBlurtScreenshots/testLightAppearance"
  "VibeGamesUITests/VibeBlurtScreenshots/testDarkAppearance"
  "VibeGamesUITests/VibeTenScreenshots/testLightAppearance"
  "VibeGamesUITests/VibeTenScreenshots/testDarkAppearance"
)

skips=()
for test in "${SCREENSHOT_ONLY[@]}"; do
  skips+=("-skip-testing:$test")
done

run() {
  local what="$1"; shift
  echo
  echo "== $what"
  local log
  log=$(mktemp)
  # The log is kept on failure and thrown away on success: xcodebuild says a great
  # deal, and the one thing worth reading is why it stopped.
  if xcodebuild -project "$PROJECT" -scheme "$SCHEME" -sdk iphonesimulator \
    -destination "$DESTINATION" "$@" test > "$log" 2>&1; then
    grep -E "Executed [0-9]+ tests" "$log" | tail -1
    echo "   ok"
    rm -f "$log"
  else
    grep -E "error:|XCTAssert|Executed [0-9]+ tests|TEST FAILED|Testing failed" "$log" | tail -25
    echo "   FAILED — the whole log is at $log"
    exit 1
  fi
}

mode="${1:-}"

case "$mode" in
  --all)
    echo "Every test, including the $((${#SCREENSHOT_ONLY[@]})) screenshot fixtures."
    run "unit tests" -only-testing:VibeGamesTests
    run "UI tests" -only-testing:VibeGamesUITests
    ;;
  --unit)
    run "unit tests" -only-testing:VibeGamesTests
    ;;
  --ui)
    run "functional UI tests" -only-testing:VibeGamesUITests "${skips[@]}"
    ;;
  "")
    echo "Skipping ${#SCREENSHOT_ONLY[@]} screenshot-only tests — pass --all to include them."
    run "unit tests" -only-testing:VibeGamesTests
    run "functional UI tests" -only-testing:VibeGamesUITests "${skips[@]}"
    ;;
  *)
    echo "Unknown option: $mode" >&2
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
    ;;
esac
