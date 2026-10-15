#!/usr/bin/env python3
"""Fails if the app stops being ready to submit.

App Store submission is a checklist that has to be true on one particular day,
and every item on it is the kind that is fine until it is not: a privacy policy
URL that moved, a privacy manifest that stopped shipping, a version number that
disagrees with the page that states it. None of that is behaviour, so no test
catches it.

This is the repository half of the checklist. `APP_STORE.md` is the other half —
the parts that live in App Store Connect, and the two decisions that are not
mechanical.

    python3 Tools/check_app_store.py

Needs no network and no credentials. It runs in a second, so it can run with the
other guards.
"""
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
PROJECT = ROOT / "project.yml"
MANIFEST = ROOT / "Sources/PrivacyInfo.xcprivacy"
SUPPORT = ROOT / "Sources/Features/Home/SupportView.swift"

HOST = "https://vibegames.party"

problems: list[str] = []


def fail(where: str, message: str) -> None:
    problems.append(f"{where}: {message}")


project = PROJECT.read_text()
settings = re.search(r"MARKETING_VERSION: \"([^\"]+)\"", project)
builds = re.search(r"CURRENT_PROJECT_VERSION: \"([^\"]+)\"", project)
version = settings.group(1) if settings else "?"

# ── the two URLs an app record cannot be created without ──────────────────────

for page, label in (("privacy", "privacy policy"), ("support", "support")):
    path = SITE / f"{page}.html"
    if not path.exists():
        fail(f"site/{page}.html", f"missing — App Store Connect wants a {label} URL")
        continue
    if f"{HOST}/{page}" not in path.read_text():
        fail(f"site/{page}.html", f"does not claim {HOST}/{page} as its canonical URL")
    # Reachable from inside the app, which is what a reviewer looks for.
    if f"vibegames.party/{page}" not in SUPPORT.read_text():
        fail("Sources/Features/Home/SupportView.swift", f"the panel does not link the {label}")
    if f"{HOST}/{page}" not in (SITE / "sitemap.xml").read_text():
        fail("site/sitemap.xml", f"the {label} page is not listed")

# ── the privacy manifest ──────────────────────────────────────────────────────

if not MANIFEST.exists():
    fail("Sources/PrivacyInfo.xcprivacy", "missing — the upload is bounced with ITMS-91053")
else:
    try:
        manifest = plistlib.loads(MANIFEST.read_bytes())
    except Exception as error:  # noqa: BLE001 - any parse failure is the finding
        fail("Sources/PrivacyInfo.xcprivacy", f"is not a readable plist ({error})")
        manifest = {}

    if manifest.get("NSPrivacyTracking") is not False:
        fail("Sources/PrivacyInfo.xcprivacy", "does not declare that there is no tracking")
    if manifest.get("NSPrivacyTrackingDomains"):
        fail("Sources/PrivacyInfo.xcprivacy", "names tracking domains, and nothing here tracks")

    apis = {entry.get("NSPrivacyAccessedAPIType") for entry in manifest.get("NSPrivacyAccessedAPITypes", [])}
    if "NSPrivacyAccessedAPICategoryUserDefaults" not in apis:
        fail("Sources/PrivacyInfo.xcprivacy", "does not declare UserDefaults, which @AppStorage uses")
    for entry in manifest.get("NSPrivacyAccessedAPITypes", []):
        if not entry.get("NSPrivacyAccessedAPITypeReasons"):
            fail("Sources/PrivacyInfo.xcprivacy",
                 f"{entry.get('NSPrivacyAccessedAPIType')} has no reason, which is the part Apple reads")

    # The manifest, the listing answers and the policy page have to agree. The
    # policy page is the one that can be checked here.
    policy = (SITE / "privacy.html").read_text().lower()
    for declared, phrase in (
        ("NSPrivacyCollectedDataTypeDeviceID", "advertising identifier"),
        ("NSPrivacyCollectedDataTypeProductInteraction", "how the games are used"),
        ("NSPrivacyCollectedDataTypeCrashData", "crash reports"),
        ("NSPrivacyCollectedDataTypeCustomerSupport", "feedback box"),
        ("NSPrivacyCollectedDataTypeOtherUserContent", "nickname"),
    ):
        types = {entry.get("NSPrivacyCollectedDataType") for entry in manifest.get("NSPrivacyCollectedDataTypes", [])}
        if declared not in types:
            fail("Sources/PrivacyInfo.xcprivacy", f"does not declare {declared}")
        if phrase not in policy:
            fail("site/privacy.html", f"does not mention the {phrase} the manifest declares")

# ── things that are set in the project and would be easy to lose ──────────────

for key, value in (
    ("ITSAppUsesNonExemptEncryption", "false"),
    ("CFBundleShortVersionString", f'"{version}"'),
    ("CFBundleVersion", f'"{builds.group(1) if builds else "?"}"'),
    ("TARGETED_DEVICE_FAMILY", '"1,2"'),
):
    if key == "TARGETED_DEVICE_FAMILY":
        present = key in project
    else:
        present = f"{key}: {value}" in project
    if not present:
        fail("project.yml", f"{key} is not set to {value}")

# The support page states the version, so that somebody reading it knows what
# they are running — and so that a forgotten bump is caught here rather than by a
# user.
stated = re.search(r"Vibe Games (\d+\.\d+)", (SITE / "support.html").read_text())
if not stated:
    fail("site/support.html", "does not say which version it is for")
elif stated.group(1) != version:
    fail("site/support.html", f"says version {stated.group(1)}, and project.yml says {version}")

# The screenshots are shot rather than committed, so this only says whether they
# have been shot; `Tools/appstore_shots.py` is what makes them, and it checks the
# pixel sizes itself.
for slug, device in (("iphone-6.9", "iPhone 17 Pro Max"), ("ipad-13", "iPad Pro 13-inch (M5)")):
    shot_dir = ROOT / ".build" / "appstore" / slug
    count = len(list(shot_dir.glob("*.jpg"))) if shot_dir.exists() else 0
    if count < 3:
        fail("screenshots", f"{count} for {slug} — shoot them with "
                            f"`python3 Tools/appstore_shots.py \"{device}\" {slug}`")

if problems:
    print(f"{len(problems)} thing(s) between this app and the App Store:\n", file=sys.stderr)
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    print("\nAPP_STORE.md has the rest of the checklist.", file=sys.stderr)
    sys.exit(1)

print(f"App Store check passed — version {version}, the privacy manifest, both URLs, "
      "and a screenshot set for each required size.")
