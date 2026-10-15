# Submitting to the App Store

Everything Apple asks for that can live in a repository is here. The rest is App
Store Connect, and the list below says which is which and in what order.

One decision in here was a judgement rather than a step — **the donation link**
— and it is settled: the app names the website and links nothing. The other
thing at the bottom is not a decision but a fact to be ready for: **Similar Vibe**
cannot be played by a reviewer with one device.

---

## What is already in the repository

| | |
| --- | --- |
| **Privacy policy URL** | `https://vibegames.party/privacy` — live, and linked from inside the app |
| **Support URL** | `https://vibegames.party/support` — live, with a working feedback box, and linked from inside the app |
| **Privacy manifest** | `Sources/PrivacyInfo.xcprivacy` — ships in the bundle; says what the app collects and declares the one required-reason API it uses |
| **Export compliance** | `ITSAppUsesNonExemptEncryption: false` in `project.yml` — no question at upload and no annual report |
| **Icon** | Rendered by `Tools/make_icon.swift`; there is a test that it is square, opaque and present |
| **Screenshots** | `python3 Tools/appstore_shots.py "iPhone 17 Pro Max" iphone-6.9` and `… "iPad Pro 13-inch (M5)" ipad-13` |
| **Version** | 1.0 (build 1), in `project.yml` |
| **Devices** | iPhone **and** iPad (`TARGETED_DEVICE_FAMILY: "1,2"`), which is why an iPad screenshot set is required |
| **Not present, on purpose** | No accounts, no sign-in, no purchases, no ads, no advertising identifier, no tracking, no third-party content |

`python3 Tools/check_app_store.py` checks all of that, including that the two
URLs above are linked from the app and that the version on the support page
matches `project.yml`.

---

## What only you can do

In this order. Steps 1–4 are one-time setup; 5–11 are per submission.

1. **Apple Developer Program membership**, and the team already in `project.yml`
   (`2KBMDZ33ZL`).
2. **Agreements, Tax, and Banking** in App Store Connect: the free-apps agreement
   has to be active. A free app needs no tax or banking forms.
3. **The bundle id** `party.vibegames.VibeGames` in Certificates, Identifiers &
   Profiles, if it is not there already.
4. **Create the app record**: App Store Connect → My Apps → **+** → New App.
   Platform iOS, name **Vibe Games**, primary language English (U.S.), the bundle
   id above, SKU anything unique (`vibegames-ios`), Full Access.
5. **Paste the listing** — the copy is below, with the character limits Apple
   enforces.
6. **App Privacy** — the answers are below. They have to match
   `Sources/PrivacyInfo.xcprivacy` and `site/privacy.html`; three answers to one
   question is three chances to disagree.
7. **Age rating** — the questionnaire answers are below.
8. **Screenshots** — upload from `.build/appstore/iphone-6.9/` and
   `.build/appstore/ipad-13/`. The first three are the ones search results show.
9. **Upload the build**: `Tools/archive_app.sh` archives and exports an `.ipa`,
   then Xcode → Window → **Organizer** → Distribute App → App Store Connect →
   Upload. (`xcrun altool --upload-app` still works with an app-specific
   password, but Apple has been steering people to Organizer and Transporter for
   years, and Organizer is one click.)
10. **TestFlight yourself first.** Install the build from TestFlight and check
    the two links at the bottom of the heart panel open the pages they say they
    do — that is the only part of this the tests cannot check.
11. **Submit for review** with the review notes below. Add yourself as the
    contact; no demo account is needed because there are no accounts.

---

## The listing copy

**Name** (30): `Vibe Games`

**Subtitle** (30): `Party games in your pocket`

**Promotional text** (170): `Party games for the whole table: describe it
without saying it, name three things before the buzzer, race the same puzzle, or
take three cards that match.` — *can be changed any time without a new build.*

**Keywords** (100, comma-separated, no spaces after commas):

```
family games,word game,guessing game,puzzle,trivia,charades,group game,pass and play,offline
```

**Description** (4000):

```
Party games for the whole table, in your pocket.

Quick games you can play on your own in a spare five minutes, or pass
around a room with everyone on their own device. No accounts, no adverts,
nothing to buy, and nothing to unlock.

SIMILAR VIBE — Describe it, don't say it.
Two teams, one word, and nobody wants to be holding it. One person is shown a
word and has to get their team to say it without saying it. Get it right and a
new word passes to somebody on the other team. The other team can see the word,
and has one enormous red BUZZ button.

VIBE FIVE — Name three things before the buzzer.
A category, five seconds, and one device passed round the table. Name three
things that fit. Sounds easy until the clock is running.

WORD VIBE — Six guesses, one word.
Everyone gets the same word at the same time, and the first to solve it wins.
Coloured hints tell you how close you are, in the way you already know.

NUMBER VIBE — Fill the grid, beat the room.
The same puzzle on every screen at the same time. Take your time, or race.

VIBE PAIRINGS — Three cards that match.
Every card has four features and a trio is three cards where each feature is the
same across all three or different on all three. Find the most and you win.

WHY IT IS FREE
I built these games for my own family. We play them in the evenings, and I wanted
to share them. There is nothing to buy in the app: if you would like to say
thanks, there is a page on the website about the ways to help.

WORKS ON WHATEVER YOU HAVE
iPhone, iPad and any browser. The solo games and Vibe Five need no connection at
all — they are good on a train.
```

