# Vibe Games

A native iOS party-game app plus its companion website, in one repository.

- `Sources/`, `Tests/`, `UITests/`, `project.yml` — the iOS app (XcodeGen)
- `web/` — the browser versions, at play.vibegames.party (React + Vite)
- `site/` — the marketing landing page (static HTML/CSS)
- `firebase/` — Realtime Database rules shared by both clients

The shell is a hub with four playable games.

| Game | Players | Backend |
| --- | --- | --- |
| **Vibe Five** — name three things before the buzzer | Pass one phone around | None |
| **Word Vibe** — guess the five-letter word | Everyone on their own phone | Firebase Realtime Database |
| **Number Vibe** — fill the grid | Solo, or a race on the same board | Firebase Realtime Database |
| **Vibe Pairings** — find three cards that agree on every feature | Solo, or a race on the same table | Firebase Realtime Database |

## Vibe Five

Name three things that fit the category — you have five seconds.

The one button carries the whole loop: **START → START → Done! → NEXT**. The clock
never starts on its own — you start it when the table is ready.

1. Press **START**. The category appears, filling most of the screen, with a
   `GET READY` badge. **No timer runs and none is shown** — read it out, explain
   it, argue about it for as long as you like.
2. When everyone is ready, press **START** again. The dial appears and drains
   `5 → 0`, with ticks for the last three seconds — the dial appearing *is* the
   signal that time is now running. The button now reads **Done!**.
3. The round ends either way:
   - **The clock runs out** — the buzzer sounds, the screen flashes red, and a jolt fires.
   - **The player presses Done!** to end it early. This is deliberately silent, because the
     buzzer means the clock beat you. The dial freezes on however many seconds were left,
     so the group can see how much time they had to spare.
4. The button now reads **NEXT**. Press it to deal a fresh category, which again
   waits for you to start the clock.

The category stays hidden until you press Start, so nobody can read ahead. Rounds are
dealt from one shuffled deck so no category repeats until the pool is exhausted.

### Category packs

Eleven packs, all toggleable in Game Setup. The deck is built only from the packs
you leave switched on.

| Pack |
| --- |
| Everyday Life |
| Food & Drink |
| Animals & Nature |
| Movies & Cinema |
| Music |
| TV & Streaming |
| Places & Travel |
| Sports |
| Games & Play |
| People & Jobs |
| Random & Silly |

Categories get retired from time to time, so the packs are deliberately not a
fixed size and no count is quoted here to go stale. `python3 Tools/check_packs.py`
re-validates them — no pack below its floor, no duplicates within or across
packs, word counts and formatting. Run `python3 Tools/make_web_packs.py` first if
you have edited one, so the web copy is regenerated from the Swift source.

Sound and haptics can be switched off independently. Preferences persist in
`UserDefaults`.

Haptics are also gated by the phone, and silently: **Settings → Sounds & Haptics
→ System Haptics** switches off every app's haptics at once, and no API can read
that setting, so a cue nobody feels is indistinguishable from a cue that was
never written. That is what made the time-up buzz look broken when it was the
setting. The Simulator has no Taptic Engine at all either, which is why no test
covers the feeling — only that the code asked for it. `Sources/Audio/Haptics.swift`
holds one continuous half-second buzz for exactly this reason: the older impact
generators fire for about 15ms, which reads as a click, not an alarm.

## Word Vibe

Guess the five-letter word in six tries. Play solo on one phone, or start a game
and have everyone guess the same word on their own device — first to solve it
wins.

- **14,855** guessable words, **489** of which can be the answer.
- Green means right letter, right place; amber means right letter, wrong place.
- Repeated letters are scored properly: exact matches are claimed first, then
  remaining letters are matched against what is left of the answer. Guessing
  `EERIE` against `SPEED` credits two `E`s and marks the third absent.
- Solo play needs **no backend at all**. Multiplayer is what needs Firebase.

### Playing with friends

The host taps **Start a game with friends** and shares the code — two short
words, `cars feed`, because it gets read out loud across a room.
Everyone else taps **Join with a code**. Players disappear automatically when
they leave, and a round ends with a countdown before the next word.

Codes are two four-letter words rather than eight characters of noise because
they are said out loud and typed in by somebody who only heard them. What is
typed is forgiven: capitals, a hyphen (`cars-feed`), a space (`cars feed`) and
the two words run together (`carsfeed`) all resolve to the same room, and the
same shape works in all four games that have one. Digits are kept rather than
stripped, so a code from before the words changed still names the room it named.

What is **shown** is the two words a space apart — `CARS FEED`. The separator is
a reading aid rather than part of the code: it is what stops `carsfeed` reading
as one long noise, and it is not something anybody has to reproduce, because
nothing that is not a letter survives the trip into the room. `GameCode.display`
and its web twin `displayGameCode` are the only places a code is laid out for a
screen.

The vocabulary is shared, which is not automatic — a code made on a phone has to
be joinable in a browser. `Sources/Model/GameCodeWords.swift` is the single
source of truth and `Tools/make_web_game_codes.py` mirrors it into
`web/src/lib/gameCodeWords.generated.ts`; regenerate after editing the list.
`web/src/test/gameCode.test.ts` reads the Swift list directly and fails if the
two ever disagree.

The iOS client shares its **exact Realtime Database schema** with the existing
web version, so a web player and an iOS player can sit in the same game — once
both point at the same Firebase project.

