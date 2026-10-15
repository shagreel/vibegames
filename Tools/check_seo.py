#!/usr/bin/env python3
"""Fails if either site stops being findable.

Search-engine basics rot quietly: a page is added and not put in the sitemap, a
canonical is left pointing at a host that no longer serves the page, an
`og:image` is moved and every shared link loses its picture. None of that shows
up in a test suite, because none of it is behaviour.

So this reads the two heads, the two sitemaps and the two robots files and
complains. It needs no network and no credentials — it is about what the files
say, checked against each other, and against the files they point at.

    python3 Tools/check_seo.py

What it does not do: check that any of it is *true*, that a search engine agrees,
or that the pages are fast. Those are a person's job, and `site/README.md` says
which buttons to press.
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
WEB = ROOT / "web"

SITEMAP_NS = "{http://www.sitemaps.org/schemas/sitemap/0.9}"

# The one host each set of pages belongs to. `vibe-games.web.app` serves the same
# files as vibegames.party, which is exactly why the canonical has to be explicit:
# two addresses for one page is a duplicate as far as a search engine is concerned.
LANDING_HOST = "https://vibegames.party"
GAME_HOST = "https://play.vibegames.party"

TITLE_MIN, TITLE_MAX = 10, 65
DESCRIPTION_MIN, DESCRIPTION_MAX = 50, 170


class Head(HTMLParser):
    """Just enough of a parser: the head's tags, the h1s, the images, the body landmarks."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.meta: dict[str, str] = {}
        self.links: list[dict[str, str]] = []
        self.title = ""
        self.h1s = 0
        self.images: list[dict[str, str]] = []
        self.landmarks: set[str] = set()
        self.json_ld: list[str] = []
        self.lang = ""
        self._in_title = False
        self._in_json_ld = False
        self._script = ""

    def handle_starttag(self, tag, attrs) -> None:
        # No PEP 604 unions in the annotations anywhere in this file: the system
        # Python here is 3.9, where `str | None` is a TypeError at import.
        a = {k: (v or "") for k, v in attrs}

        if tag == "html":
            self.lang = a.get("lang", "")
        elif tag == "title":
            self._in_title = True
        elif tag == "meta":
            key = a.get("property") or a.get("name") or a.get("charset")
            if key:
                self.meta[key] = a.get("content", "")
        elif tag == "link":
            self.links.append(a)
        elif tag == "h1":
            self.h1s += 1
        elif tag == "img":
            self.images.append(a)
        elif tag in ("main", "header", "footer", "nav"):
            self.landmarks.add(tag)
        elif tag == "script":
            if a.get("type") == "application/ld+json":
                self._in_json_ld = True
                self._script = ""

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
        elif tag == "script" and self._in_json_ld:
            self._in_json_ld = False
            self.json_ld.append(self._script)

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self.title += data
        elif self._in_json_ld:
            self._script += data


problems: list[str] = []


def fail(where: str, message: str) -> None:
    problems.append(f"{where}: {message}")


def parse(path: Path) -> Head:
    head = Head()
    head.feed(path.read_text(encoding="utf-8"))
    return head


def link_of(head: Head, rel: str) -> str:
    for link in head.links:
        if rel in link.get("rel", "").split():
            return link.get("href", "")
    return ""


def sitemap_urls(path: Path) -> list[str]:
    if not path.exists():
        fail(path.relative_to(ROOT).as_posix(), "missing")
        return []
    try:
        root = ET.fromstring(path.read_text(encoding="utf-8"))
    except ET.ParseError as error:
        fail(path.relative_to(ROOT).as_posix(), f"is not valid XML ({error})")
        return []
    return [node.text or "" for node in root.iter(f"{SITEMAP_NS}loc")]


def check_robots(path: Path, host: str) -> None:
    where = path.relative_to(ROOT).as_posix()
    if not path.exists():
        fail(where, "missing")
        return
    text = path.read_text(encoding="utf-8")
    if re.search(r"(?im)^\s*disallow:\s*/\s*$", text):
        fail(where, "disallows everything, on a host that is meant to be found")
    if f"Sitemap: {host}/sitemap.xml" not in text:
        fail(where, f"should point at {host}/sitemap.xml")