**Support URL**: `https://vibegames.party/support`
**Marketing URL**: `https://vibegames.party/`
**Privacy policy URL**: `https://vibegames.party/privacy`
**Copyright**: `© 2026 <your name>` — *put the name you want on the listing here;
it is the one field in this file I cannot fill in.*

**Category**: Games → **Family** primary, Games → **Word** secondary.

---

## App Privacy

Apple asks two questions per data type — is it linked to the person, and is it
used for tracking — and everything here is **no** to both. "Do you use data for
tracking?" is **No**, which is why the app never shows the tracking prompt.

| Data type | Linked to identity | Used for tracking | Purposes |
| --- | --- | --- | --- |
| Identifiers → Device ID | No | No | Analytics |
| Usage Data → Product Interaction | No | No | Analytics |
| Diagnostics → Crash Data | No | No | App Functionality |
| User Content → Customer Support | No | No | App Functionality |
| User Content → Other User Content | No | No | App Functionality |

Notes, because the form does not have room for them and a reviewer may ask:

- **Device ID** is the analytics installation identifier. There is no advertising
  identifier anywhere: the analytics SDK in `project.yml` is the
  `WithoutAdIdSupport` variant on purpose.
- **Product Interaction** is counts — which game started, solo or shared, whether
  it finished, the score, the seconds, which screen was opened. Never the words
  anybody guessed or described.
- **Customer Support** is the note somebody types in the feedback box. It is
  published as an issue on a public repository, which both the panel and the
  privacy page say in those words.
- **Other User Content** is the nickname, kept on the device and written into the
  game room so the other players can see whose turn it is.

---

## Age rating

The questionnaire answers, all of which are "no" or "none":

- Cartoon or fantasy violence, realistic violence, sexual content, nudity,
  profanity, alcohol/tobacco/drugs, gambling, horror, medical information: **none**
- **Unrestricted web access: No.** The app opens pages in Safari, outside the app;
  there is no browser inside it, and nowhere to type an address.
- **User-generated content: No** in the sense the form means — there is no feed,
  no publishing and no strangers. A nickname and a score are visible to the few
  people in the same room, for the length of the game, and the room is deleted
  within a day.

That comes out at **4+**.

---

## App Review Information

Suggested notes to paste in:

```
No account or sign-in: every game is playable immediately after opening.

Every game except Similar Vibe has a solo mode — Vibe Five, Word Vibe, Number Vibe and
Vibe Pairings — so the app can be reviewed fully on one device. Tap a game, then
"Solo" or "Play on this device".

Similar Vibe is the exception: it is two teams of two, each player on their own
device, so it cannot be exercised with one phone. The lobby says so rather than
starting a round that cannot be played. It is there for the same reason the other
four are: it is a game my family plays, and the four solo games demonstrate the
app's functionality in full.

The two links at the bottom of the heart panel (top right of every screen) are
the privacy policy and the support page. The panel also says, in plain text,
that there is more on the website — there is no link there by design.

Please write to me from the feedback box in that panel with anything that does
not work — it comes straight to me.
```

---

## One decision left, and one thing to know

### The donation link — decided

The app **names the website and links nothing**. The row that opened
`vibegames.party/ways-to-help` is gone from the heart panel, and the button that
did the same at the bottom of the hub is gone too; both now say, in plain text,
that there is more on the website and give the address. `Support.site` is the
only place that string lives.

That keeps the app clear of guideline 3.1.1 in the way that matters: there is no
button, no link and no call to action pointing at a payment mechanism. Somebody
who wants to find the page can type the address, which is the version of this
Apple has never had a problem with.

`Tools/check_app_no_payments.py` fails if a link to that page comes back — the
path `ways-to-help` is a marker, alongside `venmo`, and both are checked in code
and copy rather than in comments. `HomeUITests` checks the same thing from the
outside: the panel and the hub say where to look, neither is a link, and tapping
the text leaves the app exactly where it was.

**One residual path, so you can decide about it.** The two pages the app *does*
link — `/privacy` and `/support` — have a footer link to the ways-to-help page,
because that is the site's own navigation. So it is still two taps from inside
the app: Privacy, then Ways to help. I judge that low risk, since it is a website
navigating itself rather than the app making an offer, but if you want it
airtight, dropping that one footer link from both pages closes it — say the word.

### Similar Vibe cannot be reviewed on one device

Not a rejection by itself — four of five games are fully playable solo — but a
reviewer may ask how the fifth works. Options: leave the review notes as above
and answer if asked; record a short video of a round and put the link in the
notes; or leave it and see. A solo practice mode would remove the question
entirely, and is a real feature rather than a submission chore — worth doing
*after* this ships, not before.

---

## After it is live

The loop is not closed until the site points at the listing:

1. `Tools/make_qr.mjs` — replace the two placeholder store URLs with the real
   ones and re-run it; the landing page picks the new codes up with no change.
2. The landing page's two "Coming soon" pills can go, and the store blocks become
   links.
3. `site/index.html` structured data — add the app as a `SoftwareApplication`
   with `sameAs` pointing at the listing, which is what makes it eligible to show
   with a rating and a price.
4. The **Smart App Banner**: an `apple-itunes-app` meta tag on the landing page
   with the app's id, so a phone visiting the site offers the app.