The backend is **provisioned and live** on the `vibe-words-party` project, with
its rules deployed and `Sources/GoogleService-Info.plist` in place (that file is
git-ignored — see [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for how to recreate it,
or run `Tools/firebase_setup.sh`).

> **Not yet done:** the web client still points at its original project, so
> web ↔ iOS cross-play will not work until you repoint it. That is a `.env.local`
> change and a redeploy — section 6 of the setup guide.

Multiplayer is optional by design: if `GoogleService-Info.plist` is ever missing,
the app still runs, the lobby offers solo play, and it explains why the
multiplayer options are unavailable.

> **Naming.** This app must never use the trademarked name of the game it was
> inspired by. `Tools/check_branding.py` enforces that — it scans sources,
> config, filenames and docs, and fails the build if the term appears. It matches
> substrings deliberately, and that caught a genuine slip during development: an
> internal constant whose name happened to contain the forbidden string.

### Word data

`Tools/import_words.py` regenerates the bundled dictionary from the original web
project's TypeScript list:

```sh
python3 Tools/import_words.py /path/to/web-project/src/wordList.ts
python3 Tools/check_packs.py       # Vibe Five content
python3 Tools/check_blurt_words.py # Similar Vibe words, including the American spellings
python3 Tools/check_branding.py    # naming guard
```
## Number Vibe

Fill a 9x9 grid so every row, column and 3x3 box holds 1–9. Play solo at the
difficulty you choose, or race friends on an identical board.

- **Infinite puzzles, nothing stored.** A puzzle is a pure function of a
  `(seed, difficulty)` pair, so there are ~4 billion boards and a shared game
  sends a single number instead of 81 digits.
- **Only the seed is in the database.** The solution is never written, so unlike
  Word Vibe there is nothing for a client to read out of the backend.
- **Difficulty applies to solo and to games you host**: Easy / Medium / Hard.
  Guests race whatever the host picked, so everyone still gets the same board.
- Notes mode with pencil marks, clash highlighting, and a running timer.

### A note on difficulty

Tiers are **graded by the solving technique required**, not by clue count. The
generator carves a candidate, grades it with a human-style solver, and keeps
carving until the grade matches — so the tiers mean something.

| Tier | What it takes |
| --- | --- |
| Easy | Naked and hidden singles only |
| Medium | Locked candidates, naked/hidden pairs, naked triples |
| Hard | X-Wing or XY-Wing — or a grid that cannot be finished without guessing |

`SudokuGrader` implements those techniques and reports the hardest one a puzzle
needs. This is deliberately more work than counting clues, because clue count is
a poor proxy: a 34-clue grid very often still falls to singles, which is how
"hard" ends up being merely sparse. In practice Easy lands near 44 clues, Medium
26–31, Hard 22–26.

Generation costs roughly 15 ms for Easy and 250 ms for Hard — a single carve,
graded as it goes. Every board is still verified to have exactly one solution.

## Playing in a browser

**play.vibegames.party** is a menu. It used to be Word Vibe and nothing else,
because Word Vibe was the only game with a browser version — going there and
getting a word grid *was* the site. Each game now has its own path:

| Path | Game | State |
| --- | --- | --- |
| `/` | the menu | live |
| `/words` | Word Vibe | live |
| `/trio` | Vibe Pairings | live, solo and shared |
| `/five` | Vibe Five | live — pass the phone |
| `/sudoku` | Number Vibe | live — solo and raced |

Anything the router does not recognise falls through to the menu, so an old
bookmark to the root still lands somewhere useful rather than on a 404. The
router is thirty lines in `web/src/router.ts` — four screens behind a catch-all
rewrite do not need a routing library, and the games keep their shared-game id in
the query string, which is the part that actually needs preserving.

A shared game is a query string, the same as it always was:
`play.vibegames.party/trio?game=cars-feed`.

### Vibe Pairings in a browser, and why the shuffle is not a detail

The browser talks the **same schema as the app** — `trio/{gameId}` with `meta`,
`players` and `taken` — so a browser and a phone can sit in the same game. That
only works if both build the *identical* board from the same seed, and the board
is a pure function of the seed and the taken cards, so any disagreement about the
shuffle is two players looking at different tables while the score says otherwise.

That makes the shuffle load-bearing rather than incidental. Swift's
`Array.shuffle(using:)` is forward Fisher–Yates drawing bounds by multiply-shift;
`next() % bound` is also a correct shuffle and produces a *different* board for
the same seed. `Tools/trio_fixtures/` runs the Swift engine and dumps the deck
order, the opening table and a full play-out for seven seeds;
`web/src/test/trioEngine.test.ts` replays them through the TypeScript engine and
fails if the two ever disagree. Regenerate the fixtures after touching
`TrioCard.swift`, `TrioEngine.swift` or `SeededGenerator.swift`.

The card faces are not shipped twice. `Tools/make_web_cards.py` derives 512px,
256-colour copies from the 900px masters in `cards/` into `web/public/cards/` —
75MB down to **5.2MB**, which the browser fetches lazily, one per card actually on
the table. 512 is measured, not guessed: the largest a card is ever drawn is
484px, on a 13-inch iPad in portrait.

### Vibe Five in a browser

The odd one out: Vibe Five has no database behind it, in the app or on the web,
because it is one phone handed round a table. Nothing about it is shared.

Its categories live in `Sources/Features/VibeFive/Packs/` as Swift and stay
the single source of truth — the app and the browser must offer the same prompts,
and a second hand-maintained copy would drift.
`Tools/make_web_packs.py` generates `web/src/games/five/prompts.generated.ts`
from them; regenerate after changing a pack, and `Tools/check_packs.py` validates
the content itself.

The sounds are synthesised rather than shipped, as they are in the app:
`web/src/games/five/sound.ts` ports `SoundEngine.swift` to Web Audio, down to the
low-pass filter that stops the stacked square waves of the buzzer from hissing.
Its tests check the arithmetic produces real, in-range, non-silent audio, because
a NaN sample would fail silently as "no sound".

### Number Vibe in a browser, and the hardest thing to port

A shared race stores **only a seed** — never the board — so the answer is never
sitting in the database for a client to read, and both devices generate the
puzzle from that one number. Which means the generator has to be ported exactly,
not approximately.

That is a taller order than the Trio shuffle. Carving removes clues one at a
time, checking after each removal that the puzzle still has exactly one solution
and re-grading what is left; a single difference anywhere changes which clue goes
next, and the two players end up racing different boards while the screen says
otherwise. The grader sits underneath that — eight human techniques applied
easiest-first, from naked singles to X-Wings and XY-Wings — and it decides when
carving stops.

`Tools/sudoku_fixtures/` dumps the Swift generator's output for seven seeds
across all three difficulties, including the clue count and the grade;
`web/src/test/sudokuGenerator.test.ts` regenerates each one and fails if the
givens, the solution, the clue count or the grade differ. Twenty-one boards,
matched exactly.

One thing that is **not** a bug, and reads like one: hitting the requested grade
is best-effort. Generation tries a handful of carve orders and keeps the closest
miss. Measured over forty seeds it lands exactly on easy 40/40, medium 31/40 and
hard 39/40 — and the fixtures show the iOS generator behaving identically, so it
is the intended shape rather than a porting slip. It never lands more than one
grade away.

The web build also fixes a real bug the app still has: arriving at a shared link
set the game id without registering the player, so they could see the board and
nobody could see them. And the winner is recorded with a transaction rather than
a read-then-write, so two people finishing on the same tick cannot overwrite each
other.

## Vibe Pairings

**The screen calls this a good pairing; the code and the database call it a trio.**
The game's name changed and its identifiers did not, and the type names *are* the
identifiers — `TrioTable`, `TrioCard`, `trio.leaderboard`, the `trio` tree. This
section uses "trio" for the thing itself, because that is what everything below
the UI calls it.

Twelve cards are face up, each a charcuterie board. A card varies along four
features, three options each, so there are 3⁴ = 81 cards:

| Feature | Options |
| --- | --- |
| **Platter** | round walnut, bamboo hexagon, slate rectangle |
| **Cheese** | swiss wedge, gouda cubes, brie round |
| **Meat** | prosciutto ribbon, salami stack, turkey roll-up |
| **Garnish** | purple grapes, red strawberry, pear slices |

Three cards make a trio when every one of those four features is *either the
same on all three or different on all three*. Two matching and a third odd is
not a trio, which is exactly the mistake the game is built to punish.

- **The whole game is one seed.** Deck order, the opening twelve and the order
  replacements arrive all derive from a single number, so a shared game sends a
  seed and a list of takes — never a board.
- **It deals out of dead ends.** If the table has no trio and the deck still has
  cards, three more are dealt automatically, so the game can never stall.
- **Which means the opening table is not always twelve.** The first twelve cards
  occasionally hold no trio, and then a row is dealt before anybody sees it.
  Across 20,000 seeds, 622 — about one in thirty-two — open larger: 15 cards for
  most, 18 for a few. The table is therefore 12 + 3n and never unplayable. A test
  asserting a flat twelve passes most runs and fails about three times in a
  hundred, which is exactly often enough to be written off as flake, so the
  engine is checked across a run of seeds instead.
- **One board, shared.** A race is not two people playing the same deal side by
  side: it is one table, and a trio taken by anybody is gone for everybody. The
  board is rebuilt from the seed plus the takes the server accepted, in the
  server's order, so the three cards vanish where they stand and nothing slides.
- **The win is settled by the database, not by a clock.** A claim is a Realtime
  Database transaction, so two phones reaching for the same cards at the same
  instant produce one winner and one `Someone got there first!`. No phone's
  timestamp is consulted anywhere.
- **Solo clears the deck; a race ends when the deck does.** The last trio on the
  table ends the game for everyone at once, and the end state is a leaderboard:
  each player's name against the number of takes carrying their id, ties level at
  the top. Only people who scored are listed, because only a take carries a name
  — and taking two when the whole table is hunting is worth a trophy.
- **A hint for solo play** lights up *one* card of a trio, leaving the other two
  to find. Races have no hint at all — the button is not drawn, and the model
  refuses one anyway, because the game there is who spots it first.
- **A rejection flash** for wrong trios, and a synthesised tone on each hit.

### The card faces are drawings, not code

All 81 faces are drawn PNGs in `cards/`, one per combination, named
`card-NN_<platter>_<cheese>_<meat>_<garnish>.png` with the garnish varying
fastest. `TrioCard.imageName` derives that name from the card's own features
rather than keeping a second list that could fall out of step, and
`TrioArtworkTests` checks all 81 resolve to a real image in the bundle.

The folder is a **folder reference** in the bundle rather than 81 loose files at
its root, which means SwiftUI's `Image(_:)` cannot find them — it searches the
asset catalog only, and draws an empty view for a name it does not know without
saying anything in the app. The card loads its `UIImage` explicitly instead, and
shows a visible placeholder if the artwork is missing rather than a hole in the
board.

The artwork arrived 900 × 1260 with the platter marooned in the middle — 160px of
empty cream above it and 163px below, a quarter of the card doing nothing. It is
now cropped to 900 × 1153 and the layout is fitted to it.

The trim is a three-slice cut, not a rescale: the top cap (shadow, border and
the rounded corners), a band of cream, the platter, another band, then the
bottom cap. Removing rows from the cream bands leaves the border's straight
sides untouched, so the seams are invisible — but the corner is a much shallower
curve than it looks, only reaching vertical 120px down, and cutting inside that
leaves a visible step. `Cards were trimmed` notes the row bounds.

**The whole table is always on screen.** It used to be three across inside a
scroll view, which had the table running off the bottom of an iPad — on the
biggest screen, with the most room, you could see the fewest cards, and a puzzle
about twelve boards at once is not the same puzzle when you have to scroll to see
half of them. `TrioBoardLayout` measures every arrangement from one column to one
per card and takes the one that leaves the cards largest, so a phone gets three
across, a 13-inch iPad gets four, and that iPad in landscape gets six. `UITests`
checks the resulting frames really are inside the window rather than trusting
that the cards merely exist.

That layout also decided the artwork size, by measurement rather than guesswork:
the largest any card is ever drawn is on a 13-inch iPad in portrait, where the
four columns come out at **484px** across. The shipped art is 900px, so it carries
close to twice the pixels the biggest screen can use.

Which means the bundle can come down without anyone seeing it. Measured on all
81 files (75.3MB of artwork; the app bundle is 83MB):

| Card files | Artwork | App bundle |
| --- | --- | --- |
| 900px, as shipped | 75.3MB | 83MB |
| 512px — above the 484px the largest screen asks for | 25.7MB | 37MB |
| 512px, 256 colours | **5.2MB** | **16MB** |
| 900px, 256 colours | 14MB | 22MB |

Downscaling first and quantising second is much better than either alone, because
the resample smooths the gradients until 256 colours can carry them: the palette
costs a mean **37.3 dB** at 512px, against 37.9 dB at full size. Both are changes
to shipped artwork rather than to code, so they are left as decisions rather than
done.

### How to play is a page, not a paragraph

The rules used to sit on the lobby as a block of text, which everyone who already
knows them has to scroll past every time — and each of the five games did it
differently. Vibe Pairings had a page, Similar Vibe had four paragraphs in the lobby,
Word Vibe had a single line under the buttons, and Number Vibe and Vibe Five had
nothing at all. All five now have one **How to play** control on the main page,
opening one page.

They are not five similar pages. `GameInstructions.swift` holds the shell — the
back button, the `HOW TO PLAY` heading with the game's name under it, the intro,
the section spacing, the bullet list — and each game supplies only its words, as a
`GameInstructions` value. Vibe Pairings is the one whose page is diagrams rather than
prose, so it passes its own sections in; everything around them is still the
shell, which is what stops the five drifting apart again.

Three of the four openers are the same card; Vibe Five's is a quiet line of text,
because it is the one game with no lobby — its main page is a round in progress,
and a card there would push the game around for something read once.

The counts in the pages are read from the games rather than typed out: Word Vibe
says how many words it actually has, Similar Vibe how many it has to describe, Vibe
Five how many categories. A page that quotes a stale number is worse than one that
does not quote it at all.

Trio's examples are `[TrioCard]` values, not file names, and
`TrioInstructionTests` checks them against the engine: the trio really is a trio,
the near miss really is not, and it really does fail on the meat and nothing
else. A page that teaches the wrong rule is worse than no page.

`InstructionsUITests` walks the same path in all five — the game on the hub, the
opener, the page, the way back — because that sameness is the whole point of it.

The browser has the mirror of it: one `HowToPlay` component and one
`HowToPlayLink`, with each game passing its own words in. `Trio`'s rules were the
only hand-written page there, and they are now the same component as the rest.

### One table, and who got there first

A race keeps three things, and no board:

```
trio/{gameId}
  meta/       seed, creator, createdAt, started, restartTime
  players/    {shortId}: true        — presence, cleared on disconnect
  taken/      {cardId}: { seq, by, name }
```

A `taken` entry is one card, and the three cards sharing a `seq` are one take.
`seq` is assigned by the server inside the transaction that accepts the claim —
`max + 1` over what is already there — which is what makes the order of takes the
server's rather than any phone's. Rebuilding the board is then a pure function of
two things every device already has:

```swift
TrioTable.replay(seed: seed, takes: snapshot.takeIDs)
```

so the same twelve cards land in the same places everywhere, a take replaces
three of them where they stand, and no card position is ever transmitted.

The claim itself is a **transaction**, not a timestamp comparison. Two phones
reaching for the same trio at the same instant both run the block; the server
keeps the first result and re-runs the second against it, where the block finds
the cards gone and aborts. That is what produces exactly one winner without a
Cloud Function — and it works on the free Spark plan, which has no functions at
all.

The score is derived, never stored: group `taken` by `by` and count. Only takes
carry a name, which is why the leaderboard lists scorers and not the roster, and
the header lists a **count** of everyone present — read from `players`, the only
thing the roster is used for here.

`taken` and `players` are observed with `.childAdded` and `.childRemoved`, never
`.value`: both nodes only ever grow, and a `.value` observer on a hundred-player
game would re-send the whole tree on every take.

Two things follow from where the rules draw the line. A modified client can claim
a trio that is not one, because the transaction block runs on the device and the
server can only check the rules and that the value it handed the block is still
current; and nothing in the app can *delete* a game — the rules grant writes to
whoever gets there first and never a delete, so one phone cannot wipe a game out
from under the table. Cleanup is an administrator's job:

```sh
python3 Tools/prune_games.py              # report games older than a day
python3 Tools/prune_games.py --apply      # delete them
python3 Tools/prune_games.py --hours 6 --apply
```

It reuses the Firebase CLI's credentials, which carry owner rights and so bypass
the rules, and it reports unless `--apply` is given.

### Cards are spoken

Every card renders with an `accessibilityLabel` such as "round walnut platter,
swiss wedge, prosciutto ribbon, purple grapes". That is not decoration: the UI
test reads the board back off the screen, parses those labels, works out a real
trio with the game's own rule, and taps it. If the renderer and the engine ever
disagree about what a card *is*, that test fails.

## Similar Vibe

The fifth game, and the only one that does not work on your own. Everyone joins
on their own phone; the app splits the room into two teams at random and hands
one person at a time a word to describe without saying it.

Two on each side at least — four people — and the word is a hot potato:

- **One person describes; their team-mates guess.** The word reaches the
  describer's screen and nobody else's on that side.
- **Getting it passes the word to the other team**, to the next person in the
  rotation, with a new word. **The clock does not stop or reset** — it belongs to
  the round, not to the word.
- **The word goes round everybody, alternating sides, in the same order every
  time.** One member to the next, team to team, until the clock runs out.
- **The point goes to the team *not* holding the word when the clock stops.**
  Nobody scores for guessing; guessing only gets rid of the word, which is the
  whole game.
- **First to seven.**

That makes the end of the round the tense part, and the app is built so it is
tense on every phone rather than only on the describer's. It cannot be counted
either: there is no number, the bar is spent with a sixth of the round still to
play, and the ticking hurries for the last 15%. See
[How long a round lasts](#how-long-a-round-lasts).

### The other team sees the word

Which is the point of the BUZZ button. The team that is *not* holding the word is
shown it, so catching somebody saying it is a judgement they can actually make
rather than a guess from one word of a sentence. They get one enormous round red
button. Pressing it ends the round at once and pays them instead of the team
holding the word — and two people pressing at the same moment still score once,
because ending a round is a transaction.

The one screen in the room the word must never reach is the holding team's own
guessers, who are the only people actually trying to guess it.

### The word is never sent anywhere

This is the part worth knowing, because it is what makes the game work at all.
A room stores a **seed**, a **round** and which **packs** are on — never a word.
Every phone derives the same deck from those, and only the describer's screen
renders the current entry. It is not hidden in the payload; it is not in the
payload. Same trick as the Trio table and the Sudoku grid.

The *rotation* is derived the same way — from the seed, the teams and a step
counter — so no device has to be told whose turn it is; they all work it out and
agree.

Which is why the settings live in the room rather than on the phone. The deck
depends on the seed *and* the packs, so two devices disagreeing about which packs
were ticked would deal two different decks while the score ticked along — the
describer describing one thing and every other screen scoring another. Pack
*order*, not the order they were ticked in, decides the deck, for the same
reason.

### Ends are transactions

Ending a turn awards a point, checks for a winner and sets up the next turn, and
all three have to happen together or two people shouting "they said it" at the
same moment would both be paid. It is one Realtime Database transaction on the
`play` node, so the server decides which press counted. The clock running out
goes through the same transaction, which is why any phone can call time and why
the turn still ends if the describer's app has gone to sleep.

### Nobody gets the same word twice

Which took finding a real bug, and the bug was not in this game at all.

"Play again" used to deal from a fresh shuffle of the whole library, which looks
random and is not good enough: ten words out of a few hundred twice shares one or
two, which people notice and say so. Deriving the second shuffle from `seed + 1`
was meant to fix that and made it dramatically worse — measured at **10 of the
first 20 words shared, against 1.3 by chance**. (That was against the 300-word
library of the time; with the current one the chance is nearer a fifth of a
word.)

The cause was `SeededGenerator`, shared by every game in the suite. Its
constructor pre-scrambled the seed (`seed * gamma + constant`) and `next()` then
added the gamma again, so seed `n + 1` replayed seed `n`'s stream **one draw
late**. Two shuffles of the same list were therefore nearly the same shuffle.

It only showed up in Similar Vibe because it is the only game that derives a second
shuffle from a related seed — Trio and Sudoku use one seed per game, where a
shifted stream is invisible. The constructor now does what SplitMix64 actually
says: the seed *is* the state, and `next()` does the add-and-mix. Adjacent seeds
now share 1.25 of 20 words, which is chance.

On top of that, a room now has **one deck**, walked from end to end across as many
games as the table plays, rather than a fresh shuffle per game. Vibe Five does the
same thing in its own way: it remembers every prompt it has dealt, in
`UserDefaults`/`localStorage`, and leaves them out until the pool is genuinely
used up — so a second game cannot deal the first one's cards even if the pool is
a single pack.

Changing the generator changed every seeded board in the suite, so the fixtures in
`Tools/trio_fixtures`, `Tools/sudoku_fixtures` and `Tools/blurt_fixtures` were all
re-dumped from Swift and the browser tests re-checked against them.

### 2,272 things to describe, in eight packs

Food and drink, animals and nature, places and travel, household things, jobs and
people, sport and music, actions, and celebrations and weather. Written for this
rather than borrowed — the physical game's list is somebody's copyright, and the
name is kept out of the code and UI for the same reason the other one is.

**They are American words.** The list was first written in British English by
accident, which is how it came to contain `Wellies` and `Suncream` — words a
player in Ohio cannot describe to anybody, because the thing has a different name
there. So the packs are checked rather than trusted: `Tools/check_blurt_words.py`
fails on a British-only name (`postman`, `car park`, `fairy lights`), on a
British spelling (`colour`, `realise`, `centre`, `grey`), on a trademark, and on
an entry that is not 1–4 words or that contains its own pack's theme word. The
awkward part is that the two languages share thousands of words — `tap`, `vest`,
`pudding`, `chips` and `rubber` are all ordinary American words that mean
something else over there — so those are printed as advisories for a person to
read rather than failed automatically.

### Leaving, and coming back

A phone that goes away — closed, slept, lost signal — disappears from the room.
Presence is the set of live entries under `players/`, and `onDisconnect` clears a
player's own when the socket drops, so there is no heartbeat to go stale and no
counter to get out of step.

**Presence is not a one-off write, and that is not obvious.** Writing it at the
join is enough to look right and is not enough to be right: the entry is cleared
the moment the socket drops, and nothing puts it back. A phone that slept and
woke up was therefore present and connected but invisible — the room kept its team
slot, the scoreboard read "Someone", and the rotation walked straight past it, so
that phone never had a turn again for the rest of the game. Both clients now watch
`.info/connected` and re-announce themselves on every reconnect, which is
Firebase's own presence pattern and also fires once on open.

The trap inside the trap: the reconnect write needs the player's *name*, and the
listener that does it is registered before somebody who joins by link has typed
one. A write with an empty name is refused by the rules (`length >= 1`) — and a
refused write is silent, so it looks exactly like a reconnect that never
happened. The browser rebuilds the listener when the name arrives, and refuses to
write without one rather than firing a request that cannot succeed.

**The team list is deliberately not cleaned up with it.** `teams/` is what
remembers which side somebody was on, so coming back with the same code puts you
straight back where you were rather than reshuffling you. The identity is the
same because it is derived from the device and the game code, not from anything
the server holds.

That leaves three places where the team list and the room disagree, and all three
ask the same question: who is *here*?

- **Whose turn it is.** The rotation is walked over the whole team and the
  missing are taken out of the order. Standing somebody in for them instead looks
  equivalent and is not: the stand-in also holds the turn after, so they would
  describe twice in a row. Taking them out keeps everyone else's turn and gives a
  returning player their own place back.
- **Which side is short**, when somebody new arrives. Counting the departed puts
  them on a side that already has a full bench — the room reads two-a-side while
  one side has one player actually holding a phone.
- **A round nobody can start.** Nothing is running before the clock starts, so no
  clock will end a round whose describer has left, and nobody else can start it.
  When the named describer is not in the room, the next person on their team is
  offered it, and whoever starts is written down as the describer — so the word
  lands on the phone that is actually there.
- **Who is holding the word.** The round writes down a describer when it starts,
  and a phone that leaves afterwards does not rewrite it — so the turn can be
  pointing at somebody who is not in the room. `BlurtRules.holder` resolves the
  holder on every snapshot instead: the named describer while they are here, and
  the rotation's choice among the people still here once they have gone. Left at
  the raw field, a round whose describer walked out is a round nobody can play —
  the other team is shown the word and told to watch for a person who is not there,
  and the describer's own team-mates are told that person is describing to them.
  Nobody can buzz, nobody can guess, and nothing ends it early but the clock.

  It is *derived* rather than written, so both clients resolve it to the same
  phone without a write to race over — the fixtures in `Tools/blurt_fixtures/`
  hold the browser to the Swift rule. The caught-buzz comparison looks back
  through it as well, or a buzz on a round whose word has moved would land on a
  phone that has gone.

- **What the scoreboard says.** The names under each side are the people in the
  room, not the people the team list remembers. A slot with nobody in it has no
  name, and giving it one put "Alex, Someone" on a scoreboard of one — which the
  browser version of this game really did ship; the app's `names(on:)` had always
  filtered through presence, and the web's `namesOn` now does the same. A side
  that has emptied out shows no names at all rather than an empty line.

**The code is reachable from a game already in progress**, which is when a late
arrival actually turns up. It used to be out of reach: the big "read this out"
card lives in the lobby and the join field only exists before a game starts, so
the moment a round began the room had no way to say how to get into it. The board
now carries the code behind one icon in the header, on both clients, and it is
the same sheet that shows it — one place that decides how a code looks.

`Tools/blurt_presence_e2e.mjs` covers all four against the deployed site and the
real database — a leaver and a returner, a round in progress when the holder
goes, a round nobody can start, and a connection that drops and comes back under
a live page. It exists because none of this is visible in
a single client: presence is a property of the room, and every one of these bugs
looked right on the phone that stayed.

### How long a round lasts

A round is a random **50 to 70 seconds**, drawn by the phone that starts it and
written into the round's end time. Every other phone reads the length back out of
`startedAt` and `endsAt` rather than being told, so there is nothing to agree on
and nothing to go stale.

There is no number on screen, because a length a table knows is a length a table
counts down out loud. The bar is not a countdown either: it fills with the last
15% still to play, so the bar running out is not the buzzer and cannot be read as
one. What says "nearly" is a tick that stays steady for the first 85% of the round
and then closes in on itself and gets louder. The browser has no sound here, so it
gets the same information from the bar changing colour and pulsing.

`BlurtTiming` holds all of it as pure functions of `remaining` and `total` —
`urgency`, `barFill`, `tickInterval`, `tickVolume` and the whole `tickSchedule` —
and the browser's copy is pinned against Swift's by the fixtures, all 69 ticks of a
60-second round included. The ticks are absolute offsets from the round's shared
start rather than a chain of waits, which is what stops one phone's rhythm
drifting from another's and what lets a phone that joins mid-round fall in with
the table instead of starting its own.

## Building

The Xcode project is **generated** — `project.yml` is the source of truth, so
regenerate after adding or removing files:

```sh
brew install xcodegen        # once
xcodegen generate
open VibeGames.xcodeproj
```

Or from the command line:

```sh
xcodebuild -project VibeGames.xcodeproj -scheme VibeGames \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Deployment target is iOS 17.0; it builds against the iOS 27 SDK.

### Running the tests

```sh
Tools/test.sh            # unit tests, then the functional UI tests
Tools/test.sh --all      # everything, including the screenshot fixtures
Tools/test.sh --unit     # unit tests only, about 30 seconds
```

`Tools/test.sh` is a thin wrapper over xcodebuild, and the default skips the eight
tests whose only job is to shoot the landing page's screenshots. Those are the
slowest tests in the suite — the Vibe Pairings leaderboard pair plays two complete
games of two dozen rounds each, and the pair alone is 100 seconds of the run.

The underlying command, if you want it directly:

```sh
xcodebuild -project VibeGames.xcodeproj -scheme VibeGames \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

**What the time goes on**, measured from the test logs rather than guessed at,
because the obvious levers do not work: a UI test method spends about six seconds
launching the app and setting up the automation session before it asserts
anything, and about half a second per interaction after that. Running them in
parallel across four simulator clones was *slower* (717s against 644s serially —
four simulators do not fit on one Mac), and making the Trio board's one-second
spring instant changed nothing, because XCUITest does not wait on SwiftUI's
implicit animations. Reading the Trio board with one query instead of 24 was real,
and is worth a few seconds. Beyond that, the only lever is running fewer tests.

- `Tests/VibeWordsTests.swift` — 30 unit tests covering the scoring rules
  (especially repeated letters, where a naive implementation gets it wrong), the
  shared database payload shape, and the backend configuration state.
- `Tests/GameCodeTests.swift` — 13 unit tests on the code that shares a game, now
  two four-letter words (`cars-feed`) rather than eight characters of noise. The
  words are checked to be four lowercase letters drawn from the list, never the
  same word twice, and the forgiveness is checked with the ways people actually
  type a code they only heard: capitals, an added or forgotten hyphen, a stray
  space. What is displayed is checked to be two four-letter words a space apart —
  and to be accepted straight back, because a display nobody can type in is
  worse than no display. A code from before the words changed is left alone
  rather than silently becoming a different room.
- `Tests/SudokuTests.swift` — 19 unit tests. The generator gets the most
  scrutiny because it is the part that can be quietly wrong: determinism from a
  seed, that every solution is a legal grid, that the givens agree with it, that
  the givens admit **exactly one** solution, and that generation is fast enough
  to run interactively.
- `Tests/SudokuGraderTests.swift` — 8 unit tests, one per solving technique, so
  the difficulty tiers cannot silently collapse into each other.
- `Tests/VibeTrioTests.swift` — 31 unit tests. The trio rule itself is
  brute-forced against the deck: every one of the 85,320 card triples is checked
  against an independent implementation, the deck is checked for the 81 unique
  cards, and the table is checked never to stall and to stay deterministic from
  its seed. The rest guard the shared table: that replaying the recorded takes
  reproduces the whole game card for card, that a take which lost its cards is
  refused, and — because this one shipped as a bug — that a trio is judged from
  **card ids** and not from positions, which is invisible whenever the three ids
  happen to be small.
- `Tests/TrioBoardLayoutTests.swift` — 8 unit tests on the board fitting every
  card on screen. The cases are the screens it has to survive — an iPhone in
  landscape, an iPad in Slide Over, a 13-inch iPad either way — and the assertion
  is arithmetic: the grid the layout chooses, at the card size it chooses, has to
  come out inside the space it was given. It also checks that no other column
  count would have been bigger, so the board cannot quietly shrink.
- `Tests/VibeTrioModelTests.swift` — 6 unit tests that play solo games all the way
  out, so the end state is exercised without a network: the wrong trio flashes and
  scores nothing, a full deck ends on a leaderboard of one, and "play again" deals
  a fresh game with the score back at zero.
- `Tests/TrioArtworkTests.swift` — 4 unit tests. All 81 cards resolve to a real
  image in the bundle, the file numbering runs in deck order, and no two cards
  read out the same. A card whose artwork had gone missing would render as a
  placeholder, which is the sort of thing that is easy to ship and hard to see.
- `UITests/` — 47 UI tests driving the real screens in a simulator, attaching a
  screenshot at each step to the result bundle. Four of them exist to shoot the
  landing page in both appearances — a board, and the leaderboard the game ends on
  — so the screenshots and the tests cannot drift apart.

**237 tests in all: 190 unit and 47 UI.** They are what the numbers above are
worth — the grade-matching figures, the 85,320 triples, the fixture agreement
with iOS — because each of those is measured by a test rather than asserted in
prose.

Four tests talk to the **real backend** (creating a shared Word Vibe game, a
shared Sudoku game, a shared Vibe Pairings game, and taking a trio and rejoining to
find it still gone) and skip themselves when Firebase is not configured, so a
checkout without the config file still gets a green suite.

Two **browser** scripts go further and play whole games against the real
database — `Tools/blurt_e2e.mjs` with four players in four browser contexts, and
`Tools/words_e2e.mjs` for the one web game with no other end-to-end coverage.
Both take `SITE` so they can run against a local build before deploying:

```sh
cd web && npm run build && npm run preview
SITE=http://localhost:4173 node Tools/words_e2e.mjs
```

The **daily cleanup** in `functions/` has its own tests, which need no database
and no credential — they are about which rooms are old enough to delete:

```sh
cd functions && npm test
```

One Vibe Five test sits on a revealed category for six seconds — longer than a
whole round — and asserts that nothing starts by itself. One Word Vibe test
guards the keyboard feedback: it cannot know *which* verdict a letter gets,
because the answer is random, but it asserts that every guessed letter gets one
— which catches the bug where "not in the word" rendered identically to
"not tried". The Vibe Pairings tests read the cards back off the screen and solve a
trio with the game's own rule, which is what keeps the renderer honest; another
asserts a shared table stays face down until the host starts it.

## Installing on your iPhone

The project signs automatically but ships with no team set, so you need to wire up
your own Apple ID once.

**1. Sign Xcode in to an Apple ID**

Xcode → Settings → Accounts → **+** → Apple ID. A free Apple ID is enough to put
the app on your own phone.

**2. Prepare the phone**

- Connect it by cable, tap **Trust This Computer**, and enter your passcode.
- On the phone: Settings → Privacy & Security → **Developer Mode** → on, then
  restart the phone. (iOS 16+ requires this; it will not appear until the phone
  has been connected to Xcode at least once.)

**3. Point the project at your team**

Edit `project.yml` — **not** Xcode's Signing tab, because `xcodegen generate`
overwrites the project file:

```yaml
        PRODUCT_BUNDLE_IDENTIFIER: com.YOURNAME.VibeGames   # must be unique to you
        DEVELOPMENT_TEAM: ABCDE12345                        # your Team ID
```

Your Team ID is shown in Xcode → Settings → Accounts, or in the Apple Developer
portal. Then re-run `xcodegen generate`.

Alternatively, set it in Xcode's **Signing & Capabilities** tab (tick
*Automatically manage signing*, choose your team) and simply don't regenerate
afterwards — but the next `xcodegen generate` will reset it.

**4. Build and run**

Select your iPhone in Xcode's destination menu and press ⌘R. The first attempt
fails with *Untrusted Developer* — that is expected. On the phone go to
Settings → General → VPN & Device Management → **Developer App**, tap your Apple
ID and **Trust**. Press ⌘R again.

### Free vs paid Apple ID

| | Free Apple ID | Developer Program (£79/$99 a year) |
| --- | --- | --- |
| App keeps working | **7 days**, then re-install | 1 year |
| Apps on device | 3 at a time | Unlimited |
| TestFlight / App Store | No | Yes |

For a party game you will use occasionally, the free tier is usually fine — just
re-run from Xcode when it expires. A paid account is worth it only if you want to
stop thinking about the 7-day clock or share it with other people.

> If you are on the free tier, avoid regenerating the project with a different
> bundle identifier — each new identifier burns one of your limited App IDs.

## Layout

```
project.yml                     XcodeGen spec — edit this, not the .xcodeproj
site/                           Marketing landing page (static, no build step)
  index.html                    Hero, QR codes, one section per game
  assets/qr/                    Real QR codes pointing at placeholder URLs
  assets/screens/               App screenshots, light + dark
  assets/people/                Illustrations standing in for photos
web/                            Browser versions, served at play.vibegames.party
  src/VibeWords.tsx             The game
  src/firebase.ts               Firebase wiring, incl. App Check
  .env.local                    Firebase config (git-ignored)
  .firebaserc                   Hosting project
functions/                      The daily cleanup, deployed to Cloud Functions
  index.js                      The scheduled function itself
  prune.js                      Which rooms are old enough to delete
  prune.test.js                 That rule, tested without a database
Sources/
  App/VibeGamesApp.swift        @main + NavigationStack root
  Model/GameCatalog.swift       The hub's list of games
  Model/PlayerIdentity.swift    The player's id and name, shared by every game
  Design/VibeTheme.swift        Palette, gradients, button styles, canvas
  Design/GameInstructions.swift The shared "how to play" shell and pages
  Audio/SoundEngine.swift       Runtime-synthesised buzzer / ticks / start blip
  Firebase/
    FirebaseBootstrapper.swift  Optional Firebase + App Check wiring
    AppAnalytics.swift          Every event name the app reports, in one place
  Model/ShortID.swift           The per-game player id, shared by the games
  Features/
    Home/HomeView.swift         Hub screen
    Home/PreferencesView.swift  Name and appearance, from the hub's gear button
    Home/NamePromptView.swift   The one name prompt, at the door and in a game
    VibeFive/
      CategoryPack.swift        Pack enum, metadata and deck aggregation
      Packs/                    One file of 100 prompts per pack
      VibeFiveModel.swift       Deck, phases, five-second clock
      VibeFiveView.swift        Game screen
      CountdownRing.swift       The dial
      VibeFiveSettingsView.swift
    VibeWords/
      WordGameEngine.swift      Scoring rules, no UI or network
      WordLists.swift           Loads the bundled dictionary
      VibeWordsService.swift    Realtime Database reads/writes
      VibeWordsModel.swift      Session, board and sync state
      VibeWordsView.swift       Name, lobby and game screens
      VibeWordsBoardView.swift  The 6 x 5 grid
      VibeWordsKeyboardView.swift
    VibeSudoku/
      SudokuPuzzle.swift        Grid maths, solver, conflict detection
      SudokuGenerator.swift     Seeded generation, uniqueness carving
      VibeSudokuService.swift   Realtime Database reads/writes
      VibeSudokuModel.swift     Session, board and sync state
      VibeSudokuView.swift      Name, lobby and game screens
      SudokuBoardView.swift     The 9 x 9 grid
      SudokuKeypadView.swift
    VibeTrio/
      TrioCard.swift            The 81-card deck and the trio rule
      TrioEngine.swift          The table: deal, take, keep playable
      TrioCardView.swift        The card itself, drawn from its features
      TrioBoardLayout.swift     Fits the whole table on screen at any size
      VibeTrioService.swift     Realtime Database reads/writes
      VibeTrioModel.swift       Session, table and sync state
      VibeTrioView.swift        Name, lobby, waiting room and game screens
  Resources/
    valid-words.txt             Generated by Tools/import_words.py
    answer-words.txt
Tests/                          Unit tests (engine, schema, model)
UITests/                        End-to-end UI tests
firebase/database.rules.json    Realtime Database rules
Tools/make_icon.swift           Renders the app icon and the favicon
Tools/feedback_to_issues.py     Turns app feedback into issues (scheduled)
Tools/import_words.py           Regenerates the word resources
Tools/check_packs.py            Validates the Vibe Five content
Tools/check_blurt_words.py      Validates the Similar Vibe words and their English
Tools/check_branding.py         Naming guard
Tools/make_qr.mjs               Generates the landing page QR codes
Tools/make_web_cards.py         Derives the web-sized card faces
Tools/make_web_packs.py         Generates the web Vibe Five categories
Tools/make_web_game_codes.py    Mirrors the code words into the web app
Tools/blurt_e2e.mjs             A real four-player game of Similar Vibe, in browsers
Tools/blurt_presence_e2e.mjs    Leaving, rejoining and standing in, for real
Tools/words_e2e.mjs             A real game of Word Vibe, in a browser
Tools/trio_fixtures/            Dumps the Swift Trio engine for the web tests
Tools/sudoku_fixtures/          Dumps the Swift Sudoku engine for the web tests
Tools/prune_games.py            Deletes old games (admin — clients cannot)
Tools/make_illustrations.py     Generates the stand-in illustrations
Tools/shoot_site.mjs            Screenshots the landing page for review
Support/GoogleService-Info.plist.example
```

## Adding another game

1. Add a case to `GameRoute` and an entry to `GameEntry.all` in `Model/GameCatalog.swift`.
2. Add the matching `navigationDestination` branch in `RootView`
   (`Sources/App/VibeGamesApp.swift`).
3. Drop the new screen under `Sources/Features/<Game>/`.

Games listed with `route: nil` render as dimmed "SOON" tiles, which is how the
Odd One Out placeholder works today.

## Adding categories

Append a string to the relevant `static let all` array in
`Sources/Features/VibeFive/Packs/`, then run `python3 Tools/check_packs.py` to
confirm counts and uniqueness. Prompts must be 1–6 words, have no trailing
punctuation, and be answerable — an average adult should manage at least eight
or nine things that fit.

To add a whole new pack: create `Packs/<Name>Prompts.swift`, add a case to
`CategoryPack` in `CategoryPack.swift` with its title/symbol/blurb, and wire it
into `prompts`. The settings screen, deck builder and counters pick it up
automatically.

## Appearance

The suite supports light and dark, and **follows the device by default**. Pick
`System`, `Light` or `Dark` in **Preferences**, behind the gear button at the top
right of the hub; the choice persists and applies to every game.

### The app icon

**VG**, the suite's initials, set in the system's rounded heavy face and slanted,
filled with a sweep through all four game colours. The letterform is the app's own
voice — the interface is rounded and heavy throughout — so the icon is set in the
product's voice rather than in a lookalike.

It replaced four coloured tiles, which had replaced Vibe Five's dial and numeral.
Both of those put one idea on the whole suite: the dial made the app look like a
buzzer timer to anyone who had not opened it, and the tiles read as a grid of
unrelated things.

`Tools/make_icon.swift` renders both the 1024pt icon and the browser favicon, and
the favicon is written from the **same glyph outlines** rather than redrawn by
hand — so the tab and the home screen cannot drift apart:

    swift Tools/make_icon.swift \
      Sources/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png \
      web/public/favicon.svg

Two things it has to get right, both of which are easy to get wrong quietly:

- **No transparency.** The App Store rejects an icon with see-through pixels.
  `AppIconTests` checks every pixel rather than the channel format, because
  Xcode's derived copies are RGBA whatever the source is.
- **No seam.** The glow behind the mark is an explicit radial gradient whose
  radius ends inside the canvas edge but outside the corners. The obvious
  `NSGradient.draw(in:relativeCenterPosition:)` looks right and leaves a square
  step of about eight levels where its rect stops, which is visible on a
  background this subtle.

### Feedback, and how it gets here

Nobody playing these games has a GitHub account, and asking someone to make one
to report a bug means the bug never gets reported. So there is a heart in the
corner of **every screen** — the hub, all five games, and the instructions page —
and behind it a panel with one box and a send button.

    app  →  feedback/{key} in the database  →  a scheduled Action  →  an issue

The inbox is a node in the same Realtime Database the games already use, writable
by anyone and readable by anyone. It is validated hard: text between 4 and 2,000
characters, a source of `ios` or `web`, an optional game, and no unknown fields.
Overwriting an existing entry is refused, so nothing can be edited after the
fact. Public read is deliberate — everything in it is about to become a public
issue, so there is nothing there to protect.

`Tools/feedback_to_issues.py` drains it, run by
`.github/workflows/feedback.yml` every fifteen minutes and on demand from the
Actions tab.

**No secret is stored anywhere for this.** The database inbox needs no
credential, and the workflow uses the `GITHUB_TOKEN` it is handed for free. That
is the whole reason for the two-step rather than the app calling GitHub
directly: a token in a client is a token anyone can read out of it.

Two consequences worth knowing:

- **It is not instant.** A GitHub-hosted scheduled run can be minutes late. That
  is the price of not running a server; if it ever matters, a small always-on
  endpoint would make it immediate and would need an account somewhere.
- **Running it twice is safe — eventually.** Every issue carries a `feedback-id`
  marker and anything already carrying one is skipped, so a failed run can
  simply be run again and a missed schedule costs nothing. Two things had to be
  true for that to hold, and neither was.

  The marker was written into the body and read back with
  `strip(" :->")` — which removes *characters* rather than a prefix, and every
  key Firebase hands out begins with `-`. So the first character of every key
  was eaten, nothing ever matched, and **every entry was filed again on every
  scheduled run**: 39 issues for 10 actual notes, and the ten oldest entries
  taken every time so the rest never got through at all.

  And GitHub serves the issue list from a read replica, so an issue created a
  second ago may not be in it yet. Two runs close together therefore both treat
  an entry as unfiled and both file it. The drain now reads the marker with a
  regex and looks a second time, after a short pause, before filing anything.

  `Tools/test_feedback_to_issues.py` covers the round trip — write a marker,
  read it back, and get the same key — which is the check that would have caught
  the first of these on the day it was written:

  ```bash
  python3 Tools/test_feedback_to_issues.py
  ```

**Test notes are marked and never become issues.** The UI test that sends
feedback walks the real path on purpose — a form that only ever works against a
stub proves nothing — so its note lands in the live inbox. A client cannot delete
what it wrote (the rules refuse a delete from any client, deliberately), so the
test prefixes its note with `[test]` and the drain skips anything starting with
it. No test run can open an issue on the repository.

That leaves the inbox append-only: entries accumulate and nothing expires them,
because the only thing with delete rights is the admin CLI. Pruning is
occasional housekeeping rather than a chore, but it is worth knowing the command:

```bash
cd firebase && firebase database:remove /feedback --project vibe-words-party
```

The rules were probed before anything was built on them — nine cases, two that
should be allowed and seven that should be refused — and the whole path was then
walked end to end, from typing in a real browser and on a real phone through to
issues appearing on the repository.

### Crashes, which nobody can type in a box

A crash is the one failure the heart cannot catch: the page or the app stops
working, so there is no form left to fill in. Both halves report them on their
own, down the same pipe as feedback, arriving as issues labelled `crash` and
titled `Crash: …` rather than `Feedback: …`.

**On the phone**, via Firebase Crashlytics. `FirebaseBootstrapper` turns
collection on and exports `record(_:during:)`, which twelve catch blocks call
wherever the app gives up on something — a board that will not load, a claim
that will not send. An `Upload dSYMs to Crashlytics` build phase runs
Crashlytics' own `run` script, which needs two things that are easy to get
wrong: it must run *after* compiling (in `postBuildScripts`, not
`postCompileScripts`) and it must be told where the plist is (`-gsp`), because
script sandboxing otherwise blocks it from finding one. Both are in `project.yml`.

**In the browser**, via `web/src/errors.ts`, which listens for `error` and
`unhandledrejection`. It is built to stay quiet: each distinct failure is sent
once per session, keyed on its message, and a session stops after five, because
a loop that throws on every frame would otherwise post thousands of copies of one
bug and bury every real report. Sends are fire-and-forget — if the report cannot
be posted, nothing is shown, since complaining about the failure path would be a
crash reporter crashing.

The two are bounded differently on purpose. Crashlytics is a real crash reporter
with symbolication and its own retention, and is the better tool for a native
crash; the browser reporter is small because the alternative was nothing at all.
One limitation is worth knowing rather than discovering: a failure inside a
**cross-origin** script arrives as `Script error.` with no stack. That is the
browser withholding detail, not the reporter losing it — it does not apply to the
app's own bundle, and the page and browser are still recorded.

### Which games get played

Four games, two clients and a landing page, and until recently no idea which of
any of them anybody used. Now all three report into one Google Analytics
property, using the same event names and the same values, so the counts can be
read side by side rather than through a translation table.

    launch      session_start and first_open, recorded by Analytics itself
    a visit     page_view, per route — the web client and the landing page
    a game      game_start, and game_finish with an outcome

`game_start` carries `game_name` (`vibe-trio`, matching the web routes and both
`GameEntry.id`s), `mode` (`solo` or `shared`), and whatever else the game knows:
`grade` for Sudoku, `round` for Five. `game_finish` adds `outcome` — `won`,
`lost`, or `completed` — plus `score` and `seconds` where they mean something.

Four smaller events sit around the edges, each because it answers a question that
would otherwise be a guess: `screen_view` (a game opened but never started is a
lobby problem, not a game problem), `feedback_sent` (does the form work in the
wild), `support_open` and `donation_tap` (the top and the bottom of the only
funnel that keeps this running), and `share`.

**There is deliberately no "app launched" event.** Analytics records
`first_open` and `session_start` on its own, with the retention and engagement
reporting built around them, and a hand-rolled duplicate would be a worse version
of the same number.

**And there is deliberately no "abandoned" outcome.** Leaving mid-game is only
observable where the app shows a Leave button, which is two of the eight places
a round can end. A count that covers a quarter of the cases but is presented as
"abandonment" is worse than no count: the gap between starts and finishes
already carries that signal, honestly, because both are counted the same way.

Three things are worth knowing about how it is wired, because each of them is a
way to get a number that looks like data and is not:

- **One file per client.** `Sources/Firebase/AppAnalytics.swift` and
  `web/src/analytics.ts` hold every event name. A report is only worth reading if
  `game_start` means the same thing in all five games and in both apps.
- **Off is a build-time fact on the web, and a console fact on iOS.** The web
  measurement id is baked in at build time, so with none set no gtag script is
  ever created. iOS needs nothing beyond the property existing on the project:
  the `IS_ANALYTICS_ENABLED` flag written into the plist is *not* a gate, which
  was measured after an earlier claim here said otherwise.
- **StrictMode is on, and effects run twice.** Almost every web hook is a React
  effect, so each one is guarded — by a `useRef` keyed on the round, which is
  what stops a development double-invoke from counting a round twice. A page view
  counted twice is worse than one not counted at all, because it looks like data.
- **Starts are logged where the round begins, finishes where it ends.** A shared
  round begins when the seed arrives over the wire, not when the host presses
  Start, so instrumenting the button would miss every guest. Finishes are
  observed on the transition out of play, because Sudoku's loss and Trio's ending
  are *derived* states with no single line to hang a counter on.

**Nothing sent identifies anybody.** No names, no game codes, no free text from
the feedback box — counts of things happening, and nothing else.

The web client sends these with **gtag.js directly, not the Firebase Analytics
SDK**. That SDK asks Google for the app's web config at runtime and, where the
reply omits `measurementId`, trusts the omission — loading gtag with
`id=undefined` while the locally configured id sits unused, because it only falls
back when the request fails rather than when the answer is incomplete. The
measurement id is known at build time anyway, so taking it straight to gtag
removes the dependency instead of working around it.
[FIREBASE_SETUP.md](FIREBASE_SETUP.md#7-switching-analytics-on) has the two
places to fill in.

It is worth saying plainly that this changes the privacy story. The App Store
privacy answers now need Analytics declared alongside Crashlytics — device
identifiers and usage data, collected for analytics rather than advertising,
and not linked to identity. The
app still asks for no account, no email address and no tracking permission, and
the `WithoutAdIdSupport` build of the Analytics SDK is used on purpose so that
the advertising identifier is never touched and no ATT prompt is ever needed.

### Your name, and where it is asked for

The player's name is the app's, not a game's: one name, one id, one place to set
them. That place is Preferences on the hub, which is also where appearance lives
— it used to be a light/dark button, and the name had nowhere to live but inside
each game that wanted one.

Which meant that choosing Vibe Pairings to play *solo* put a name form in front of
you that the game did not need and you could not get past. Now:

- On a **first run** the name is asked once, at the front door, before any game is
  opened. It can be waved away — three of the four games never want it.
- A game's lobby **never** asks. Solo play goes straight to the board.
- Only starting or joining a **shared** game asks, and only if the name is still
  missing; the tap that needed it is held and runs once the name arrives.
- The hub shows a `Playing as …` chip, which is the short way back to Preferences.

`NamePromptView` is the single prompt for all four places, so the door and the
lobby cannot drift apart.

> **The "already asked" flag is a string, not a bool.** A launch argument always
> arrives in `UserDefaults` as text, so a `Bool` sitting under that key cannot be
> overridden from the command line and a UI test cannot force a first run. The
> tests pass `-vibegames.playerName ""` and `-vibegames.namePromptAnswered ""`
> for exactly that reason.

Every colour in `VibeTheme` resolves per appearance via a dynamic `UIColor`, so
there is no second palette to keep in sync.

> **A bare `.white` in a view is almost always a bug.** White text on the light
> canvas is invisible. Use the semantic tokens, and reserve `.white` for text on
> a *coloured fill* — buttons, scored tiles, keyboard keys — where it is right in
> both appearances. Two places need care: an unscored word tile and an untried
> keyboard key are pale in light mode, so their labels use `primaryText`, which
> flips, rather than white.

## Notes

- **No audio assets.** `SoundEngine` synthesises the buzzer (detuned square waves
  with a pitch bend, then low-passed), the countdown tick and the start blip at
  launch with `AVAudioEngine`. The audio session uses `.playback`, so the buzzer
  is audible even with the ringer switch off.
- **No `@Observable` macro.** The model uses `ObservableObject`/`@Published`. This
  is deliberate: it means the project compiles in environments that cannot run
  Swift macro plugins (sandboxed build agents), which `@Observable`, `@State` and
  `#Preview` all require. Switching back is a small, mechanical change if you want it.
- **The clock is wall-clock based.** `VibeFiveModel` derives remaining time from a
  `startedAt` date rather than accumulating ticks, so the countdown cannot drift.
  A 20 Hz task exists only to fire audio cues and end the round; the ring itself is
  driven by `TimelineView(.animation)` for smooth 60 fps drawing.