def check_page(path: Path, host: str, *, url: str, needs_json_ld: bool,
               expect_body: bool = True) -> None:
    """The head of one page, and the files it names.

    `expect_body` is false for the game's shell, which is a `<div id="root">` and
    a script: its headings and landmarks are drawn by React, and are checked
    below rather than here.
    """
    where = path.relative_to(ROOT).as_posix()
    head = parse(path)

    if head.lang != "en":
        fail(where, f"<html lang> is {head.lang!r}")
    if "viewport" not in head.meta:
        fail(where, "no viewport")
    elif "width=device-width" not in head.meta["viewport"]:
        fail(where, "the viewport does not follow the device width")

    if not head.title:
        fail(where, "no <title>")
    elif not TITLE_MIN <= len(head.title) <= TITLE_MAX:
        fail(where, f"title is {len(head.title)} characters, want {TITLE_MIN}-{TITLE_MAX}")

    description = head.meta.get("description", "")
    if not description:
        fail(where, "no meta description")
    elif not DESCRIPTION_MIN <= len(description) <= DESCRIPTION_MAX:
        fail(where, f"description is {len(description)} characters, "
                    f"want {DESCRIPTION_MIN}-{DESCRIPTION_MAX}")

    canonical = link_of(head, "canonical")
    if not canonical:
        fail(where, "no canonical link")
    elif not canonical.startswith(f"{host}/"):
        fail(where, f"canonical is {canonical!r}, which is not on {host}")

    for key in ("og:type", "og:site_name", "og:title", "og:description", "og:url", "og:image"):
        if not head.meta.get(key):
            fail(where, f"no {key}")
    if head.meta.get("og:url") and canonical and head.meta["og:url"] != canonical:
        fail(where, "og:url and the canonical disagree about which page this is")
    if head.meta.get("og:title") and head.meta["og:title"] != head.title:
        fail(where, "og:title and <title> disagree")

    image = head.meta.get("og:image", "")
    if image:
        if not image.startswith("https://"):
            fail(where, f"og:image is {image!r}, which is not an absolute https URL")
        elif (SITE / image.removeprefix(f"{LANDING_HOST}/")) not in [
            p for p in (SITE / "assets").rglob("*")
        ]:
            fail(where, f"og:image points at {image!r}, which is not a file on this site")
        if head.meta.get("og:image:width") != "1200" or head.meta.get("og:image:height") != "630":
            fail(where, "og:image should declare its 1200x630 size, or a preview guesses")

    if head.meta.get("twitter:card") != "summary_large_image":
        fail(where, "no twitter:card of summary_large_image")
    for key in ("twitter:title", "twitter:description", "twitter:image"):
        if not head.meta.get(key):
            fail(where, f"no {key}")

    if not link_of(head, "icon"):
        fail(where, "no favicon: an icon-less result looks like a broken site")

    if expect_body:
        if head.h1s != 1:
            fail(where, f"{head.h1s} <h1> elements, want exactly one")
        for landmark in ("header", "main", "footer"):
            if landmark not in head.landmarks:
                fail(where, f"no <{landmark}> landmark")

        for index, attrs in enumerate(head.images, start=1):
            source = attrs.get("src", "?")
            if not attrs.get("alt") and not attrs.get("aria-hidden"):
                fail(where, f"image {index} ({source}) has no alt text")
            if not (attrs.get("width") and attrs.get("height")):
                fail(where, f"image {index} ({source}) has no width and height, so it shifts the page")

    if needs_json_ld:
        if not head.json_ld:
            fail(where, "no structured data")
        for block in head.json_ld:
            try:
                data = json.loads(block)
            except json.JSONDecodeError as error:
                fail(where, f"structured data is not valid JSON ({error})")
                continue
            if "@context" not in data or "@graph" not in data and "@type" not in data:
                fail(where, "structured data has no @context and @type")
            for url_in_data in re.findall(r'"(@id|url|image)":\s*"(https?://[^"]+)"', json.dumps(data)):
                if not url_in_data[1].startswith("https://"):
                    fail(where, f"structured data names {url_in_data[1]!r}, which is not https")

    return head


# Every page on the landing host, found rather than listed: a page that is not
# checked is a page that can rot, and one that is not in the sitemap is a page
# nobody finds.
PAGES = {path.name: path for path in sorted(SITE.glob("*.html"))}

print("The landing page — vibegames.party\n")
for name, path in PAGES.items():
    url = "/" if name == "index.html" else "/" + name.removesuffix(".html")
    check_page(path, LANDING_HOST, url=url, needs_json_ld=(name == "index.html"))
    print()

print("The game — play.vibegames.party\n")
check_page(WEB / "index.html", GAME_HOST, url="/", needs_json_ld=False, expect_body=False)

# The shell has no body, so the two things a search engine and a screen reader
# need from it have to come from the app: a heading per screen, and a title per
# route. Both are one line away from being forgotten when a game is added.
app = (WEB / "src/App.tsx").read_text(encoding="utf-8")
titles_source = (WEB / "src/titles.ts").read_text(encoding="utf-8")
routes = set(re.findall(r"case '([^']+)'", app)) | {"/"}
declared = set(re.findall(r"^  '([^']+)':", titles_source, re.M))
for route in sorted(routes - declared):
    fail("web/src/titles.ts", f"{route} is a route with no title")
for route in sorted(declared - routes):
    fail("web/src/titles.ts", f"{route} has a title and is not a route")
if "installTitles" not in (WEB / "src/main.tsx").read_text(encoding="utf-8"):
    fail("web/src/main.tsx", "nothing installs the titles, so every tab says the same thing")

screens = list((WEB / "src").rglob("*.tsx"))
if not any("<h1" in path.read_text(encoding="utf-8") for path in screens):
    fail("web/src", "no screen renders an <h1>")
if not any("<header" in path.read_text(encoding="utf-8") for path in screens):
    fail("web/src", "no screen renders a <header>")

print("Sitemaps and robots\n")
landing = sitemap_urls(SITE / "sitemap.xml")
game = sitemap_urls(WEB / "public/sitemap.xml")
check_robots(SITE / "robots.txt", LANDING_HOST)
check_robots(WEB / "public/robots.txt", GAME_HOST)

# A page nobody lists is a page nobody finds, and an empty sitemap is worse.
wanted = {
    name: (f"{LANDING_HOST}/" if name == "index.html"
           else f"{LANDING_HOST}/{name.removesuffix('.html')}")
    for name in PAGES
}
for name, url in wanted.items():
    if url not in landing:
        fail("site/sitemap.xml", f"{url} is a page and is not listed")
for url in landing:
    if not url.startswith(f"{LANDING_HOST}/"):
        fail("site/sitemap.xml", f"{url} is not on {LANDING_HOST}")
    if url not in wanted.values():
        fail("site/sitemap.xml", f"lists {url}, which is not a page here")
if len(landing) != len(wanted):
    fail("site/sitemap.xml", f"lists {len(landing)} pages, and there are {len(wanted)}")

if game != [f"{GAME_HOST}/"]:
    fail("web/public/sitemap.xml", f"should list {GAME_HOST}/ and nothing else, lists {game}")

# The card both hosts show is one file, and a moved file is every share broken.
for image in ("vibe-games.jpg", "ways-to-help.jpg"):
    if not (SITE / "assets/og" / image).exists():
        fail("site/assets/og", f"{image} is missing — Tools/make_og_image.mjs draws it")

# The two favicons are one mark, generated by one tool; two answers to "what does
# this site look like" is how a tab and a bookmark end up disagreeing.
if (SITE / "favicon.svg").read_bytes() != (WEB / "public/favicon.svg").read_bytes():
    fail("favicon.svg", "the landing page and the game disagree about the mark; "
                        "both come from `swift Tools/make_icon.swift`")

print()
if problems:
    print(f"{len(problems)} thing(s) to fix:\n", file=sys.stderr)
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    sys.exit(1)

print(f"SEO check passed — {len(PAGES)} landing pages, 1 game page, "
      "and the tags, sitemaps and robots files agree with each other.")
