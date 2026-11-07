# Vibe Games — every user-facing string, for review

A single review copy of the English words that ship in the iOS app and the browser
client, grouped so the wording can be read and criticised without opening Xcode.
This file is a **snapshot for review, not a source of truth**: every entry carries
a `file:line` reference, and the code remains the only thing that decides what is
on screen.

## What this file is, and what it is not

- **The app is not internationalized.** There are no `.strings` or `.xcstrings`
  files, no `Localizable` tables and no localization layer. Every string is
  hardcoded: in Swift, inside SwiftUI `Text`, `Label`, `Button`, alerts, notes and
  model error messages; in TypeScript/TSX, inside JSX text, string literals and
  template strings. The web client has no i18n library either.
- **Every entry is quoted as it ships.** Spelling, grammar, punctuation, em dashes
  and `**bold**` markup are reproduced without correction — several entries are
  here *because* they read badly.
- **Curly quotes** (`“ ”`) wrap the quoted copy, so a straight quote or apostrophe
  *inside* an entry is part of the string itself.
- **`{...}` marks an interpolated value.** Entries assembled from interpolations
  are marked `[template]`. Where the interpolation resolves to a static constant
  (pack counts, points to win, guess counts) the resolved number is written out.
- **[VoiceOver]** marks a string that is spoken rather than drawn. These are
  user-facing and are included; accessibility *identifiers*, analytics event
  names, SF Symbol names, URLs, API keys and code identifiers are not.
- **Marketing and legal pages are pointers only** (section 4), not duplicated.
- Paths are relative to the repository root.

## Where the words live

**iOS app**

- `Sources/Features/Home/` — shared chrome: hub, preferences/about, support panel,
  feedback form, name prompt, solo-resume prompt, round-over panel, game
  header bar, game-code badge, shared settings pieces.
- `Sources/Features/<Game>/` — each game's lobby, play screen, settings sheet and
  its model's error/summary strings: `VibeFive/`, `VibeWords/`, `VibeSudoku/`,
  `VibeTrio/`, `VibeBlurt/`, `VibeTen/`.
- `Sources/Design/GameInstructions.swift` — the five prose "how to play" pages.
- `Sources/Features/VibeTrio/TrioInstructionsView.swift` — Vibe Pairings' custom,
  diagram-led "how to play" page.
- `Sources/Model/` — hub catalogue names/taglines, invite text, name limits.
- `Sources/Firebase/FirebaseBootstrapper.swift` — the service-unavailable wording.
- `Sources/Features/Utilities/` — the dice and first-player tools.

**Web client**

- `web/src/hub/` — shared chrome: hub, header, lobby, how-to-play shell, settings,
  support panel, room code, round-over, solo-resume.
- `web/src/games/<game>/` — `five/`, `words/`, `sudoku/`, `trio/`, `blurt/`,
  `ten/`: each screen, its inline instructions, and the labels held in its engine.
- `web/src/titles.ts`, `web/src/App.tsx` — browser tab titles and routes.
- `web/src/games/feedback.ts`, `web/src/errors.ts` — feedback and crash-report
  wording.

**Marketing, legal and store listing**

- `site/index.html`, `site/about.html`, `site/privacy.html`, `site/support.html`,
  `site/ways-to-help.html` — the website the App Store links to.
- `APP_STORE.md` — the App Store listing copy.

---

## 1. Rules and instructions

These are the pages behind "How to play". All six games share one page shell; five
supply prose and Vibe Pairings supplies its own diagram-led sections.

### Shared rules-page chrome

The shell every rules page uses (`Sources/Design/GameInstructions.swift`), and the
opener that reaches it.

- “HOW TO PLAY” — Sources/Design/GameInstructions.swift:246
- “Back” [VoiceOver] — Sources/Design/GameInstructions.swift:242
- “{game name}” [template] (page subtitle under the heading, e.g. “Vibe Five”) — Sources/Design/GameInstructions.swift:250
- “How to play” (lobby card title) — Sources/Design/GameInstructions.swift:313
- “The rules, and what the buttons do” (lobby card subtitle) — Sources/Design/GameInstructions.swift:316
- “How to play” (text-only opener, used by Vibe Five) — Sources/Design/GameInstructions.swift:362
- “Playing” (heading over the bullets; drawn uppercased) — Sources/Design/GameInstructions.swift:274
- Section titles are drawn uppercased by the page — Sources/Design/GameInstructions.swift:384

### Vibe Five

From `Sources/Design/GameInstructions.swift:35`. Resolved counts: 995 categories in
11 packs.

- “Vibe Five” (page name) — Sources/Design/GameInstructions.swift:37
- “It's easy right? Just name 3 things that fit in the category...in only 5 seconds.” (intro) — Sources/Design/GameInstructions.swift:39
- “Game host” (section title) — Sources/Design/GameInstructions.swift:41
- “We find the games works best if one player is the game host. It's also helpful if you can cast the screen onto a larger TV that everyone can see, but it's not required. The host will press **START** to see the first clue. The first job of the host is to read the clue, very clearly, so the players can understand it. Once the host has finished reading the clue they press the **START** button again.” — Sources/Design/GameInstructions.swift:42
- “How a round ends” (section title) — Sources/Design/GameInstructions.swift:49
- “Either the clock runs out — the buzzer sounds and the screen flashes red — or the host presses **Done!** to end it early. Done! is deliberately silent, because the buzzer means the clock beat you. Either way the dial freezes on the time that was left, so the table can see how much time they had to spare.” — Sources/Design/GameInstructions.swift:50
- “Alternative Play” (section title) — Sources/Design/GameInstructions.swift:55
- “If you don't want to have a single person as a host, you can also pass the device from person to person. You can also play solo this way if you want to practice.” — Sources/Design/GameInstructions.swift:56
- “START — Shows a category.” — Sources/Design/GameInstructions.swift:61
- “Buzzer — You didn't get it fast enough.” — Sources/Design/GameInstructions.swift:62
- “Done! — You got it! Congratulations.” — Sources/Design/GameInstructions.swift:63
- “NEXT — Show a new category.” — Sources/Design/GameInstructions.swift:64
- “Packs — 995 categories across 11 packs, switched on and off in Game Setup. Only the packs you leave on go into the deck, and no category comes round twice until the pool runs out.” — Sources/Design/GameInstructions.swift:65

### Word Vibe

From `Sources/Design/GameInstructions.swift:71`.

- “Word Vibe” (page name) — Sources/Design/GameInstructions.swift:73
- “Guess the five-letter word in six tries. Play solo on this device, or start a game and race everyone on the same word.” (intro) — Sources/Design/GameInstructions.swift:75
- “Reading the colours” (section title) — Sources/Design/GameInstructions.swift:78
- “**Green** is the right letter in the right place. **Amber** means the letter is in the word but somewhere else. **Grey** means it is not in the word at all.” — Sources/Design/GameInstructions.swift:79
- “Repeated letters” (section title) — Sources/Design/GameInstructions.swift:82
- “Exact matches are claimed first, and what is left of the answer then has to cover the rest: guessing EERIE against SPEED credits two Es and marks the third one absent.” — Sources/Design/GameInstructions.swift:83
- “Solo — A fresh word, with no connection needed.” — Sources/Design/GameInstructions.swift:89
- “With friends — Everyone guesses the same word on their own device. The first to solve it is announced to the whole room.” — Sources/Design/GameInstructions.swift:90

### Number Vibe

From `Sources/Design/GameInstructions.swift:94`.

- “Number Vibe” (page name) — Sources/Design/GameInstructions.swift:96
- “Fill the 9x9 grid so every row, every column and every 3x3 box holds 1 to 9. Play solo, or race friends on an identical board.” (intro) — Sources/Design/GameInstructions.swift:98
- “Difficulty” (section title) — Sources/Design/GameInstructions.swift:101
- “Easy, Medium and Hard are graded by the technique a puzzle needs to solve it. If you host a race, you choose the difficulty and everybody gets the same board.” — Sources/Design/GameInstructions.swift:102
- “Notes” (section title) — Sources/Design/GameInstructions.swift:105
- “**Notes** lets you pencil candidates into a square. Anything that clashes with a number in the same row, column or box is highlighted, so a mistake shows up before it spreads.” — Sources/Design/GameInstructions.swift:106
- “Solo — An endless supply of boards, at the difficulty you choose.” — Sources/Design/GameInstructions.swift:111
- “Race — Everyone gets the same board. First to fill it wins.” — Sources/Design/GameInstructions.swift:112

### Vibe Ten

From `Sources/Design/GameInstructions.swift:115`.

- “Vibe Ten” (page name) — Sources/Design/GameInstructions.swift:117
- “Take pairs of numbers off the board until all the numbers have been removed.” (intro) — Sources/Design/GameInstructions.swift:119
- “What pairs” (section title) — Sources/Design/GameInstructions.swift:121
- “Two numbers match if they are **the same**, or if they **add up to ten** — 1 with 9, 2 with 8, 3 with 7, 4 with 6, 5 with 5. They have to be on the same row, column or diagonal, with nothing in between: neighbours count, and so does a line with only gaps in it.” — Sources/Design/GameInstructions.swift:122
- “Rows that join up” (section title) — Sources/Design/GameInstructions.swift:127
- “You can enable a setting that lets the rows connect end to end: the last square of a row is next to the first square of the row below it, so a 5 at the end of one row matches a 5 at the start of the next — and, if the squares between them have already been taken, the one after that can match.” — Sources/Design/GameInstructions.swift:128
- “The board” (section title) — Sources/Design/GameInstructions.swift:132
- “The board is **nine columns** wide and starts with **twelve to eighteen rows** of numbers. The strategy of the game is deciding which pair to take first, because every pair you remove changes what is available.” — Sources/Design/GameInstructions.swift:133
- “Dim mode” (section title) — Sources/Design/GameInstructions.swift:137
- “In standard play, when you make a pair, the pair is removed immediately from the board and all the pieces below the pair rise up. In the game settings, there is a **Dim** option that leaves a taken pair on the board, greyed out, instead of removing it. A dimmed number is gone as far as the rules are concerned: it cannot be picked again, and a pair can be made straight across it. When every number in a row has been dimmed, the whole row clears at once and everything below it rises one row.” — Sources/Design/GameInstructions.swift:138
- “New rows” (section title) — Sources/Design/GameInstructions.swift:145
- “You can reveal more rows of numbers at the bottom of the board by pressing the **Add rows** button. During game setup, you can choose whether the button reveals two or four rows. The new rows bring a partner for the numbers that have no pair to take, and pair up the rest.” — Sources/Design/GameInstructions.swift:146
- “Winning” (section title) — Sources/Design/GameInstructions.swift:149
- “Continue removing pairs until you have removed them all. If you are able to remove all the numbers, you win. If you cannot remove all the numbers and you can no longer add rows, you lose. You can retry the board and see if you can remove the pairs differently and win.” — Sources/Design/GameInstructions.swift:150
- “Playing as a room” (section title) — Sources/Design/GameInstructions.swift:154
- “Everyone gets the identical board, dealt from a seed and played by the host's chosen options — the starting rows, how many rows a press adds, whether the rows join end to end, and how a taken pair leaves the board. You each take pairs at your own pace on your own device. The first person to clear the board wins.” — Sources/Design/GameInstructions.swift:155
- “Solo — A fresh board whenever you want one. Play at your own pace.” — Sources/Design/GameInstructions.swift:162
- “Room — The same board for everyone. First to clear it wins.” — Sources/Design/GameInstructions.swift:163

### Similar Vibe

From `Sources/Design/GameInstructions.swift:166`. Resolved: first team to 7 points.

- “Similar Vibe” (page name) — Sources/Design/GameInstructions.swift:168
- “Describe a word without saying it, so your team can guess it before the clock stops.” (intro) — Sources/Design/GameInstructions.swift:170
- “Use similar words” (section title) — Sources/Design/GameInstructions.swift:172
- “One person is shown a word and describes it using similar words, without saying it. Their teammates try to guess the word. If they get it right a new word is shown to somebody on the **other** team. A round lasts about a minute. Make sure you don't have the word when the time runs out or the other team gets a point — whoever is left holding it starts the next round.” — Sources/Design/GameInstructions.swift:173
- “A giveaway” (section title) — Sources/Design/GameInstructions.swift:179
- “The team **not** holding the word can see it, and has one big red BUZZ button. If the describer says the word, or any part of it, they press it — and take the point.” — Sources/Design/GameInstructions.swift:180
- “Four people — Two on each side at least. The app splits the room into teams at random.” — Sources/Design/GameInstructions.swift:185
- “Scoring — Nobody scores for guessing. The point goes to the team that was not holding the word when the clock stops — unless one team gives away their word.” — Sources/Design/GameInstructions.swift:187
- “Winning — First team to 7 points wins the game.” — Sources/Design/GameInstructions.swift:190

### Vibe Pairings

Custom page: `Sources/Features/VibeTrio/TrioInstructionsView.swift`. This page is
diagram-led, so every heading, paragraph, label and bullet is listed.

- “Vibe Pairings” (page name) — Sources/Features/VibeTrio/TrioInstructionsView.swift:41
- “Twelve charcuterie boards are dealt face up. Your job is to find three of them that make a good pairing.” (intro) — Sources/Features/VibeTrio/TrioInstructionsView.swift:42
- “What's on a board” (section heading) — Sources/Features/VibeTrio/TrioInstructionsView.swift:81
- “Every board has four features, and each one comes three ways.” — Sources/Features/VibeTrio/TrioInstructionsView.swift:83
- “Platter” (feature label) — Sources/Features/VibeTrio/TrioInstructionsView.swift:28
- “round walnut · bamboo hexagon · slate rectangle” (feature options) — Sources/Features/VibeTrio/TrioInstructionsView.swift:28
- “Cheese” (feature label) — Sources/Features/VibeTrio/TrioInstructionsView.swift:29
- “swiss wedge · gouda cubes · brie round” (feature options) — Sources/Features/VibeTrio/TrioInstructionsView.swift:29
- “Meat” (feature label) — Sources/Features/VibeTrio/TrioInstructionsView.swift:30
- “prosciutto ribbon · salami stack · turkey roll-up” (feature options) — Sources/Features/VibeTrio/TrioInstructionsView.swift:30
- “Garnish” (feature label) — Sources/Features/VibeTrio/TrioInstructionsView.swift:31
- “purple grapes · red strawberry · pear slices” (feature options) — Sources/Features/VibeTrio/TrioInstructionsView.swift:31
- “Platter”, “Cheese”, “Meat”, “Garnish” (labels drawn on the example board) — Sources/Features/VibeTrio/TrioInstructionsView.swift:202
- “A board labelled with its four features” [VoiceOver] — Sources/Features/VibeTrio/TrioInstructionsView.swift:227
- “The rule” (section heading) — Sources/Features/VibeTrio/TrioInstructionsView.swift:117
- “Three cards make a good pairing when **every one of the four features is either the same on all three cards, or different on all three**.” — Sources/Features/VibeTrio/TrioInstructionsView.swift:119
- “Two matching and a third different is not a good pairing — on any feature.” — Sources/Features/VibeTrio/TrioInstructionsView.swift:124
- “This is a good pairing” (example title) — Sources/Features/VibeTrio/TrioInstructionsView.swift:46
- “Platter and cheese are the same on all three. Meat and garnish are different on all three. An excellent pairing.” (example verdict) — Sources/Features/VibeTrio/TrioInstructionsView.swift:48
- “This is not a good pairing” (example title) — Sources/Features/VibeTrio/TrioInstructionsView.swift:51
- “Two of them are prosciutto and the third is salami — two the same and one different. That's not a good pairing.” (example verdict) — Sources/Features/VibeTrio/TrioInstructionsView.swift:53
- “Meat” (the failing feature called out on the bad example) — Sources/Features/VibeTrio/TrioInstructionsView.swift:54
- “all the same” / “all different” (feature-breakdown labels) — Sources/Features/VibeTrio/TrioInstructionsView.swift:265
- “{feature} all the same, {feature} all different, …” [VoiceOver][template] — Sources/Features/VibeTrio/TrioInstructionsView.swift:287
- “Solo — Clear the whole deck at your own pace. Stuck? **Hint** picks out one card of a good pairing — the other two are still yours to find.” — Sources/Features/VibeTrio/TrioInstructionsView.swift:57
- “Race — Everyone gets the same boards on their own device. Whoever finds the most pairings wins. The host decides whether the table has hints.” — Sources/Features/VibeTrio/TrioInstructionsView.swift:60
- “Wrong three — They flash red and nothing moves. Keep trying.” — Sources/Features/VibeTrio/TrioInstructionsView.swift:63

---

## 2. App interface copy

Everything user-visible in the iOS app apart from the rules pages, grouped by
screen. Strings assembled from interpolations are marked `[template]`; VoiceOver
labels are marked `[VoiceOver]`.

### Hub

`Sources/Features/Home/HomeView.swift`, `Sources/Features/Home/HubTile.swift`,
`Sources/Model/GameCatalog.swift`, `Sources/Features/Utilities/UtilitiesButton.swift`.

- “VIBE GAMES” (hub title) — Sources/Features/Home/HomeView.swift:58
- “Quick party games. Pass it round.” (tagline) — Sources/Features/Home/HomeView.swift:69
- “Preferences” [VoiceOver] (gear button) — Sources/Features/Home/HomeView.swift:93
- “Playing as {name}” [template] (name chip when a name is set) — Sources/Features/Home/HomeView.swift:105
- “Add your name” (name chip when there is no name) — Sources/Features/Home/HomeView.swift:105
- “More games on the way.” (footer) — Sources/Features/Home/HomeView.swift:123
- “Opens the game” [VoiceOver] (hint on a playable tile) — Sources/Features/Home/HomeView.swift:146
- “{title}, coming soon” [VoiceOver][template] (unplayable tile) — Sources/Features/Home/HomeView.swift:152
- “SOON” (badge on an unreleased tile) — Sources/Features/Home/HubTile.swift:42

**Game tiles, in hub order** (`Sources/Model/GameCatalog.swift`)

- “Vibe Five” — Sources/Model/GameCatalog.swift:29
- “Name three things before the buzzer.” — Sources/Model/GameCatalog.swift:30
- “Word Vibe” — Sources/Model/GameCatalog.swift:37
- “Guess the five-letter word. First to solve wins.” — Sources/Model/GameCatalog.swift:38
- “Number Vibe” — Sources/Model/GameCatalog.swift:45
- “Fill the grid. Race your friends to it.” — Sources/Model/GameCatalog.swift:46
- “Vibe Pairings” — Sources/Model/GameCatalog.swift:53
- “Three cards where every feature matches or differs.” — Sources/Model/GameCatalog.swift:54
- “Vibe Ten” — Sources/Model/GameCatalog.swift:61
- “Pair the digits. Clear the board. First to clear it wins.” — Sources/Model/GameCatalog.swift:62
- “Similar Vibe” — Sources/Model/GameCatalog.swift:69
- “Describe it. Don't say it. Two teams, one word.” — Sources/Model/GameCatalog.swift:70

**Utilities entry on the hub**

- “Utilities” — Sources/Features/Utilities/UtilitiesButton.swift:22
- “Dice, and whatever else the table needs.” — Sources/Features/Utilities/UtilitiesButton.swift:26
- “Opens the utilities” [VoiceOver] — Sources/Features/Utilities/UtilitiesButton.swift:52

### Preferences and About

`Sources/Features/Home/PreferencesView.swift`, with the shared name and
appearance sections from `Sources/Features/Home/GameSettings.swift`.

- “Preferences” (sheet title) — Sources/Features/Home/PreferencesView.swift:57
- “Done” (sheet button) — Sources/Features/Home/PreferencesView.swift:61
- “Your name” (section title) — Sources/Features/Home/GameSettings.swift:162
- “Forget it” (clears the stored name) — Sources/Features/Home/GameSettings.swift:165
- “Your name” (text-field placeholder) — Sources/Features/Home/PreferencesView.swift:12
- “Shown to everyone in a game you play together. Up to 24 characters.” — Sources/Features/Home/GameSettings.swift:183
- “Appearance” (section title) — Sources/Features/Home/GameSettings.swift:192
- “System” / “Light” / “Dark” (segmented control) — Sources/App/VibeGamesApp.swift:23
- “Match System follows the device's light or dark setting.” — Sources/Features/Home/GameSettings.swift:202
- “About” (section title) — Sources/Features/Home/PreferencesView.swift:77
- “Privacy” (link) — Sources/Features/Home/PreferencesView.swift:80
- “Support” (link) — Sources/Features/Home/PreferencesView.swift:82
- “Vibe Games {version} ({build})” [template] — Sources/Features/Home/PreferencesView.swift:87

Full appearance names, used where there is room: “Match System”, “Light”, “Dark” —
Sources/App/VibeGamesApp.swift:13.

### Support panel and feedback form

`Sources/Features/Home/SupportView.swift`, `Sources/Features/Home/FeedbackService.swift`.

**The heart and the panel**

- “Support Vibe Games” [VoiceOver] (heart button) — Sources/Features/Home/SupportView.swift:63
- “Support” (sheet title) — Sources/Features/Home/SupportView.swift:153
- “Done” (sheet button) — Sources/Features/Home/SupportView.swift:157
- “Made with love” (heading) — Sources/Features/Home/SupportView.swift:24
- “I built these games for my own family. We play them in the evenings — it is how we wind down together and stay close — and I wanted to share that with other families.” (blurb, first paragraph) — Sources/Features/Home/SupportView.swift:26
- “Every game is free. Nothing to unlock, no adverts, no account.” (blurb, second paragraph) — Sources/Features/Home/SupportView.swift:28
- “Other ways to help” (section heading) — Sources/Features/Home/SupportView.swift:107
- “Share it with another family” (share row) — Sources/Features/Home/SupportView.swift:117
- “They can play in a browser tonight, free” (share row detail) — Sources/Features/Home/SupportView.swift:118
- “Privacy” (link) — Sources/Features/Home/SupportView.swift:135
- “·” (separator between the two links) — Sources/Features/Home/SupportView.swift:137
- “Support” (link) — Sources/Features/Home/SupportView.swift:138

**Feedback form**

- “Tell me what you think, or what is not working” (form heading) — Sources/Features/Home/SupportView.swift:315
- “Send” (button, idle) — Sources/Features/Home/SupportView.swift:348
- “Sending…” (button, in flight) — Sources/Features/Home/SupportView.swift:348
- “No account, no email address, nothing to sign up for — it reaches me as a note.” (note, no game context) — Sources/Features/Home/SupportView.swift:363
- “No account, no email address, nothing to sign up for — it reaches me as a note about {game}.” [template] (note inside a game) — Sources/Features/Home/SupportView.swift:363
- “Thank you — it arrived.” (sent state) — Sources/Features/Home/SupportView.swift:284
- “There is no reply by email, so this is where the note ends — it goes on the list and gets worked through. Found something else?” — Sources/Features/Home/SupportView.swift:291
- “Send another” — Sources/Features/Home/SupportView.swift:296
- “Please write a little more.” (too-short error) — Sources/Features/Home/FeedbackService.swift:29
- “Please keep it under 2000 characters.” (too-long error) — Sources/Features/Home/FeedbackService.swift:31
- “Sending needs a connection to the game service.” (no database) — Sources/Features/Home/FeedbackService.swift:54

### Name prompt

`Sources/Features/Home/NamePromptView.swift`, plus the per-game message each game
passes in.

- “What should we call you?” — Sources/Features/Home/NamePromptView.swift:32
- “Your name” (field placeholder) — Sources/Features/Home/PreferencesView.swift:12
- “Save” — Sources/Features/Home/NamePromptView.swift:49
- “Not now” — Sources/Features/Home/NamePromptView.swift:54
- “It is only needed for games you play with other people, and you can change it later from the home screen.” (first-run message) — Sources/Features/Home/NamePromptView.swift:80
- “So everyone knows who got there first.” (Word Vibe) — Sources/Features/VibeWords/VibeWordsView.swift:30
- “So everyone can see who finished first.” (Number Vibe) — Sources/Features/VibeSudoku/VibeSudokuView.swift:29
- “So everyone knows who spotted it first.” (Vibe Pairings) — Sources/Features/VibeTrio/VibeTrioView.swift:24
- “So your team knows who is describing.” (Similar Vibe) — Sources/Features/VibeBlurt/VibeBlurtView.swift:56
- “So the others in the room know whose score is whose.” (Vibe Ten) — Sources/Features/VibeTen/VibeTenView.swift:36

### Solo-resume prompt

One alert, used by Word Vibe, Number Vibe, Vibe Pairings and Vibe Ten.

`Sources/Features/Home/SoloResumePrompt.swift`

- “A game is in progress” (alert title) — Sources/Features/Home/SoloResumePrompt.swift:19
- “{summary}” [template] (alert message; the game supplies the sentence) — Sources/Features/Home/SoloResumePrompt.swift:30
- “Continue” — Sources/Features/Home/SoloResumePrompt.swift:20
- “New game” — Sources/Features/Home/SoloResumePrompt.swift:24
- “Cancel” — Sources/Features/Home/SoloResumePrompt.swift:28

### Shared game chrome

The header, round-over panel, code badge and settings pieces every game uses.

`Sources/Features/Home/GameHeaderBar.swift`, `Sources/Features/Home/RoundOverPanel.swift`,
`Sources/Features/Home/GameCodeBadge.swift`, `Sources/Features/Home/GameSettings.swift`.

- “Back to games” [VoiceOver] (header, lobby; each game lists its own) — Sources/Features/VibeWords/VibeWordsView.swift:380
- “Leave game” [VoiceOver] (header, in a game; each game lists its own) — Sources/Features/VibeWords/VibeWordsView.swift:380
- “Share game code” [VoiceOver] (share button) — Sources/Features/VibeWords/VibeWordsView.swift:395
- “Game settings” [VoiceOver] (sliders button) — Sources/Features/Home/GameSettings.swift:140
- “Play again” (round-over primary button default) — Sources/Features/Home/RoundOverPanel.swift:33
- “Game code” (caption over the code) — Sources/Features/Home/GameCodeBadge.swift:37
- “Game code {code}” [VoiceOver][template] — Sources/Features/Home/GameCodeBadge.swift:80
- “Read this out — everyone joins with it.” (host's code hint) — Sources/Features/VibeWords/VibeWordsView.swift:343
- “Everyone else: Word Vibe → Join with a code” (guest's code hint) — Sources/Features/VibeWords/VibeWordsView.swift:344
- “Everyone else: Number Vibe → Join with a code” — Sources/Features/VibeSudoku/VibeSudokuView.swift:410
- “Everyone else: Vibe Pairings → Join with a code” — Sources/Features/VibeTrio/VibeTrioView.swift:535
- “Everyone else: Vibe Ten → Join with a code” — Sources/Features/VibeTen/VibeTenView.swift:198
- “Everyone else: Similar Vibe → Join with a code” — Sources/Features/VibeBlurt/VibeBlurtView.swift:225

### Vibe Five

`Sources/Features/VibeFive/VibeFiveView.swift`, `VibeFiveModel.swift`,
`VibeFiveSettingsView.swift`.

**The game screen**

- “VIBE FIVE” (header title) — Sources/Features/VibeFive/VibeFiveView.swift:168
- “Ready to play” (header subtitle before the first round) — Sources/Features/VibeFive/VibeFiveView.swift:169
- “Round {n}” [template] (header subtitle) — Sources/Features/VibeFive/VibeFiveView.swift:169
- “Back to games” [VoiceOver] — Sources/Features/VibeFive/VibeFiveView.swift:171
- “Tap START to reveal a category” (empty card) — Sources/Features/VibeFive/VibeFiveView.swift:257
- “Read it out loud, then quickly start the clock” (empty card helper) — Sources/Features/VibeFive/VibeFiveView.swift:262
- “GET READY” (badge when a category is revealed) — Sources/Features/VibeFive/VibeFiveView.swift:231
- “TIME'S UP!” (badge when the clock runs out) — Sources/Features/VibeFive/VibeFiveView.swift:233
- “STOPPED” (badge when the round is ended early) — Sources/Features/VibeFive/VibeFiveView.swift:235
- “Category: {text}” [VoiceOver][template] — Sources/Features/VibeFive/VibeFiveView.swift:203
- “SECONDS” / “LEFT” / “TIME” (caption under the dial number) — Sources/Features/VibeFive/CountdownRing.swift:41
- “Time is up” [VoiceOver] — Sources/Features/VibeFive/CountdownRing.swift:90
- “Stopped with {n} seconds left” [VoiceOver][template] — Sources/Features/VibeFive/CountdownRing.swift:91
- “{n} seconds remaining” [VoiceOver][template] — Sources/Features/VibeFive/CountdownRing.swift:92

**The one big button**

- “START” (ready, and again to start the clock) — Sources/Features/VibeFive/VibeFiveModel.swift:113
- “Done!” (while the clock runs) — Sources/Features/VibeFive/VibeFiveModel.swift:115
- “NEXT” (after a stop or a buzz) — Sources/Features/VibeFive/VibeFiveModel.swift:116
- “Reveals a category” [VoiceOver] — Sources/Features/VibeFive/VibeFiveView.swift:301
- “Starts the five second clock” [VoiceOver] — Sources/Features/VibeFive/VibeFiveView.swift:303
- “Ends the round early” [VoiceOver] — Sources/Features/VibeFive/VibeFiveView.swift:305
- “Deals the next category” [VoiceOver] — Sources/Features/VibeFive/VibeFiveView.swift:307
- “Reveals the next category” [VoiceOver] — Sources/Features/VibeFive/VibeFiveView.swift:309

**Settings sheet**

- “Game Settings” (sheet title) — Sources/Features/VibeFive/VibeFiveSettingsView.swift:22
- “Done” — Sources/Features/VibeFive/VibeFiveSettingsView.swift:26
- “Feedback” (section title) — Sources/Features/VibeFive/VibeFiveSettingsView.swift:39
- “Buzzer & ticks” — Sources/Features/VibeFive/VibeFiveSettingsView.swift:44
- “Plays even in silent mode” — Sources/Features/VibeFive/VibeFiveSettingsView.swift:45
- “Haptics” — Sources/Features/VibeFive/VibeFiveSettingsView.swift:58
- “Ticks and a jolt when time runs out” — Sources/Features/VibeFive/VibeFiveSettingsView.swift:60
- “Category packs” (section title) — Sources/Features/VibeFive/VibeFiveSettingsView.swift:76
- “Clear” / “All” (toggle every pack) — Sources/Features/VibeFive/VibeFiveSettingsView.swift:78
- “At least one pack always stays on.” — Sources/Features/VibeFive/VibeFiveSettingsView.swift:94
- “{n} categories · {n} of 11 packs” [template] (summary line) — Sources/Features/VibeFive/VibeFiveSettingsView.swift:105

**Category pack names and blurbs** (`Sources/Features/VibeFive/CategoryPack.swift`)

- “Everyday Life” (title) — Sources/Features/VibeFive/CategoryPack.swift:32
- “Kitchens, pockets and junk drawers” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:65
- “Food & Drink” (title) — Sources/Features/VibeFive/CategoryPack.swift:33
- “Meals, snacks and ingredients” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:66
- “Animals & Nature” (title) — Sources/Features/VibeFive/CategoryPack.swift:34
- “Creatures, weather and the outdoors” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:67
- “Movies & Cinema” (title) — Sources/Features/VibeFive/CategoryPack.swift:35
- “Films, genres and cinema trips” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:68
- “Music” (title) — Sources/Features/VibeFive/CategoryPack.swift:36
- “Songs, artists and instruments” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:69
- “TV & Streaming” (title) — Sources/Features/VibeFive/CategoryPack.swift:37
- “Shows, series and streaming” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:70
- “Places & Travel” (title) — Sources/Features/VibeFive/CategoryPack.swift:38
- “Cities, trips and packing lists” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:71
- “Sports” (title) — Sources/Features/VibeFive/CategoryPack.swift:39
- “Athletes, matches and the gym” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:72
- “Games & Play” (title) — Sources/Features/VibeFive/CategoryPack.swift:40
- “Boards, cards, consoles and toys” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:73
- “People & Jobs” (title) — Sources/Features/VibeFive/CategoryPack.swift:41
- “Jobs, habits and awkward moments” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:74
- “Random & Silly” (title) — Sources/Features/VibeFive/CategoryPack.swift:42
- “Daft debates and silly what-ifs” (blurb) — Sources/Features/VibeFive/CategoryPack.swift:75

**Other model strings**

- “Anything you like” (fallback category, only reachable if every pack is empty) — Sources/Features/VibeFive/VibeFiveModel.swift:264

### Word Vibe

`Sources/Features/VibeWords/VibeWordsView.swift`, `VibeWordsModel.swift`,
`VibeWordsSettingsView.swift`, `VibeWordsBoardView.swift`, `VibeWordsKeyboardView.swift`.

**Lobby**

- “WORD VIBE” (header title) — Sources/Features/VibeWords/VibeWordsView.swift:77
- “Five letters. Six tries. First to solve wins.” (header subtitle) — Sources/Features/VibeWords/VibeWordsView.swift:77
- “Play on this device” — Sources/Features/VibeWords/VibeWordsView.swift:84
- “A fresh word, no connection needed” — Sources/Features/VibeWords/VibeWordsView.swift:85
- “Start a game with friends” — Sources/Features/VibeWords/VibeWordsView.swift:97
- “You get a code to share” — Sources/Features/VibeWords/VibeWordsView.swift:98
- “JOIN WITH A CODE” (join card heading) — Sources/Features/VibeWords/VibeWordsView.swift:173
- “cars feed” (join field placeholder) — Sources/Features/VibeWords/VibeWordsView.swift:179
- “Join” (join button) — Sources/Features/VibeWords/VibeWordsView.swift:195
- “Everyone plays the same word on their own device. First to guess it wins.” (lobby footer) — Sources/Features/VibeWords/VibeWordsView.swift:108

**The game screen**

- “{n} player · code {code}” / “{n} players · code {code}” [template] (shared header subtitle) — Sources/Features/VibeWords/VibeWordsView.swift:271
- “Solo game” (solo header subtitle) — Sources/Features/VibeWords/VibeWordsView.swift:273
- “Next word in” (countdown caption) — Sources/Features/VibeWords/VibeWordsView.swift:310
- “{name} solved it first.” (winner banner) — Sources/Features/VibeWords/VibeWordsView.swift:326
- “Start when everyone has joined.” (host waiting line) — Sources/Features/VibeWords/VibeWordsView.swift:347
- “Waiting for {host} to start…” [template] — Sources/Features/VibeWords/VibeWordsView.swift:348
- “Start game” (host button) — Sources/Features/VibeWords/VibeWordsView.swift:354
- “Back to games” / “Leave game” [VoiceOver] — Sources/Features/VibeWords/VibeWordsView.swift:380
- “Share game code” [VoiceOver] — Sources/Features/VibeWords/VibeWordsView.swift:395

**Round over**

- “Solved!” (title when this player got it) — Sources/Features/VibeWords/VibeWordsView.swift:291
- “{name} solved it first” [template] (title when somebody else did) — Sources/Features/VibeWords/VibeWordsView.swift:293
- “The word was {answer}” [template] (title when nobody did) — Sources/Features/VibeWords/VibeWordsView.swift:295
- “{name} got there first, mind. The next one is a new word.” [template] — Sources/Features/VibeWords/VibeWordsView.swift:300
- “In {n} guesses” [template] — Sources/Features/VibeWords/VibeWordsView.swift:302
- “The next one is a new word.” — Sources/Features/VibeWords/VibeWordsView.swift:303

**Refusals, errors and saved-game summaries**

- “Not enough letters” — Sources/Features/VibeWords/VibeWordsModel.swift:357
- “Not in word list” — Sources/Features/VibeWords/VibeWordsModel.swift:359
- “Solved it!” — Sources/Features/VibeWords/VibeWordsModel.swift:378
- “Out of guesses. The word was {answer}.” [template] — Sources/Features/VibeWords/VibeWordsModel.swift:382
- “Solved — but the room could not be told.” — Sources/Features/VibeWords/VibeWordsModel.swift:405
- “Could not create the game: {reason}” [template] — Sources/Features/VibeWords/VibeWordsModel.swift:222
- “Could not join that game: {reason}” [template] — Sources/Features/VibeWords/VibeWordsModel.swift:247
- “Could not start the game: {reason}” [template] — Sources/Features/VibeWords/VibeWordsModel.swift:258
- “Could not start the next round: {reason}” [template] — Sources/Features/VibeWords/VibeWordsModel.swift:426
- “Playing with friends needs a game service.” (no backend) — Sources/Features/VibeWords/VibeWordsModel.swift:121
- “A word is waiting, with every guess left.” (solo-resume summary, no guesses yet) — Sources/Features/VibeWords/VibeWordsModel.swift:169
- “{n} of 6 guesses used” [template] (solo-resume summary) — Sources/Features/VibeWords/VibeWordsModel.swift:170

**Board and keyboard, spoken**

- “Guess grid” [VoiceOver] — Sources/Features/VibeWords/VibeWordsBoardView.swift:29
- “{n} of 6 guesses used” [VoiceOver][template] — Sources/Features/VibeWords/VibeWordsBoardView.swift:30
- “Empty” [VoiceOver] (empty tile) — Sources/Features/VibeWords/VibeWordsBoardView.swift:152
- “Submit guess” [VoiceOver] (return key) — Sources/Features/VibeWords/VibeWordsKeyboardView.swift:162
- “Delete letter” [VoiceOver] (backspace key) — Sources/Features/VibeWords/VibeWordsKeyboardView.swift:163
- “correct” / “in the word” / “not in the word” / “not tried” [VoiceOver] (key hint) — Sources/Features/VibeWords/VibeWordsKeyboardView.swift:171

**Settings sheet**

- “Game Settings” (sheet title) — Sources/Features/VibeWords/VibeWordsSettingsView.swift:21
- “Done” — Sources/Features/VibeWords/VibeWordsSettingsView.swift:25

### Number Vibe

`Sources/Features/VibeSudoku/VibeSudokuView.swift`, `VibeSudokuModel.swift`,
`VibeSudokuSettingsView.swift`, `SudokuKeypadView.swift`, `SudokuBoardView.swift`,
`Sources/Features/VibeSudoku/SudokuPuzzle.swift`.

**Lobby**

- “NUMBER VIBE” (header title) — Sources/Features/VibeSudoku/VibeSudokuView.swift:79
- “Fill the grid. First to finish wins.” (header subtitle) — Sources/Features/VibeSudoku/VibeSudokuView.swift:80
- “DIFFICULTY” (card heading) — Sources/Features/VibeSudoku/VibeSudokuView.swift:103
- “Solo and hosted games” (card note) — Sources/Features/VibeSudoku/VibeSudokuView.swift:105
- “Difficulty” (picker label) — Sources/Features/VibeSudoku/VibeSudokuView.swift:113
- “Easy” / “Singles all the way down” — Sources/Features/VibeSudoku/SudokuPuzzle.swift:14 / :62
- “Medium” / “Needs pairs and locked candidates” — Sources/Features/VibeSudoku/SudokuPuzzle.swift:15 / :63
- “Hard” / “Sparse, and needs real technique” — Sources/Features/VibeSudoku/SudokuPuzzle.swift:16 / :64
- “Play on this device” — Sources/Features/VibeSudoku/VibeSudokuView.swift:137
- “{difficulty} puzzle, no connection needed” [template] — Sources/Features/VibeSudoku/VibeSudokuView.swift:138
- “Race your friends” — Sources/Features/VibeSudoku/VibeSudokuView.swift:146
- “You pick the board, everyone races it” — Sources/Features/VibeSudoku/VibeSudokuView.swift:147
- “JOIN WITH A CODE” — Sources/Features/VibeSudoku/VibeSudokuView.swift:157
- “cars feed” (join field placeholder) — Sources/Features/VibeSudoku/VibeSudokuView.swift:163
- “Join” — Sources/Features/VibeSudoku/VibeSudokuView.swift:179

**The game screen**

- “{difficulty} · {time} · {n}/81 · code {code}” [template] (shared header subtitle) — Sources/Features/VibeSudoku/VibeSudokuView.swift:311
- “Solo · {difficulty} · {time} · {n}/81” [template] (solo header subtitle) — Sources/Features/VibeSudoku/VibeSudokuView.swift:311
- “Next puzzle in” (countdown caption) — Sources/Features/VibeSudoku/VibeSudokuView.swift:374
- “{name} solved it first.” (winner banner) — Sources/Features/VibeSudoku/VibeSudokuView.swift:392
- “Read this out — everyone joins with it.” (host's code hint) — Sources/Features/VibeSudoku/VibeSudokuView.swift:409
- “Start when everyone has joined. Everyone races the same {difficulty} board.” [template] — Sources/Features/VibeSudoku/VibeSudokuView.swift:413
- “Waiting for {host} to start…” [template] — Sources/Features/VibeSudoku/VibeSudokuView.swift:414
- “Start game” — Sources/Features/VibeSudoku/VibeSudokuView.swift:420
- “Back to games” / “Leave game” [VoiceOver] — Sources/Features/VibeSudoku/VibeSudokuView.swift:443
- “Share game code” [VoiceOver] — Sources/Features/VibeSudoku/VibeSudokuView.swift:460

**Round over**

- “Solved!” (title) — Sources/Features/VibeSudoku/VibeSudokuView.swift:329
- “{name} got there first, mind. The next board is a new one.” [template] — Sources/Features/VibeSudoku/VibeSudokuView.swift:348
- “{n} of 81 · {time}” [template] — Sources/Features/VibeSudoku/VibeSudokuView.swift:350
- “Next board” (heading over the next-difficulty picker) — Sources/Features/VibeSudoku/VibeSudokuView.swift:355
- “Difficulty for the next board” (picker label) — Sources/Features/VibeSudoku/VibeSudokuView.swift:360

**Refusals, errors and saved-game summaries**

- “Notes hold {n} numbers.” [template] — Sources/Features/VibeSudoku/VibeSudokuModel.swift:385
- “Solved — but the room could not be told.” — Sources/Features/VibeSudoku/VibeSudokuModel.swift:450
- “Could not create the game: {reason}” [template] — Sources/Features/VibeSudoku/VibeSudokuModel.swift:208
- “Could not join that game: {reason}” [template] — Sources/Features/VibeSudoku/VibeSudokuModel.swift:233
- “Could not start the game: {reason}” [template] — Sources/Features/VibeSudoku/VibeSudokuModel.swift:244
- “Could not start the next round: {reason}” [template] — Sources/Features/VibeSudoku/VibeSudokuModel.swift:474
- “Playing with friends needs a game service.” — Sources/Features/VibeSudoku/VibeSudokuModel.swift:99
- “{n} of 81 squares filled” [template] (solo-resume summary) — Sources/Features/VibeSudoku/VibeSudokuModel.swift:154
- “{time}” [template] (elapsed clock in the header) — Sources/Features/VibeSudoku/VibeSudokuModel.swift:104

**Board and keypad, spoken**

- “Sudoku grid” [VoiceOver] — Sources/Features/VibeSudoku/SudokuBoardView.swift:42
- “{n} of 81 cells filled” [VoiceOver][template] — Sources/Features/VibeSudoku/SudokuBoardView.swift:43
- “row {n}, column {n}, empty” [VoiceOver][template] — Sources/Features/VibeSudoku/SudokuBoardView.swift:154
- “row {n}, column {n}, notes {n n n}” [VoiceOver][template] — Sources/Features/VibeSudoku/SudokuBoardView.swift:160
- “row {n}, column {n}, {value}, given” [VoiceOver][template] — Sources/Features/VibeSudoku/SudokuBoardView.swift:163
- “, selected” [VoiceOver] (appended to the focused cell) — Sources/Features/VibeSudoku/SudokuBoardView.swift:155
- “NOTES” / “NOTES ON” (keypad toggle) — Sources/Features/VibeSudoku/SudokuKeypadView.swift:33
- “ERASE” (keypad) — Sources/Features/VibeSudoku/SudokuKeypadView.swift:41

**Settings sheet**

- “Game Settings” (sheet title) — Sources/Features/VibeSudoku/VibeSudokuSettingsView.swift:29
- “Done” — Sources/Features/VibeSudoku/VibeSudokuSettingsView.swift:33
- “Notes per square” (section title) — Sources/Features/VibeSudoku/VibeSudokuSettingsView.swift:47
- “Nine marks per square” — Sources/Features/VibeSudoku/VibeSudokuSettingsView.swift:50
- “Off draws four big ones. On draws every candidate, three by three.” — Sources/Features/VibeSudoku/VibeSudokuSettingsView.swift:52
- “A square can hold nine candidates, and four of them make a hard puzzle harder. Nine are every candidate, each in its own little box, the way pencil marks are read on paper — but nine marks in a phone-sized square are hard to read, and an unreadable note is worse than no note at all. Whichever you pick is kept for next time.” (explanation) — Sources/Features/VibeSudoku/VibeSudokuSettingsView.swift:66

### Vibe Pairings

`Sources/Features/VibeTrio/VibeTrioView.swift`, `VibeTrioModel.swift`,
`VibeTrioSettingsView.swift`, `TrioCardView.swift`.

**Lobby**

- “VIBE PAIRINGS” (header title) — Sources/Features/VibeTrio/VibeTrioView.swift:70
- “Three cards. Every feature same or different.” (header subtitle) — Sources/Features/VibeTrio/VibeTrioView.swift:71
- “Play on this device” — Sources/Features/VibeTrio/VibeTrioView.swift:77
- “Clear the whole deck at your own pace” — Sources/Features/VibeTrio/VibeTrioView.swift:78
- “Race your friends” — Sources/Features/VibeTrio/VibeTrioView.swift:88
- “One table of cards. Take a good pairing before anyone else does.” — Sources/Features/VibeTrio/VibeTrioView.swift:89
- “JOIN WITH A CODE” — Sources/Features/VibeTrio/VibeTrioView.swift:117
- “cars feed” (join field placeholder) — Sources/Features/VibeTrio/VibeTrioView.swift:123
- “Join” — Sources/Features/VibeTrio/VibeTrioView.swift:139

**The game screen**

- “VIBE PAIRINGS” (header title) — Sources/Features/VibeTrio/VibeTrioView.swift:241
- “{n} player · {n} good pairing · {time} · code {code}” [template] (shared header subtitle) — Sources/Features/VibeTrio/VibeTrioView.swift:252
- “{n} good pairing · {time}” [template] (solo header subtitle) — Sources/Features/VibeTrio/VibeTrioView.swift:252
- “Hint” (button) — Sources/Features/VibeTrio/VibeTrioView.swift:365
- “Race — no hints” (shown when the host turned hints off) — Sources/Features/VibeTrio/VibeTrioView.swift:381
- “{n} left in the deck” [template] — Sources/Features/VibeTrio/VibeTrioView.swift:389
- “Next deal in” (countdown caption) — Sources/Features/VibeTrio/VibeTrioView.swift:404
- “Read this out — everyone joins with it.” (host's code hint) — Sources/Features/VibeTrio/VibeTrioView.swift:534
- “Start when everyone has joined. Clear the deck together — first good pairing taken is yours.” — Sources/Features/VibeTrio/VibeTrioView.swift:538
- “Waiting for {host} to start…” [template] — Sources/Features/VibeTrio/VibeTrioView.swift:539
- “Start game” — Sources/Features/VibeTrio/VibeTrioView.swift:545
- “Back to games” / “Leave game” [VoiceOver] — Sources/Features/VibeTrio/VibeTrioView.swift:568
- “Share game code” [VoiceOver] — Sources/Features/VibeTrio/VibeTrioView.swift:583

**Round over and standings**

- “Nobody cleared a good pairing this time.” (empty standings) — Sources/Features/VibeTrio/VibeTrioView.swift:462
- “Deck cleared” (solo result title) — Sources/Features/VibeTrio/VibeTrioView.swift:486
- “Nobody scored” (shared result title) — Sources/Features/VibeTrio/VibeTrioView.swift:489
- “You win!” (shared result title) — Sources/Features/VibeTrio/VibeTrioView.swift:490
- “{name} wins” [template] — Sources/Features/VibeTrio/VibeTrioView.swift:490
- “Tie at {n}” [template] — Sources/Features/VibeTrio/VibeTrioView.swift:491
- “{time} · {n} player(s)” [template] (shared detail) — Sources/Features/VibeTrio/VibeTrioView.swift:447
- “{n} good pairing(s) in {time}” [template] (solo detail) — Sources/Features/VibeTrio/VibeTrioView.swift:449
- “{rank}” / “{name}” / “{score}” [template] (a standings row) — Sources/Features/VibeTrio/VibeTrioView.swift:497

**Refusals, errors and saved-game summaries**

- “{n} trio taken” / “{n} trios taken” [template] (solo-resume summary) — Sources/Features/VibeTrio/VibeTrioModel.swift:212
- “Someone got there first!” (default conflict notice) — Sources/Features/VibeTrio/VibeTrioService.swift:113
- “A new deal started — try that again.” (conflict notice when the deal has moved on) — Sources/Features/VibeTrio/VibeTrioModel.swift:548
- “Could not reach the game. Check your connection.” — Sources/Features/VibeTrio/VibeTrioModel.swift:553
- “Could not change the hint setting: {reason}” [template] — Sources/Features/VibeTrio/VibeTrioModel.swift:101
- “Could not create the game: {reason}” [template] — Sources/Features/VibeTrio/VibeTrioModel.swift:276
- “Could not join that game: {reason}” [template] — Sources/Features/VibeTrio/VibeTrioModel.swift:296
- “Could not start the game: {reason}” [template] — Sources/Features/VibeTrio/VibeTrioModel.swift:307
- “Could not start the next game: {reason}” [template] — Sources/Features/VibeTrio/VibeTrioModel.swift:576
- “Playing with friends needs a game service.” — Sources/Features/VibeTrio/VibeTrioModel.swift:157
- “You” (your own name in the solo standings) — Sources/Features/VibeTrio/VibeTrioModel.swift:127
- “Player” (fallback for a player with no readable name) — Sources/Features/VibeTrio/VibeTrioModel.swift:133

**Cards, spoken**

- “{platter}, {cheese}, {meat}, {garnish}” [VoiceOver][template] — Sources/Features/VibeTrio/TrioCard.swift:132
- “Face-down card” [VoiceOver] — Sources/Features/VibeTrio/TrioCardView.swift:124

**Settings sheet**

- “Game Settings” (sheet title) — Sources/Features/VibeTrio/VibeTrioSettingsView.swift:24
- “Done” — Sources/Features/VibeTrio/VibeTrioSettingsView.swift:28
- “Hints” (section title) — Sources/Features/VibeTrio/VibeTrioSettingsView.swift:47
- “Hints in this race” — Sources/Features/VibeTrio/VibeTrioSettingsView.swift:52
- “On gives every player the Hint button” — Sources/Features/VibeTrio/VibeTrioSettingsView.swift:53
- “On, for everybody” (read-only, hints on) — Sources/Features/VibeTrio/VibeTrioSettingsView.swift:66
- “Off, for everybody — only the host can change it, before the start” (read-only, hints off) — Sources/Features/VibeTrio/VibeTrioSettingsView.swift:67

### Similar Vibe

`Sources/Features/VibeBlurt/VibeBlurtView.swift`, `VibeBlurtModel.swift`,
`VibeBlurtSettingsView.swift`, `BlurtEngine.swift`.

**Lobby**

- “SIMILAR VIBE” (header title) — Sources/Features/VibeBlurt/VibeBlurtView.swift:90
- “Describe it. Don't say it.” (header subtitle) — Sources/Features/VibeBlurt/VibeBlurtView.swift:91
- “Start a game” — Sources/Features/VibeBlurt/VibeBlurtView.swift:97
- “Everyone joins on their own device” — Sources/Features/VibeBlurt/VibeBlurtView.swift:98
- “JOIN WITH A CODE” — Sources/Features/VibeBlurt/VibeBlurtView.swift:118
- “cars feed” (join field placeholder) — Sources/Features/VibeBlurt/VibeBlurtView.swift:124
- “Join” — Sources/Features/VibeBlurt/VibeBlurtView.swift:138

**Before the start**

- “SIMILAR VIBE” / “Waiting to start” (header) — Sources/Features/VibeBlurt/VibeBlurtView.swift:173
- “Everyone else: Similar Vibe → Join with a code” (code hint) — Sources/Features/VibeBlurt/VibeBlurtView.swift:225
- “Start” (host button) — Sources/Features/VibeBlurt/VibeBlurtView.swift:183
- “Teams are picked at random, so nobody can argue.” (host hint when the room is big enough) — Sources/Features/VibeBlurt/VibeBlurtModel.swift:281
- “You need 4 people — two on each team. {n} more to go.” [template] (host hint when it is not) — Sources/Features/VibeBlurt/VibeBlurtModel.swift:283
- “Waiting for {host} to start.” [template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:204
- “Settings” (settings card title) — Sources/Features/VibeBlurt/VibeBlurtView.swift:288
- “all 8 packs” (settings card summary, every pack on) — Sources/Features/VibeBlurt/VibeBlurtView.swift:322
- “{n} of 8 packs” [template] (settings card summary) — Sources/Features/VibeBlurt/VibeBlurtView.swift:323
- “IN THE ROOM ({n})” [template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:328
- “you” (marker beside your own name) — Sources/Features/VibeBlurt/VibeBlurtView.swift:344
- “Share” (share sheet button) — Sources/Features/VibeBlurt/VibeBlurtView.swift:250

**Scoreboard and clock**

- “Team One” / “Team Two” — Sources/Features/VibeBlurt/BlurtEngine.swift:15
- “YOUR TEAM” (badge on your own side) — Sources/Features/VibeBlurt/VibeBlurtView.swift:428
- “{team}: {score}, {names}, your team” [VoiceOver][template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:452
- “Time is nearly up” [VoiceOver] — Sources/Features/VibeBlurt/VibeBlurtView.swift:493
- “Time is running” [VoiceOver] — Sources/Features/VibeBlurt/VibeBlurtView.swift:493

**A turn: describing, buzzing, guessing**

- “YOUR WORD — DON'T SAY IT” (describer caption) — Sources/Features/VibeBlurt/VibeBlurtView.swift:500
- “Got it — pass it on” (describer button) — Sources/Features/VibeBlurt/VibeBlurtView.swift:529
- “The word goes to the other team. The clock keeps running.” — Sources/Features/VibeBlurt/VibeBlurtView.swift:542
- “WATCH FOR IT” (other team's caption) — Sources/Features/VibeBlurt/VibeBlurtView.swift:560
- “Watch close — if they say the word above, buzz them!” (buzz rule, no describer name) — Sources/Features/VibeBlurt/VibeBlurtView.swift:590
- “Watch close — if {name} says the word above, buzz them!” [template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:591
- “BUZZ” (the big red button) — Sources/Features/VibeBlurt/VibeBlurtView.swift:601
- “Buzz” [VoiceOver] (no describer name) — Sources/Features/VibeBlurt/VibeBlurtView.swift:612
- “Buzz — {name} said the word” [VoiceOver][template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:613
- “Saying any part of it counts too.” — Sources/Features/VibeBlurt/VibeBlurtView.swift:615
- “GUESS IT” (holding team's caption) — Sources/Features/VibeBlurt/VibeBlurtView.swift:626
- “{name} is describing a word to you” [template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:631
- “Shout it out!” — Sources/Features/VibeBlurt/VibeBlurtView.swift:640
- “Get it right and the word passes to the other team — the clock keeps running.” — Sources/Features/VibeBlurt/VibeBlurtView.swift:645

**Between turns**

- “Round over” (result line when no point was awarded) — Sources/Features/VibeBlurt/VibeBlurtModel.swift:219
- “{team} takes the point — caught a giveaway” [template] — Sources/Features/VibeBlurt/VibeBlurtModel.swift:221
- “{team} takes the point — the clock ran out” [template] — Sources/Features/VibeBlurt/VibeBlurtModel.swift:222
- “You're up” (it is your turn to describe) — Sources/Features/VibeBlurt/VibeBlurtView.swift:686
- “Nobody is left to describe” — Sources/Features/VibeBlurt/VibeBlurtView.swift:688
- “{name} is up” [template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:689
- “You're on {team} — guessing” [template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:696
- “You're on {team} — watching” [template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:696
- “Hold the device so only you can see it, then start the clock.” — Sources/Features/VibeBlurt/VibeBlurtView.swift:703
- “They have left the room, and nothing is running yet. Anyone on their team can take the round.” — Sources/Features/VibeBlurt/VibeBlurtView.swift:705
- “Nobody on that side is in the room, so there is no round to take.” — Sources/Features/VibeBlurt/VibeBlurtView.swift:707
- “Pass the device to {name}. Everyone else, watch for the word.” [template] — Sources/Features/VibeBlurt/VibeBlurtView.swift:708
- “Start the clock” (button) — Sources/Features/VibeBlurt/VibeBlurtView.swift:718

**Finished**

- “SIMILAR VIBE” / “That's the game” (header) — Sources/Features/VibeBlurt/VibeBlurtView.swift:739
- “{team} wins” [template] (round-over title) — Sources/Features/VibeBlurt/VibeBlurtView.swift:745
- “{one} – {two}” [template] (round-over detail, the two scores) — Sources/Features/VibeBlurt/VibeBlurtView.swift:746
- “First to 7” (header subtitle, solo) — Sources/Features/VibeBlurt/VibeBlurtView.swift:797
- “First to 7 · code {code}” [template] (header subtitle, shared) — Sources/Features/VibeBlurt/VibeBlurtView.swift:798
- “Back to games” / “Leave game” [VoiceOver] — Sources/Features/VibeBlurt/VibeBlurtView.swift:805
- “Share game code” [VoiceOver] — Sources/Features/VibeBlurt/VibeBlurtView.swift:818
- “Game code” [VoiceOver] (code button once the game is under way) — Sources/Features/VibeBlurt/VibeBlurtView.swift:839

**Refusals and errors**

- “Could not create the game: {reason}” [template] — Sources/Features/VibeBlurt/VibeBlurtModel.swift:306
- “Could not join that game: {reason}” [template] — Sources/Features/VibeBlurt/VibeBlurtModel.swift:325
- “Could not start the game: {reason}” [template] — Sources/Features/VibeBlurt/VibeBlurtModel.swift:383

**Settings sheet**

- “Game Settings” (sheet title) — Sources/Features/VibeBlurt/VibeBlurtSettingsView.swift:31
- “Done” — Sources/Features/VibeBlurt/VibeBlurtSettingsView.swift:35
- “Words” (section title) — Sources/Features/VibeBlurt/VibeBlurtSettingsView.swift:49
- “{n} words in the deck” [template] — Sources/Features/VibeBlurt/VibeBlurtSettingsView.swift:108

**Word pack names and blurbs** (`Sources/Features/VibeBlurt/BlurtPack.swift`)

- “Food & Drink” (title) — Sources/Features/VibeBlurt/BlurtPack.swift:19
- “Meals, snacks and drinks” (blurb) — Sources/Features/VibeBlurt/BlurtPack.swift:47
- “Animals & Nature” (title) — Sources/Features/VibeBlurt/BlurtPack.swift:20
- “Creatures great and small” (blurb) — Sources/Features/VibeBlurt/BlurtPack.swift:48
- “Places & Travel” (title) — Sources/Features/VibeBlurt/BlurtPack.swift:21
- “Spots near and far” (blurb) — Sources/Features/VibeBlurt/BlurtPack.swift:49
- “Household Objects” (title) — Sources/Features/VibeBlurt/BlurtPack.swift:22
- “Things around the home” (blurb) — Sources/Features/VibeBlurt/BlurtPack.swift:50
- “Jobs & People” (title) — Sources/Features/VibeBlurt/BlurtPack.swift:23
- “Jobs and the people who do them” (blurb) — Sources/Features/VibeBlurt/BlurtPack.swift:51
- “Sport & Music” (title) — Sources/Features/VibeBlurt/BlurtPack.swift:24
- “Sports, games and music” (blurb) — Sources/Features/VibeBlurt/BlurtPack.swift:52
- “Actions & Situations” (title) — Sources/Features/VibeBlurt/BlurtPack.swift:25
- “Things people do” (blurb) — Sources/Features/VibeBlurt/BlurtPack.swift:53
- “Celebrations & Weather” (title) — Sources/Features/VibeBlurt/BlurtPack.swift:26
- “Festivals, celebrations and weather” (blurb) — Sources/Features/VibeBlurt/BlurtPack.swift:54

### Vibe Ten

`Sources/Features/VibeTen/VibeTenView.swift`, `VibeTenModel.swift`, `VibeTenBoard.swift`.

**Lobby**

- “VIBE TEN” (header title) — Sources/Features/VibeTen/VibeTenView.swift:94
- “Pair the digits, drop the ones above, clear the board.” (header subtitle) — Sources/Features/VibeTen/VibeTenView.swift:95
- “Play on this device” — Sources/Features/VibeTen/VibeTenView.swift:101
- “A board of your own, no connection needed” — Sources/Features/VibeTen/VibeTenView.swift:102
- “Race your friends” — Sources/Features/VibeTen/VibeTenView.swift:112
- “The same board for everyone. First to clear it wins.” — Sources/Features/VibeTen/VibeTenView.swift:113
- “JOIN WITH A CODE” — Sources/Features/VibeTen/VibeTenView.swift:133
- “cars feed” (join field placeholder) — Sources/Features/VibeTen/VibeTenView.swift:139
- “Join” — Sources/Features/VibeTen/VibeTenView.swift:155

**Waiting room**

- “VIBE TEN” / “Waiting to start” (header) — Sources/Features/VibeTen/VibeTenView.swift:191
- “Everyone else: Vibe Ten → Join with a code” (code hint) — Sources/Features/VibeTen/VibeTenView.swift:198
- “Start when everyone has joined. Everyone plays the same board.” — Sources/Features/VibeTen/VibeTenView.swift:201
- “Waiting for {host} to start…” [template] — Sources/Features/VibeTen/VibeTenView.swift:202
- “Start” — Sources/Features/VibeTen/VibeTenView.swift:211
- “IN THE ROOM ({n})” [template] — Sources/Features/VibeTen/VibeTenView.swift:233
- “Someone” (fallback for a player with no readable name) — Sources/Features/VibeTen/VibeTenView.swift:239

**The game screen**

- “Match the digits.” (header subtitle, before a board exists) — Sources/Features/VibeTen/VibeTenModel.swift:178
- “{n} player(s)” [template] (shared header subtitle, first part) — Sources/Features/VibeTen/VibeTenModel.swift:180
- “Solo · {n} pair(s) · {n} left to take” [template] (solo header subtitle) — Sources/Features/VibeTen/VibeTenModel.swift:183
- “Add {n} rows” [template] (new-row button) — Sources/Features/VibeTen/VibeTenView.swift:286
- “Add {n} rows at the bottom” [VoiceOver][template] — Sources/Features/VibeTen/VibeTenView.swift:301
- “Column {n} row {n}: {value}” [VoiceOver][template] — Sources/Features/VibeTen/VibeTenView.swift:405
- “Column {n} row {n}: {value}, taken” [VoiceOver][template] (dimmed cell) — Sources/Features/VibeTen/VibeTenView.swift:422

**Round over**

- “Cleared it!” (title, you cleared) — Sources/Features/VibeTen/VibeTenView.swift:467
- “{name} cleared it first” [template] — Sources/Features/VibeTen/VibeTenView.swift:467
- “No one cleared it” (shared, everybody finished) — Sources/Features/VibeTen/VibeTenView.swift:470
- “No moves left” (solo, out of moves) — Sources/Features/VibeTen/VibeTenView.swift:471
- “You cleared the board first. {n} pairs taken.” [template] — Sources/Features/VibeTen/VibeTenView.swift:479
- “{name} cleared the board first. {n} pairs taken.” [template] — Sources/Features/VibeTen/VibeTenView.swift:481
- “{n} pairs taken, and nobody cleared the board.” [template] — Sources/Features/VibeTen/VibeTenView.swift:484
- “{n} pairs taken. The room is still playing.” [template] — Sources/Features/VibeTen/VibeTenView.swift:486
- “Every digit gone. {n} pairs taken.” [template] — Sources/Features/VibeTen/VibeTenView.swift:489
- “{n} pairs taken, with no pairs left and no room for a new row.” [template] — Sources/Features/VibeTen/VibeTenView.swift:490
- “Retry this board” (primary button when a solo board can be retried) — Sources/Features/VibeTen/VibeTenView.swift:444
- “Play again” (primary button otherwise) — Sources/Features/VibeTen/VibeTenView.swift:444
- “New board” (secondary button when retrying) — Sources/Features/VibeTen/VibeTenView.swift:453
- “{rank}. {name}” [template] (standings row) — Sources/Features/VibeTen/VibeTenView.swift:497
- “cleared” (standings badge) — Sources/Features/VibeTen/VibeTenView.swift:505
- “playing” (standings badge) — Sources/Features/VibeTen/VibeTenView.swift:509

**Errors and saved-game summaries**

- “Could not create the game: {reason}” [template] — Sources/Features/VibeTen/VibeTenModel.swift:394
- “Could not join that game: {reason}” [template] — Sources/Features/VibeTen/VibeTenModel.swift:416
- “Could not start the game: {reason}” [template] — Sources/Features/VibeTen/VibeTenModel.swift:426
- “Could not deal the next board: {reason}” [template] — Sources/Features/VibeTen/VibeTenModel.swift:651
- “Playing with friends needs a game service.” — Sources/Features/VibeTen/VibeTenModel.swift:189
- “A board is waiting.” (solo-resume summary, no board yet) — Sources/Features/VibeTen/VibeTenModel.swift:295
- “{n} pair(s) taken, and the board is done.” [template] — Sources/Features/VibeTen/VibeTenModel.swift:297
- “{n} pair(s) taken · {n} digits left” [template] — Sources/Features/VibeTen/VibeTenModel.swift:298

**Settings sheet**

- “Game Settings” (sheet title) — Sources/Features/VibeTen/VibeTenView.swift:725
- “Done” — Sources/Features/VibeTen/VibeTenView.swift:729
- “The board” (section title) — Sources/Features/VibeTen/VibeTenView.swift:665
- “Choose how many rows to start with; the grid holds only eighteen rows at a time.” — Sources/Features/VibeTen/VibeTenView.swift:667
- “Start with” (picker label) — Sources/Features/VibeTen/VibeTenView.swift:672
- “Fewer starting rows means more room to grow. In a group game everybody starts with the same number of rows.” — Sources/Features/VibeTen/VibeTenView.swift:682
- “The board is set for this game. Start a new game to change the starting rows.” — Sources/Features/VibeTen/VibeTenView.swift:683
- “Rows to add” (label) — Sources/Features/VibeTen/VibeTenView.swift:690
- “Add two or four rows at a time.” — Sources/Features/VibeTen/VibeTenView.swift:704
- “In a group game the host sets how many rows are revealed at a time.” — Sources/Features/VibeTen/VibeTenView.swift:706
- “When a pair is matched” (section title and picker label) — Sources/Features/VibeTen/VibeTenView.swift:624
- “Remove” (mode title) — Sources/Features/VibeTen/VibeTenBoard.swift:16
- “A matched pair disappears and the digits above fall into the gap.” (mode blurb) — Sources/Features/VibeTen/VibeTenBoard.swift:24
- “Dim” (mode title) — Sources/Features/VibeTen/VibeTenBoard.swift:17
- “A matched pair dims and stays put. Dimmed digits are treated as empty, so a pair can be made across them. When every digit in a row is dimmed the row clears and everything below it rises one row.” (mode blurb) — Sources/Features/VibeTen/VibeTenBoard.swift:26
- “Choose it before you start. Pairs taken in Dim mode stay on the board.” — Sources/Features/VibeTen/VibeTenView.swift:641
- “In a room the host's rules are the game's rules. This room is playing the way it was created.” — Sources/Features/VibeTen/VibeTenView.swift:643
- “This game is using the setting it started with. Leave it to choose again.” — Sources/Features/VibeTen/VibeTenView.swift:644
- “Rows join end to end” — Sources/Features/VibeTen/VibeTenView.swift:651
- “The last square of a row is next to the first of the row below” — Sources/Features/VibeTen/VibeTenView.swift:652

### Utilities

`Sources/Features/Utilities/UtilitiesView.swift`, `DiceView.swift`, `FirstPlayerView.swift`,
`Sources/Model/UtilityCatalog.swift`.

**Utilities list**

- “UTILITIES” (header title) — Sources/Features/Utilities/UtilitiesView.swift:14
- “Tools for the table.” (header subtitle) — Sources/Features/Utilities/UtilitiesView.swift:15
- “Back to games” [VoiceOver] — Sources/Features/Utilities/UtilitiesView.swift:17
- “Opens the {tool}” [VoiceOver][template] (tile hint) — Sources/Features/Utilities/UtilitiesView.swift:30
- “More tools on the way.” (footer) — Sources/Features/Utilities/UtilitiesView.swift:39
- “Dice” (tile title) — Sources/Model/UtilityCatalog.swift:28
- “d4, d6, d8, d10, d12, d20. Roll one, or a handful.” (tile tagline) — Sources/Model/UtilityCatalog.swift:29
- “First Player” (tile title) — Sources/Model/UtilityCatalog.swift:36
- “One question, and the table knows who starts.” (tile tagline) — Sources/Model/UtilityCatalog.swift:37

**Dice**

- “DICE” (header title) — Sources/Features/Utilities/DiceView.swift:27
- “Tap a die to roll it.” (header subtitle, empty table) — Sources/Features/Utilities/DiceView.swift:66
- “{n} dice — the table is full” [template] (header subtitle) — Sources/Features/Utilities/DiceView.swift:69
- “{n} die(s) on the table” [template] (header subtitle) — Sources/Features/Utilities/DiceView.swift:70
- “Back to utilities” [VoiceOver] — Sources/Features/Utilities/DiceView.swift:29
- “Roll a d{n}” [VoiceOver][template] (die in the picker) — Sources/Features/Utilities/DiceView.swift:101
- “No dice yet” (empty table) — Sources/Features/Utilities/DiceView.swift:129
- “Tap one above to roll it.” (empty table helper) — Sources/Features/Utilities/DiceView.swift:133
- “d{n}” [template] (result column heading) — Sources/Features/Utilities/DiceView.swift:155
- “d{n}: {value}” [VoiceOver][template] (settled die) — Sources/Features/Utilities/DiceView.swift:239
- “d{n}: rolling” [VoiceOver][template] — Sources/Features/Utilities/DiceView.swift:239
- “Roll” (button) — Sources/Features/Utilities/DiceView.swift:256
- “Clear” (button) — Sources/Features/Utilities/DiceView.swift:275
- “No dice” / “{n} dice” [VoiceOver][template] (table summary) — Sources/Features/Utilities/DiceTableView.swift:24
- “d{n}: {value}” [VoiceOver][template] (a die on the table) — Sources/Features/Utilities/DiceTable.swift:408
- “Settings” (sheet title) — Sources/Features/Utilities/DiceView.swift:333
- “Done” — Sources/Features/Utilities/DiceView.swift:337

**First Player**

- “FIRST PLAYER” (header title) — Sources/Features/Utilities/FirstPlayerView.swift:23
- “One question, one answer.” (header subtitle) — Sources/Features/Utilities/FirstPlayerView.swift:24
- “Back to utilities” [VoiceOver] — Sources/Features/Utilities/FirstPlayerView.swift:26
- “Tap for another” (card footer) — Sources/Features/Utilities/FirstPlayerView.swift:75
- “{question} {seat instruction}.” [VoiceOver][template] (the whole card) — Sources/Features/Utilities/FirstPlayerView.swift:102
- “Draws another question” [VoiceOver] — Sources/Features/Utilities/FirstPlayerView.swift:103
- “That person goes first” (seat instruction) — Sources/Features/Utilities/FirstPlayer.swift:30
- “The person to their left goes first” — Sources/Features/Utilities/FirstPlayer.swift:31
- “The person to their right goes first” — Sources/Features/Utilities/FirstPlayer.swift:32
- “Settings” (sheet title) — Sources/Features/Utilities/FirstPlayerView.swift:133
- “Done” — Sources/Features/Utilities/FirstPlayerView.swift:137

The question bank the card draws from (“Who has the longest hair?”, “Whose
birthday is next?”, and 36 more) lives at `Sources/Features/Utilities/FirstPlayer.swift:57`
and is game content, not chrome; it is listed in section 5.

### Errors and system wording

- “Add GoogleService-Info.plist to enable playing with friends.” (no Firebase configuration) — Sources/Firebase/FirebaseBootstrapper.swift:28
- “Could not reach the game service: {reason}” [template] — Sources/Firebase/FirebaseBootstrapper.swift:30
- “Firebase did not initialise” (the `{reason}` the line above carries when configuration fails) — Sources/Firebase/FirebaseBootstrapper.swift:53
- “Join my {game} game — {link} — or open the app and enter code {CODE}.” [template] (the share text) — Sources/Model/GameInvite.swift:37
- “Vibe Games {version} ({build})” [template] — Sources/Features/Home/PreferencesView.swift:87

---

## 3. Web interface copy

The browser client at `play.vibegames.party`. Grouped by screen and game. Where a
string is word-for-word the same as the app's, it is marked “(same as app)” and
still listed. Accessibility labels are marked `[VoiceOver]` (they are read by
screen readers in the browser just as they are on iOS); ARIA roles, identifiers,
analytics keys, CSS classes and game content are excluded.

### Browser tab titles

`web/src/titles.ts`

- “Vibe Games — party games in your pocket” — web/src/titles.ts:15
- “Vibe Five — name three things, fast” — web/src/titles.ts:16
- “Word Vibe — guess the five-letter word” — web/src/titles.ts:17
- “Number Vibe — fill the grid” — web/src/titles.ts:18
- “Vibe Pairings — find three that match” — web/src/titles.ts:19
- “Similar Vibe — describe it, don’t say it” — web/src/titles.ts:20
- “Vibe Ten — pair the digits, clear the board” — web/src/titles.ts:21

`web/src/App.tsx` is the route switch and carries no user-visible text of its own.

### Hub

`web/src/hub/Hub.tsx`, `web/src/hub/catalog.tsx`.

- “Vibe Games” (hub title) — web/src/hub/Hub.tsx:16
- “Quick party games. Grab a phone, pass it round.” (tagline) — web/src/hub/Hub.tsx:25
- “Soon” (badge on an unreleased tile) — web/src/hub/Hub.tsx:55
- “{title}, coming soon” [VoiceOver][template] (unavailable tile) — web/src/hub/Hub.tsx:48
- “About Vibe Games” (footer link) — web/src/hub/Hub.tsx:75
- “Support” (footer link) — web/src/hub/Hub.tsx:77
- “Privacy” (footer link) — web/src/hub/Hub.tsx:79

**Game tiles, in hub order** (`web/src/hub/catalog.tsx`)

- “Vibe Five” (tile title) — web/src/hub/catalog.tsx:65
- “Name three things before the buzzer.” (tile tagline) — web/src/hub/catalog.tsx:66
- “Word Vibe” (tile title) — web/src/hub/catalog.tsx:74
- “Guess the five-letter word. First to solve wins.” (tile tagline) — web/src/hub/catalog.tsx:75
- “Number Vibe” (tile title) — web/src/hub/catalog.tsx:83
- “Fill the grid. Race your friends to it.” (tile tagline) — web/src/hub/catalog.tsx:84
- “Vibe Pairings” (tile title) — web/src/hub/catalog.tsx:92
- “Three cards where every feature matches or differs.” (tile tagline) — web/src/hub/catalog.tsx:93
- “Vibe Ten” (tile title) — web/src/hub/catalog.tsx:101
- “Pair the digits. Clear the board. First to clear it wins.” (tile tagline) — web/src/hub/catalog.tsx:102
- “Similar Vibe” (tile title) — web/src/hub/catalog.tsx:110
- “Describe it. Don't say it. Two teams, one word.” (tile tagline) — web/src/hub/catalog.tsx:111

### Shared web chrome

`web/src/hub/HowToPlay.tsx`, `Lobby.tsx`, `GameHeader.tsx`, `BackToGames.tsx`,
`RoundOver.tsx`, `SoloResume.tsx`, `RoomCode.tsx`, `GameCodeBadge.tsx`,
`GameSettings.tsx`, `Support.tsx`.

**How to play shell** (same as app)

- “Back” (rules page button text) — web/src/hub/HowToPlay.tsx:36
- “Back” [VoiceOver] (the same button's label) — web/src/hub/HowToPlay.tsx:32
- “How to play” (rules page title) — web/src/hub/HowToPlay.tsx:39
- “Playing” (heading over bullets) — web/src/hub/HowToPlay.tsx:56
- “How to play” (link on every main page) — web/src/hub/HowToPlay.tsx:81

**Lobby shell**

- “Join with a code” (join form label) — web/src/hub/Lobby.tsx:52
- “cars feed” (join field placeholder) — web/src/hub/Lobby.tsx:58
- “Join” (join button) — web/src/hub/Lobby.tsx:64

**Header and back**

- “Leave game” [VoiceOver] (default back label in a game) — web/src/hub/GameHeader.tsx:70
- “Back to games” [VoiceOver] (back to hub) — web/src/hub/BackToGames.tsx:16
- “Games” (back button text) — web/src/hub/BackToGames.tsx:21

**Round over**

- “Play again” (primary button default) — web/src/hub/RoundOver.tsx:19

**Solo resume** (same as app)

- “A game is in progress” (dialog title and accessible name) — web/src/hub/SoloResume.tsx:25
- “A game is in progress” (visible heading) — web/src/hub/SoloResume.tsx:31
- “Continue” — web/src/hub/SoloResume.tsx:34
- “New game” — web/src/hub/SoloResume.tsx:37
- “Cancel” — web/src/hub/SoloResume.tsx:40

**Room code**

- “Game code” [VoiceOver] (header button) — web/src/hub/RoomCode.tsx:26
- “Game code” (dialog accessible name) — web/src/hub/RoomCode.tsx:59
- “Game code” (sheet heading) — web/src/hub/RoomCode.tsx:65
- “Read it out, or send the link. Anyone with it can join.” — web/src/hub/RoomCode.tsx:68
- “Link copied” / “Copy the link” (clipboard button) — web/src/hub/RoomCode.tsx:84
- “Done” (sheet button) — web/src/hub/RoomCode.tsx:88

**Code badge**

- “Game code” (caption) — web/src/hub/GameCodeBadge.tsx:38
- “Game code {code}” [VoiceOver][template] — web/src/hub/GameCodeBadge.tsx:41

**Settings sheet** (same as app)

- “Game settings” [VoiceOver] (sliders button and dialog name) — web/src/hub/GameSettings.tsx:51
- “Game settings” (sheet heading) — web/src/hub/GameSettings.tsx:90
- “Your name” (section heading) — web/src/hub/GameSettings.tsx:93
- “Forget it” (clears the stored name) — web/src/hub/GameSettings.tsx:103
- “Your name” (field placeholder and accessible name) — web/src/hub/GameSettings.tsx:111
- “Shown to everyone in a game you play together. Up to 24 characters.” — web/src/hub/GameSettings.tsx:125
- “Appearance” (section heading) — web/src/hub/GameSettings.tsx:127
- “System” / “Follow the device” — web/src/hub/GameSettings.tsx:27
- “Light” / “Always light” — web/src/hub/GameSettings.tsx:28
- “Dark” / “Always dark” — web/src/hub/GameSettings.tsx:29
- “Done” — web/src/hub/GameSettings.tsx:150

**Support panel**

- “Support Vibe Games” [VoiceOver] (heart button) — web/src/hub/Support.tsx:69
- “Support Vibe Games” (dialog accessible name) — web/src/hub/Support.tsx:110
- “Close” [VoiceOver] (panel close button) — web/src/hub/Support.tsx:112
- “Made with love” (heading) — web/src/hub/Support.tsx:120
- “I built these games for my own family. We play them in the evenings — it is how we wind down together and stay close — and I wanted to share that with other families.” — web/src/hub/Support.tsx:122
- “Other ways to help” (section heading) — web/src/hub/Support.tsx:129
- “Every game is free. Nothing to unlock, no adverts, no account. If you would like to say thanks, you could buy my family a treat to help cover what it costs to keep them running.” — web/src/hub/Support.tsx:132
- “Buy us a treat” (tip row) — web/src/hub/Support.tsx:149
- “Venmo @chill-gelato” (tip row detail) — web/src/hub/Support.tsx:150
- “Link copied” / “Share it with another family” (share row) — web/src/hub/Support.tsx:162
- “They can play in a browser tonight, free” (share row detail) — web/src/hub/Support.tsx:163
- “Copied” / “Copy the Venmo handle” (clipboard button) — web/src/hub/Support.tsx:172

**Feedback form**

- “Tell me what you think, or what is not working” (form label) — web/src/hub/Support.tsx:241
- “Ideas, bugs, a game you would like next — anything at all.” (textarea placeholder) — web/src/hub/Support.tsx:246
- “Sending…” / “Send” (button) — web/src/hub/Support.tsx:258
- “No account, no email address, nothing to sign up for — it reaches me as a note.” — web/src/hub/Support.tsx:261
- “No account, no email address, nothing to sign up for — it reaches me as a note about {game}.” [template] — web/src/hub/Support.tsx:261
- “Thank you — it arrived.” (sent state) — web/src/hub/Support.tsx:218
- “There is no reply by email, so this is where the note ends — it goes on the list and gets worked through. Found something else?” — web/src/hub/Support.tsx:221
- “Send another” — web/src/hub/Support.tsx:233
- “That did not go through. Please try again in a moment.” (send failure) — web/src/hub/Support.tsx:208
- “Please write a little more.” (too-short error) — web/src/games/feedback.ts:40
- “Please keep it under 2000 characters.” (too-long error) — web/src/games/feedback.ts:43

### Vibe Five

`web/src/games/five/VibeFive.tsx`, with labels from `web/src/games/five/model.ts`
and packs from `web/src/games/five/packs.ts`.

**How to play** (the web page's own wording; resolved counts: 995 categories in 11 packs)

- “Vibe Five” (page name) — web/src/games/five/VibeFive.tsx:91
- “A category, five seconds, and one device passed round the table. Name three things that fit before the buzzer.” (intro) — web/src/games/five/VibeFive.tsx:92
- “The category waits for you” (section title) — web/src/games/five/VibeFive.tsx:96
- “Press **START** and the category fills the screen with a GET READY badge. No timer is running and none is shown, so read it out, explain it, and argue about it for as long as you like.” — web/src/games/five/VibeFive.tsx:97
- “Then the clock” (section title) — web/src/games/five/VibeFive.tsx:100
- “Press **START** again when the table is ready. The dial appears and drains from five to zero, with a tick for each of the last three seconds. The dial appearing is the signal that time is running.” — web/src/games/five/VibeFive.tsx:101
- “How a round ends” (section title) — web/src/games/five/VibeFive.tsx:104
- “Either the clock runs out — the buzzer sounds and the screen flashes red — or the player presses **Done!** to end it early. Done! is deliberately silent, because the buzzer means the clock beat you. Either way the dial freezes on the time that was left.” — web/src/games/five/VibeFive.tsx:105
- “START — Deals a category. Nothing is running yet.” — web/src/games/five/VibeFive.tsx:109
- “Done! — Ends the round early. Silent, so the buzzer keeps its meaning.” — web/src/games/five/VibeFive.tsx:110
- “NEXT — Deals a fresh category and waits for you to start the clock again.” — web/src/games/five/VibeFive.tsx:111
- “Packs — 995 categories across 11 packs, switched on and off in Game Setup. Only the packs you leave on go into the deck, and no category comes round twice until the pool runs out.” — web/src/games/five/VibeFive.tsx:114

**The game screen**

- “Vibe Five” (header title) — web/src/games/five/VibeFive.tsx:243
- “Ready to play” (header subtitle before the first round) — web/src/games/five/VibeFive.tsx:244
- “Round {n}” [template] — web/src/games/five/VibeFive.tsx:244
- “Tap START to reveal a category” (empty card) — web/src/games/five/VibeFive.tsx:348
- “Read it out, then start the clock when you are ready” (empty card helper) — web/src/games/five/VibeFive.tsx:349
- “Category: {text}” [VoiceOver][template] — web/src/games/five/VibeFive.tsx:352
- “GET READY” (badge when a category is revealed) — web/src/games/five/model.ts:279
- “TIME'S UP!” (badge when the clock runs out) — web/src/games/five/model.ts:281
- “STOPPED” (badge when the round is ended early) — web/src/games/five/model.ts:283
- “START” (ready, and again to start the clock) — web/src/games/five/model.ts:251
- “Done!” (while the clock runs) — web/src/games/five/model.ts:253
- “NEXT” (after a stop or a buzz) — web/src/games/five/model.ts:255
- “Reveals a category” [VoiceOver] — web/src/games/five/model.ts:263
- “Starts the five second clock” [VoiceOver] — web/src/games/five/model.ts:265
- “Ends the round early” [VoiceOver] — web/src/games/five/model.ts:267
- “Deals the next category” [VoiceOver] — web/src/games/five/model.ts:269
- “Reveals the next category” [VoiceOver] — web/src/games/five/model.ts:271
- “Time is up” [VoiceOver] — web/src/games/five/VibeFive.tsx:395
- “Stopped with {n} seconds left” [VoiceOver][template] — web/src/games/five/VibeFive.tsx:397
- “{n} seconds remaining” [VoiceOver][template] — web/src/games/five/VibeFive.tsx:398
- “SECONDS” / “LEFT” / “TIME” (caption under the dial number) — web/src/games/five/VibeFive.tsx:429

**Settings sheet**

- “Feedback” (section title) — web/src/games/five/VibeFive.tsx:278
- “Sound” — web/src/games/five/VibeFive.tsx:280
- “Buzzer and ticks, even in silent mode” — web/src/games/five/VibeFive.tsx:281
- “Vibration” — web/src/games/five/VibeFive.tsx:286
- “Ticks, and a jolt when time runs out” — web/src/games/five/VibeFive.tsx:287
- “Category packs” (section title) — web/src/games/five/VibeFive.tsx:293
- “{n} categories in play” [template] — web/src/games/five/VibeFive.tsx:295
- “Select one” / “Select all” (toggle every pack) — web/src/games/five/VibeFive.tsx:297

**Category pack names and blurbs** (`web/src/games/five/packs.ts`, same as app)

- “Everyday Life” / “Kitchens, pockets and junk drawers” — web/src/games/five/packs.ts:36
- “Food & Drink” / “Meals, snacks and ingredients” — web/src/games/five/packs.ts:37
- “Animals & Nature” / “Creatures, weather and the outdoors” — web/src/games/five/packs.ts:38
- “Movies & Cinema” / “Films, genres and cinema trips” — web/src/games/five/packs.ts:39
- “Music” / “Songs, artists and instruments” — web/src/games/five/packs.ts:40
- “TV & Streaming” / “Shows, series and streaming” — web/src/games/five/packs.ts:41
- “Places & Travel” / “Cities, trips and packing lists” — web/src/games/five/packs.ts:42
- “Sports” / “Athletes, matches and the gym” — web/src/games/five/packs.ts:43
- “Games & Play” / “Boards, cards, consoles and toys” — web/src/games/five/packs.ts:44
- “People & Jobs” / “Jobs, habits and awkward moments” — web/src/games/five/packs.ts:45
- “Random & Silly” / “Daft debates and silly what-ifs” — web/src/games/five/packs.ts:46

### Word Vibe

`web/src/games/words/VibeWords.tsx`.

**How to play** (the web page's own wording; resolved counts: 14,855 words can be
guessed, 489 can be the answer)

- “Word Vibe” (page name) — web/src/games/words/VibeWords.tsx:38
- “Guess the five-letter word in six tries. Play solo, or start a game and race everyone on the same word.” (intro) — web/src/games/words/VibeWords.tsx:40
- “Reading the colours” (section title) — web/src/games/words/VibeWords.tsx:43
- “**Green** is the right letter in the right place. **Amber** means the letter is in the word but somewhere else. **Grey** means it is not in the word at all.” — web/src/games/words/VibeWords.tsx:44
- “Repeated letters” (section title) — web/src/games/words/VibeWords.tsx:47
- “Counted properly rather than one letter at a time. Exact matches are claimed first, and what is left of the answer then has to cover the rest: guessing EERIE against SPEED credits two Es and marks the third one absent.” — web/src/games/words/VibeWords.tsx:48
- “Solo — A fresh word, with no connection needed.” — web/src/games/words/VibeWords.tsx:52
- “With friends — You get a code to share — two short words, like cars feed — and everyone guesses the same word on their own device. The first to solve it is announced to the whole room.” — web/src/games/words/VibeWords.tsx:54
- “The words — 14855 can be guessed, and 489 of them can be the answer.” — web/src/games/words/VibeWords.tsx:58

**Lobby and shared game**

- “Word Vibe” (header title) — web/src/games/words/VibeWords.tsx:744
- “{n} player(s)” [template] (header subtitle) — web/src/games/words/VibeWords.tsx:749
- “Six guesses. Everyone gets the same word.” (lobby blurb) — web/src/games/words/VibeWords.tsx:779
- “Play on this device” — web/src/games/words/VibeWords.tsx:787
- “A word to yourself, and nobody waiting on you” — web/src/games/words/VibeWords.tsx:788
- “Race your friends” — web/src/games/words/VibeWords.tsx:792
- “The same word at the same time. First to solve it wins.” — web/src/games/words/VibeWords.tsx:793
- “Enter your name” (name field placeholder) — web/src/games/words/VibeWords.tsx:810
- “Continue” (name form button) — web/src/games/words/VibeWords.tsx:816
- “Enter your name so others know who won!” (name helper) — web/src/games/words/VibeWords.tsx:819
- “Create a game to get started!” — web/src/games/words/VibeWords.tsx:827
- “🎮 Create Game” — web/src/games/words/VibeWords.tsx:831
- “Copy game link” [VoiceOver] (copy button title) — web/src/games/words/VibeWords.tsx:833
- “Everyone else: Word Vibe → Join with a code” (code hint) — web/src/games/words/VibeWords.tsx:849
- “You created this game! Click start when everyone has joined.” — web/src/games/words/VibeWords.tsx:852
- “🚀 Start Game” — web/src/games/words/VibeWords.tsx:856
- “⏳ Waiting for the game creator to start the game...” — web/src/games/words/VibeWords.tsx:869
- “New game starting in...” (restart countdown) — web/src/games/words/VibeWords.tsx:878
- “🏆 {name} solved it first.” [template] (winner banner) — web/src/games/words/VibeWords.tsx:905
- “That does not look like a code” (join error) — web/src/games/words/VibeWords.tsx:636
- “Not enough letters” (refusal) — web/src/games/words/VibeWords.tsx:432
- “Not in word list” (refusal) — web/src/games/words/VibeWords.tsx:439
- “Congratulations! 🎉” (win message) — web/src/games/words/VibeWords.tsx:453
- “Game Over! The word was {answer}” [template] — web/src/games/words/VibeWords.tsx:470
- “Link copied! Share it with friends.” (share result) — web/src/games/words/VibeWords.tsx:730
- “Failed to copy. URL: {url}” [template] (share failure) — web/src/games/words/VibeWords.tsx:733
- “{n} of 6 guesses used” [template] (solo-resume summary) — web/src/games/words/VibeWords.tsx:123

**Round over**

- “Solved!” (title when this player got it) — web/src/games/words/VibeWords.tsx:913
- “{name} solved it first” [template] — web/src/games/words/VibeWords.tsx:915
- “The word was {answer}” [template] — web/src/games/words/VibeWords.tsx:916
- “Solved — but the room could not be told.” — web/src/games/words/VibeWords.tsx:920
- “{name} got there first, mind. The next one is a new word.” [template] — web/src/games/words/VibeWords.tsx:923
- “In {n} guess(es)” [template] — web/src/games/words/VibeWords.tsx:924
- “The next one is a new word.” — web/src/games/words/VibeWords.tsx:925
- “Play Again” (in-board button after the round) — web/src/games/words/VibeWords.tsx:985

### Number Vibe

`web/src/games/sudoku/VibeSudoku.tsx`, with difficulty words from
`web/src/games/sudoku/puzzle.ts`.

**How to play** (the web page's own wording)

- “Number Vibe” (page name) — web/src/games/sudoku/VibeSudoku.tsx:63
- “Fill the 9x9 grid so every row, every column and every 3x3 box holds 1 to 9. Play solo, or race friends on an identical board.” (intro) — web/src/games/sudoku/VibeSudoku.tsx:65
- “Difficulty means something” (section title) — web/src/games/sudoku/VibeSudoku.tsx:68
- “Easy, Medium and Hard are graded by the technique a puzzle actually needs, not by how many clues it has — so Hard is hard rather than merely sparse. If you host a race, guests play whatever difficulty you picked, so everybody gets the same board.” — web/src/games/sudoku/VibeSudoku.tsx:69
- “If you get stuck” (section title) — web/src/games/sudoku/VibeSudoku.tsx:72
- “**Notes** lets you pencil candidates into a square. Anything that clashes with a number in the same row, column or box is highlighted, so a mistake shows up before it spreads.” — web/src/games/sudoku/VibeSudoku.tsx:73
- “Solo — An endless supply of boards, at the difficulty you choose.” — web/src/games/sudoku/VibeSudoku.tsx:77
- “Race — Everyone gets the same board. First to fill it wins.” — web/src/games/sudoku/VibeSudoku.tsx:78
- “Nothing is stored — A puzzle is a pure function of its seed, so a shared game sends one number instead of a grid — and the solution is never written anywhere.” — web/src/games/sudoku/VibeSudoku.tsx:80

**Lobby**

- “Number Vibe” (header title) — web/src/games/sudoku/VibeSudoku.tsx:530
- “Proper Sudoku. Play Easy, Medium or Hard on your own — or race the room on the same board.” (lobby blurb) — web/src/games/sudoku/VibeSudoku.tsx:825
- “Easy” (title) — web/src/games/sudoku/puzzle.ts:54
- “Singles all the way down” (blurb) — web/src/games/sudoku/puzzle.ts:54
- “Medium” (title) — web/src/games/sudoku/puzzle.ts:55
- “Needs pairs and locked candidates” (blurb) — web/src/games/sudoku/puzzle.ts:55
- “Hard” (title) — web/src/games/sudoku/puzzle.ts:56
- “Sparse, and needs real technique” (blurb) — web/src/games/sudoku/puzzle.ts:56
- “Play on this device” — web/src/games/sudoku/VibeSudoku.tsx:851
- “A board to yourself, at the pace you like” — web/src/games/sudoku/VibeSudoku.tsx:852
- “Race your friends” — web/src/games/sudoku/VibeSudoku.tsx:856
- “The same board for everyone. First to finish takes it.” — web/src/games/sudoku/VibeSudoku.tsx:857

**The game screen**

- “{n} player(s) · {difficulty} · {n}/81 · {time} · code {code}” [template] (header subtitle) — web/src/games/sudoku/VibeSudoku.tsx:669
- “Sudoku board” [VoiceOver] (grid) — web/src/games/sudoku/VibeSudoku.tsx:703
- “Row {n} column {n}, {value}, given” [VoiceOver][template] (cell) — web/src/games/sudoku/VibeSudoku.tsx:733
- “Row {n} column {n}, empty” [VoiceOver][template] (cell) — web/src/games/sudoku/VibeSudoku.tsx:734
- “Enter {n}” [VoiceOver][template] (keypad digit) — web/src/games/sudoku/VibeSudoku.tsx:779
- “Notes” (keypad toggle) — web/src/games/sudoku/VibeSudoku.tsx:793
- “Erase” (keypad) — web/src/games/sudoku/VibeSudoku.tsx:802
- “🏆 {name} solved it first.” [template] (winner banner) — web/src/games/sudoku/VibeSudoku.tsx:572
- “Next board in” (countdown caption) — web/src/games/sudoku/VibeSudoku.tsx:626

**Waiting room**

- “Everyone else: Number Vibe → Join with a code” (code hint) — web/src/games/sudoku/VibeSudoku.tsx:878
- “Everyone races the same {difficulty} board. Start when they have joined.” [template] — web/src/games/sudoku/VibeSudoku.tsx:881
- “Waiting for {host} to start…” [template] — web/src/games/sudoku/VibeSudoku.tsx:882
- “Nobody yet” (empty player list) — web/src/games/sudoku/VibeSudoku.tsx:885
- “Start game” — web/src/games/sudoku/VibeSudoku.tsx:889
- “Copy the link” — web/src/games/sudoku/VibeSudoku.tsx:900

**Round over**

- “You finished it!” (title, shared game) — web/src/games/sudoku/VibeSudoku.tsx:600
- “Solved!” (title, solo) — web/src/games/sudoku/VibeSudoku.tsx:600
- “Solved — but the room could not be told.” — web/src/games/sudoku/VibeSudoku.tsx:603
- “{name} got there first, mind. The next board is a new one.” [template] — web/src/games/sudoku/VibeSudoku.tsx:605
- “{n} of 81 · {time}” [template] — web/src/games/sudoku/VibeSudoku.tsx:606
- “Difficulty for the next board” (choices group label) — web/src/games/sudoku/VibeSudoku.tsx:615

**Notices and saved-game summaries**

- “No game with that code” (join error) — web/src/games/sudoku/VibeSudoku.tsx:205
- “Could not create the game” — web/src/games/sudoku/VibeSudoku.tsx:340
- “Notes hold {n} numbers.” [template] — web/src/games/sudoku/VibeSudoku.tsx:405
- “Could not start the next round” — web/src/games/sudoku/VibeSudoku.tsx:498
- “{n} of 81 squares filled” [template] (solo-resume summary) — web/src/games/sudoku/VibeSudoku.tsx:152

**Name prompt**

- “What should we call you?” — web/src/games/sudoku/VibeSudoku.tsx:921
- “So everyone can see who finished first.” — web/src/games/sudoku/VibeSudoku.tsx:922
- “Your name” (field placeholder) — web/src/games/sudoku/VibeSudoku.tsx:926
- “Save” — web/src/games/sudoku/VibeSudoku.tsx:932
- “Not now” — web/src/games/sudoku/VibeSudoku.tsx:935

**Settings sheet**

- “Notes per square” (section title) — web/src/games/sudoku/VibeSudoku.tsx:647
- “Nine marks per square” — web/src/games/sudoku/VibeSudoku.tsx:651
- “Off draws four big ones. On draws every candidate, three by three.” — web/src/games/sudoku/VibeSudoku.tsx:652

### Vibe Pairings

`web/src/games/trio/VibeTrio.tsx`.

**How to play** (the web page's own wording)

- “Vibe Pairings” (page name) — web/src/games/trio/VibeTrio.tsx:927
- “Twelve charcuterie boards are dealt face up. Your job is to find three of them that make a good pairing.” (intro) — web/src/games/trio/VibeTrio.tsx:928
- “What's on a board” (section title) — web/src/games/trio/VibeTrio.tsx:931
- “Every board has four features, and each one comes three ways. **Platter**: round walnut, bamboo hexagon, slate rectangle. **Cheese**: swiss wedge, gouda cubes, brie round. **Meat**: prosciutto ribbon, salami stack, turkey roll-up. **Garnish**: purple grapes, red strawberry, pear slices.” — web/src/games/trio/VibeTrio.tsx:932
- “The rule” (section title) — web/src/games/trio/VibeTrio.tsx:935
- “Three cards make a good pairing when every one of those four features is **either the same on all three or different on all three**. Two matching and a third odd is not a good pairing — that is exactly the mistake the game is built to punish.” — web/src/games/trio/VibeTrio.tsx:936
- “Solo — Clear the whole deck at your own pace. Stuck? **Hint** picks out one card of a good pairing — the other two are still yours to find.” — web/src/games/trio/VibeTrio.tsx:940
- “Race — Everyone shares one table, so a good pairing taken by anybody is gone for everybody. The winner is whoever has taken the most when the deck runs out. The host decides whether the table has hints.” — web/src/games/trio/VibeTrio.tsx:941
- “Wrong three — They flash red and nothing moves. Look again — the cards stay put.” — web/src/games/trio/VibeTrio.tsx:942

**Lobby and shared game**

- “Vibe Pairings” (header title) — web/src/games/trio/VibeTrio.tsx:494
- “{n} player(s) · {n} good pairing(s) · {time} · code {code}” [template] (shared header subtitle) — web/src/games/trio/VibeTrio.tsx:607
- “{n} good pairing(s) · {time}” [template] (solo header subtitle) — web/src/games/trio/VibeTrio.tsx:614
- “Three cards. Every feature the same on all three, or different on all three.” (lobby blurb) — web/src/games/trio/VibeTrio.tsx:644
- “Play on this device” — web/src/games/trio/VibeTrio.tsx:652
- “Clear the whole deck at your own pace” — web/src/games/trio/VibeTrio.tsx:653
- “Race your friends” — web/src/games/trio/VibeTrio.tsx:657
- “One table of cards. Take a good pairing before anyone else does.” — web/src/games/trio/VibeTrio.tsx:658
- “Everyone else: Vibe Pairings → Join with a code” (code hint) — web/src/games/trio/VibeTrio.tsx:679
- “Start when everyone has joined. Clear the deck together — the first to spot a good pairing takes it.” — web/src/games/trio/VibeTrio.tsx:682
- “Waiting for {host} to start…” [template] — web/src/games/trio/VibeTrio.tsx:683
- “{n} player(s) here” [template] — web/src/games/trio/VibeTrio.tsx:686
- “Start game” — web/src/games/trio/VibeTrio.tsx:690
- “Copy the link” — web/src/games/trio/VibeTrio.tsx:702
- “Hint” (button) — web/src/games/trio/VibeTrio.tsx:854
- “Race — no hints” — web/src/games/trio/VibeTrio.tsx:857
- “{n} left in the deck” [template] — web/src/games/trio/VibeTrio.tsx:859
- “Next deal in” (countdown caption) — web/src/games/trio/VibeTrio.tsx:585
- “{platter}, {cheese}, {meat}, {garnish}” [VoiceOver][template] (a card) — web/src/games/trio/cards.ts:128

**Round over and standings**

- “Deck cleared” (solo result title) — web/src/games/trio/VibeTrio.tsx:888
- “Nobody scored” (shared result title) — web/src/games/trio/VibeTrio.tsx:890
- “You win!” — web/src/games/trio/VibeTrio.tsx:893
- “{name} wins” [template] — web/src/games/trio/VibeTrio.tsx:894
- “Tie at {n}” [template] — web/src/games/trio/VibeTrio.tsx:895
- “{time} · {n} player(s)” [template] (shared detail) — web/src/games/trio/VibeTrio.tsx:902
- “{n} good pairing(s) in {time}” [template] (solo detail) — web/src/games/trio/VibeTrio.tsx:903
- “{rank}” / “{name}” / “{score}” [template] (a standings row) — web/src/games/trio/VibeTrio.tsx:911
- “Player” (fallback for a player with no readable name) — web/src/games/trio/VibeTrio.tsx:877
- “You” (your own name in the solo standings) — web/src/games/trio/VibeTrio.tsx:880

**Notices and saved-game summaries**

- “No game with that code” (join error) — web/src/games/trio/VibeTrio.tsx:150
- “Could not create the game” (fallback notice) — web/src/games/trio/VibeTrio.tsx:343
- “Someone got there first!” — web/src/games/trio/VibeTrio.tsx:434
- “A new deal started — try that again.” — web/src/games/trio/VibeTrio.tsx:436
- “Could not reach the game. Check your connection.” — web/src/games/trio/VibeTrio.tsx:437
- “{n} trio(s) taken” [template] (solo-resume summary) — web/src/games/trio/VibeTrio.tsx:200

**Settings sheet**

- “Hints” (section title) — web/src/games/trio/VibeTrio.tsx:514
- “Everyone plays the same way: a race with hints is a different game, so this is for the whole room.” — web/src/games/trio/VibeTrio.tsx:517
- “Only the host can change this, and only before the start.” — web/src/games/trio/VibeTrio.tsx:518
- “Hints in this race” — web/src/games/trio/VibeTrio.tsx:525
- “On gives every player the Hint button” — web/src/games/trio/VibeTrio.tsx:526
- “On, for everybody” / “Off, for everybody” (read-only state) — web/src/games/trio/VibeTrio.tsx:536

**Name prompt**

- “What should we call you?” — web/src/games/trio/VibeTrio.tsx:967
- “So everyone knows who spotted it first.” — web/src/games/trio/VibeTrio.tsx:968
- “Your name” (field placeholder) — web/src/games/trio/VibeTrio.tsx:972
- “Save” — web/src/games/trio/VibeTrio.tsx:978
- “Not now” — web/src/games/trio/VibeTrio.tsx:981

### Similar Vibe

`web/src/games/blurt/VibeBlurt.tsx`, with rules from `web/src/games/blurt/engine.ts`
and pack names from `web/src/games/blurt/words.generated.ts`.

**How to play** (the web page's own wording; resolved: 2,273 words across 8 packs,
first to 7)

- “Similar Vibe” (page name) — web/src/games/blurt/VibeBlurt.tsx:83
- “Two teams, a phone each, and a word nobody wants to be holding. Describe it without saying it, and get rid of it before the clock stops.” (intro) — web/src/games/blurt/VibeBlurt.tsx:85
- “Use similar words” (section title) — web/src/games/blurt/VibeBlurt.tsx:88
- “One person is shown a word and describes it using similar words, without saying it. Their team-mates try to guess the word. Get it right and a new word is shown to somebody on the **other** team. Whoever is left holding the word starts the next round — so do not still have it when the time runs out, or the other team gets the point. The clock does not stop or reset: it belongs to the round, not to the word.” — web/src/games/blurt/VibeBlurt.tsx:89
- “Nobody can count the clock down” (section title) — web/src/games/blurt/VibeBlurt.tsx:92
- “A round lasts a random 50 to 70 seconds and there is no number on screen. The ticking stays steady and then hurries and grows louder as the end approaches.” — web/src/games/blurt/VibeBlurt.tsx:93
- “A giveaway” (section title) — web/src/games/blurt/VibeBlurt.tsx:96
- “The team **not** holding the word can see it, and has one big red BUZZ button. If the describer says the word, or any part of it, they press it — and take the point.” — web/src/games/blurt/VibeBlurt.tsx:97
- “4 people — Two on each side at least. The app splits the room into teams at random.” — web/src/games/blurt/VibeBlurt.tsx:102
- “Scoring — Nobody scores for guessing. The point goes to the team that was not holding the word when the clock stopped — unless one team gives away their word.” — web/src/games/blurt/VibeBlurt.tsx:106
- “First to 7 — Wins the game.” — web/src/games/blurt/VibeBlurt.tsx:109
- “Words — 2273 to describe across 8 packs, chosen before the game starts.” — web/src/games/blurt/VibeBlurt.tsx:111

**Lobby and before the start**

- “Similar Vibe” (header title) — web/src/games/blurt/VibeBlurt.tsx:732
- “First to 7” (header subtitle, in a room) — web/src/games/blurt/VibeBlurt.tsx:733
- “Describe it. Don't say it.” (header subtitle, no room) — web/src/games/blurt/VibeBlurt.tsx:733
- “Start a game” (lobby button) — web/src/games/blurt/VibeBlurt.tsx:477
- “Join with a code” (join label) — web/src/games/blurt/VibeBlurt.tsx:481
- “cars feed” (join placeholder) — web/src/games/blurt/VibeBlurt.tsx:487
- “Join” — web/src/games/blurt/VibeBlurt.tsx:493
- “Everyone else: Similar Vibe → Join with a code” (code hint) — web/src/games/blurt/VibeBlurt.tsx:515
- “In the room ({n})” [template] — web/src/games/blurt/VibeBlurt.tsx:519
- “you” (marker beside your own name) — web/src/games/blurt/VibeBlurt.tsx:526
- “Settings” (settings card title) — web/src/games/blurt/VibeBlurt.tsx:538
- “all 8 packs” / “{n} of 8 packs” [template] (settings card summary) — web/src/games/blurt/VibeBlurt.tsx:540
- “Start” (host button) — web/src/games/blurt/VibeBlurt.tsx:552
- “Teams are picked at random, so nobody can argue.” (host hint) — web/src/games/blurt/VibeBlurt.tsx:445
- “You need 4 people — two on each team. {n} more to go.” [template] — web/src/games/blurt/VibeBlurt.tsx:447
- “Waiting for {host} to start.” [template] — web/src/games/blurt/VibeBlurt.tsx:557

**A turn**

- “Team One” / “Team Two” — web/src/games/blurt/engine.ts:33
- “Your team” (badge on your own side) — web/src/games/blurt/VibeBlurt.tsx:586
- “{team} takes the point — caught a giveaway” [template] — web/src/games/blurt/VibeBlurt.tsx:594
- “Nobody takes the point — …” [template] (when no team was awarded it) — web/src/games/blurt/VibeBlurt.tsx:594
- “{team} takes the point — the clock ran out” [template] — web/src/games/blurt/VibeBlurt.tsx:598
- “Your word — don't say it” (describer caption) — web/src/games/blurt/VibeBlurt.tsx:625
- “Got it — pass it on” (describer button) — web/src/games/blurt/VibeBlurt.tsx:628
- “The word goes to the other team. The clock keeps running.” — web/src/games/blurt/VibeBlurt.tsx:630
- “Watch for it” (other team's caption) — web/src/games/blurt/VibeBlurt.tsx:637
- “Watch close — if {name} says the word above, buzz them!” [template] — web/src/games/blurt/VibeBlurt.tsx:646
- “Watch close — if they say the word above, buzz them!” — web/src/games/blurt/VibeBlurt.tsx:647
- “BUZZ” (the big red button) — web/src/games/blurt/VibeBlurt.tsx:650
- “Saying any part of it counts too.” — web/src/games/blurt/VibeBlurt.tsx:652
- “Guess it” (holding team's caption) — web/src/games/blurt/VibeBlurt.tsx:658
- “{name} is describing a word to you” [template] — web/src/games/blurt/VibeBlurt.tsx:661
- “Shout it out!” — web/src/games/blurt/VibeBlurt.tsx:665
- “Get it right and the word passes to the other team — the clock keeps running.” — web/src/games/blurt/VibeBlurt.tsx:668

**Between turns and finished**

- “You're up” — web/src/games/blurt/VibeBlurt.tsx:682
- “{name} is up” [template] — web/src/games/blurt/VibeBlurt.tsx:682
- “Nobody is left to describe” — web/src/games/blurt/VibeBlurt.tsx:682
- “You're on {team} — guessing” / “watching” [template] — web/src/games/blurt/VibeBlurt.tsx:688
- “Hold the phone so only you can see it, then start the clock.” — web/src/games/blurt/VibeBlurt.tsx:693
- “They have left the room, and nothing is running yet. Anyone on their team can take the round.” — web/src/games/blurt/VibeBlurt.tsx:695
- “Pass the phone to {name}. Everyone else, watch for the word.” [template] — web/src/games/blurt/VibeBlurt.tsx:697
- “Nobody on that side is in the room, so there is no round to take.” — web/src/games/blurt/VibeBlurt.tsx:698
- “Start the clock” — web/src/games/blurt/VibeBlurt.tsx:706
- “{team} wins” [template] (round-over title) — web/src/games/blurt/VibeBlurt.tsx:618
- “{one} – {two}” [template] (round-over detail) — web/src/games/blurt/VibeBlurt.tsx:619

**Join errors and name prompt**

- “Could not start a game. Check your connection.” — web/src/games/blurt/VibeBlurt.tsx:372
- “That code did not work. Check it and try again.” — web/src/games/blurt/VibeBlurt.tsx:385
- “No game with that code” — web/src/games/blurt/service.ts:268
- “What should we call you?” — web/src/games/blurt/VibeBlurt.tsx:757
- “So your team knows who is describing.” — web/src/games/blurt/VibeBlurt.tsx:758
- “Your name” (field placeholder) — web/src/games/blurt/VibeBlurt.tsx:762
- “Save” — web/src/games/blurt/VibeBlurt.tsx:768
- “Not now” — web/src/games/blurt/VibeBlurt.tsx:771

**Settings sheet**

- “Turn length” (section title, no control) — web/src/games/blurt/VibeBlurt.tsx:170
- “Somewhere between 50 and 70 seconds, and not the same twice. Nobody can count it down — the bar changes colour and starts pulsing when it is nearly over.” — web/src/games/blurt/VibeBlurt.tsx:171
- “Words” (section title) — web/src/games/blurt/VibeBlurt.tsx:173
- “{n} words in the deck” [template] — web/src/games/blurt/VibeBlurt.tsx:187
- “Everyone in the room gets these, so you will all be describing the same things.” — web/src/games/blurt/VibeBlurt.tsx:190
- “Only the host can change these, and only before the game starts.” — web/src/games/blurt/VibeBlurt.tsx:191
- “Food & Drink” (title) — web/src/games/blurt/words.generated.ts:30
- “Meals, snacks and drinks” (blurb) — web/src/games/blurt/words.generated.ts:32
- “Animals & Nature” (title) — web/src/games/blurt/words.generated.ts:36
- “Creatures great and small” (blurb) — web/src/games/blurt/words.generated.ts:38
- “Places & Travel” (title) — web/src/games/blurt/words.generated.ts:42
- “Spots near and far” (blurb) — web/src/games/blurt/words.generated.ts:44
- “Household Objects” (title) — web/src/games/blurt/words.generated.ts:48
- “Things around the home” (blurb) — web/src/games/blurt/words.generated.ts:50
- “Jobs & People” (title) — web/src/games/blurt/words.generated.ts:54
- “Jobs and the people who do them” (blurb) — web/src/games/blurt/words.generated.ts:56
- “Sport & Music” (title) — web/src/games/blurt/words.generated.ts:60
- “Sports, games and music” (blurb) — web/src/games/blurt/words.generated.ts:62
- “Actions & Situations” (title) — web/src/games/blurt/words.generated.ts:66
- “Things people do” (blurb) — web/src/games/blurt/words.generated.ts:68
- “Celebrations & Weather” (title) — web/src/games/blurt/words.generated.ts:72
- “Festivals, celebrations and weather” (blurb) — web/src/games/blurt/words.generated.ts:74

### Vibe Ten

`web/src/games/ten/VibeTen.tsx`, with mode words from `web/src/games/ten/engine.ts`.

**How to play** (the web page's own wording)

- “Vibe Ten” (page name) — web/src/games/ten/VibeTen.tsx:64
- “Take pairs of numbers off the board until all the numbers have been removed.” (intro) — web/src/games/ten/VibeTen.tsx:65
- “What pairs” (section title) — web/src/games/ten/VibeTen.tsx:68
- “Two numbers match if they are **the same**, or if they **add up to ten** — 1 with 9, 2 with 8, 3 with 7, 4 with 6, 5 with 5. They have to be on the same row, column or diagonal, with nothing in between: neighbours count, and so does a line with only gaps in it.” — web/src/games/ten/VibeTen.tsx:69
- “Rows that join up” (section title) — web/src/games/ten/VibeTen.tsx:72
- “You can enable a setting that lets the rows connect end to end: the last square of a row is next to the first square of the row below it, so a 5 at the end of one row matches a 5 at the start of the next — and, if the squares between them have already been taken, the one after that can match.” — web/src/games/ten/VibeTen.tsx:73
- “The board” (section title) — web/src/games/ten/VibeTen.tsx:76
- “The board is **nine columns** wide and starts with **twelve to eighteen rows** of numbers. The strategy of the game is deciding which pair to take first, because every pair you remove changes what is available.” — web/src/games/ten/VibeTen.tsx:77
- “Dim mode” (section title) — web/src/games/ten/VibeTen.tsx:80
- “In standard play, when you make a pair, the pair is removed immediately from the board and all the pieces below the pair rise up. In the game settings, there is a **Dim** option that leaves a taken pair on the board, greyed out, instead of removing it. A dimmed number is gone as far as the rules are concerned: it cannot be picked again, and a pair can be made straight across it. When every number in a row has been dimmed, the whole row clears at once and everything below it rises one row.” — web/src/games/ten/VibeTen.tsx:81
- “New rows” (section title) — web/src/games/ten/VibeTen.tsx:84
- “You can reveal more rows of numbers at the bottom of the board by pressing the **Add rows** button. During game setup, you can choose whether the button reveals two or four rows. The new rows bring a partner for the numbers that have no pair to take, and pair up the rest.” — web/src/games/ten/VibeTen.tsx:85
- “Winning” (section title) — web/src/games/ten/VibeTen.tsx:88
- “Continue removing pairs until you have removed them all. If you are able to remove all the numbers, you win. If you cannot remove all the numbers and you can no longer add rows, you lose. You can retry the board and see if you can remove the pairs differently and win.” — web/src/games/ten/VibeTen.tsx:89
- “Playing as a room” (section title) — web/src/games/ten/VibeTen.tsx:92
- “Everyone gets the identical board, dealt from a seed and played by the host's chosen options — the starting rows, how many rows a press adds, whether the rows join end to end, and how a taken pair leaves the board. You each take pairs at your own pace on your own device. The first person to clear the board wins.” — web/src/games/ten/VibeTen.tsx:93
- “Solo — A fresh board whenever you want one. Play at your own pace.” — web/src/games/ten/VibeTen.tsx:97
- “Room — The same board for everyone. First to clear it wins.” — web/src/games/ten/VibeTen.tsx:98

**Lobby, waiting room and game screen**

- “Vibe Ten” (header title) — web/src/games/ten/VibeTen.tsx:601
- “{n} player(s) · {n} pair(s)” [template] (shared header subtitle) — web/src/games/ten/VibeTen.tsx:594
- “Solo · {n} pair(s) · {n} left to take” [template] (solo header subtitle) — web/src/games/ten/VibeTen.tsx:595
- “Pair the digits, drop the ones above, clear the board.” (lobby blurb) — web/src/games/ten/VibeTen.tsx:616
- “Play on this device” — web/src/games/ten/VibeTen.tsx:624
- “A board of your own, no connection needed” — web/src/games/ten/VibeTen.tsx:625
- “Play with others” — web/src/games/ten/VibeTen.tsx:629
- “The same board for everyone. First to clear it wins.” — web/src/games/ten/VibeTen.tsx:630
- “Everyone else: Vibe Ten → Join with a code” (code hint) — web/src/games/ten/VibeTen.tsx:939
- “Start when everyone has joined. Everyone plays the same board.” — web/src/games/ten/VibeTen.tsx:943
- “Waiting for {host} to start…” [template] — web/src/games/ten/VibeTen.tsx:944
- “Start” — web/src/games/ten/VibeTen.tsx:951
- “Copy the link” — web/src/games/ten/VibeTen.tsx:964
- “Vibe Ten board” [VoiceOver] (grid) — web/src/games/ten/VibeTen.tsx:868
- “Column {n} row {n}: {value}” [VoiceOver][template] — web/src/games/ten/VibeTen.tsx:876
- “Column {n} row {n}: {value}, taken” [VoiceOver][template] — web/src/games/ten/VibeTen.tsx:885
- “Add {n} rows at the bottom” [VoiceOver][template] — web/src/games/ten/VibeTen.tsx:917
- “Add {n} rows” [template] (button text) — web/src/games/ten/VibeTen.tsx:920

**Round over**

- “Cleared it!” — web/src/games/ten/VibeTen.tsx:811
- “{name} cleared it first” [template] — web/src/games/ten/VibeTen.tsx:811
- “No one cleared it” — web/src/games/ten/VibeTen.tsx:814
- “No moves left” — web/src/games/ten/VibeTen.tsx:815
- “You cleared the board first. {n} pairs taken.” [template] — web/src/games/ten/VibeTen.tsx:831
- “{name} cleared the board first. {n} pairs taken.” [template] — web/src/games/ten/VibeTen.tsx:832
- “{n} pairs taken, and nobody cleared the board.” [template] — web/src/games/ten/VibeTen.tsx:834
- “{n} pairs taken. The room is still playing.” [template] — web/src/games/ten/VibeTen.tsx:835
- “Every digit gone. {n} pairs taken.” [template] — web/src/games/ten/VibeTen.tsx:838
- “{n} pairs taken, with no pairs left and no room for a new row.” [template] — web/src/games/ten/VibeTen.tsx:839
- “Retry this board” / “Play again” — web/src/games/ten/VibeTen.tsx:671
- “New board” — web/src/games/ten/VibeTen.tsx:673
- “cleared” (standings badge) — web/src/games/ten/VibeTen.tsx:683

**Notices and saved-game summaries**

- “No game with that code” (join error) — web/src/games/ten/VibeTen.tsx:257
- “Could not start a game. Check your connection.” — web/src/games/ten/VibeTen.tsx:410
- “Could not tell the room that one.” — web/src/games/ten/VibeTen.tsx:488
- “Could not deal another board.” — web/src/games/ten/VibeTen.tsx:578
- “{n} pair(s) taken · {n} digits left” [template] (solo-resume summary) — web/src/games/ten/VibeTen.tsx:237

**Settings sheet**

- “The board” (section title) — web/src/games/ten/VibeTen.tsx:710
- “The board is set for this game. Start a new game to change the starting rows.” — web/src/games/ten/VibeTen.tsx:713
- “Choose how many rows to start with; the grid holds only eighteen rows at a time.” — web/src/games/ten/VibeTen.tsx:714
- “Start with” (label) — web/src/games/ten/VibeTen.tsx:717
- “Fewer starting rows means more room to grow. In a group game everybody starts with the same number of rows.” — web/src/games/ten/VibeTen.tsx:736
- “Rows to add” (label) — web/src/games/ten/VibeTen.tsx:739
- “Add two or four rows at a time. In a group game the host sets how many rows are revealed at a time.” — web/src/games/ten/VibeTen.tsx:756
- “When a pair is matched” (section title) — web/src/games/ten/VibeTen.tsx:762
- “In a room the host's rules are the game's rules. This room is playing the way it was created.” — web/src/games/ten/VibeTen.tsx:766
- “This game is using the setting it started with. Leave it to choose again.” — web/src/games/ten/VibeTen.tsx:767
- “Choose it before you start. Pairs taken in Dim mode stay on the board.” — web/src/games/ten/VibeTen.tsx:768
- “Remove” (mode title) — web/src/games/ten/engine.ts:48
- “A matched pair disappears and the digits above fall into the gap.” (mode blurb) — web/src/games/ten/engine.ts:49
- “Dim” (mode title) — web/src/games/ten/engine.ts:52
- “A matched pair dims and stays put. Dimmed digits are treated as empty, so a pair can be made across them. When every digit in a row is dimmed the row clears and everything below it rises one row.” (mode blurb) — web/src/games/ten/engine.ts:54
- “Rows join end to end” — web/src/games/ten/VibeTen.tsx:788
- “The last square of a row is next to the first of the row below” — web/src/games/ten/VibeTen.tsx:789

**Name prompt**

- “What should we call you?” — web/src/games/ten/VibeTen.tsx:983
- “So the others in the room know whose score is whose.” — web/src/games/ten/VibeTen.tsx:984
- “Your name” (field placeholder) — web/src/games/ten/VibeTen.tsx:988
- “Save” — web/src/games/ten/VibeTen.tsx:994
- “Not now” — web/src/games/ten/VibeTen.tsx:997

---

## 4. Marketing site and store listing

Not duplicated here — these pages are long-form and already edited as prose. Each
entry is the page, the URL the App Store (and the hub footer) points at, and the
file that holds the text.

| Page | URL | File |
| --- | --- | --- |
| Landing page | `https://vibegames.party/` | `site/index.html` |
| About | `https://vibegames.party/about` | `site/about.html` |
| Privacy policy | `https://vibegames.party/privacy` | `site/privacy.html` |
| Support | `https://vibegames.party/support` | `site/support.html` |
| Ways to help | `https://vibegames.party/ways-to-help` | `site/ways-to-help.html` |

These are the pages the App Store listing links to: the **marketing URL** is the
landing page, the **support URL** is `site/support.html`, and the **privacy policy
URL** is `site/privacy.html`. The latter two also appear inside the app and in the web client's
footer, so their wording is reachable from every screen.

The store listing itself is in `APP_STORE.md`:

- **Name** (`Vibe Games`), **subtitle** (`Party games in your pocket`) and
  **promotional text** — `APP_STORE.md`, “The listing copy”.
- **Keywords** — the comma-separated list in the same section.
- **Description** — the long six-game pitch, headed “Party games for the whole
  table, in your pocket.”, in the same section.
- **What's new** — the 1.0 release notes, in the same section.
- **App Privacy** and **Age rating** answers — the two sections after it.
- **App Review Information** — the suggested reviewer notes, including the
  explanation that Similar Vibe cannot be reviewed on one device.

## 5. Exclusions

These are game content, not interface copy, so they are deliberately not listed.
They live here if the wording in them needs a separate review.

- **Vibe Five category prompts** — 995 prompts across 11 packs, in
  `Sources/Features/VibeFive/Packs/*.swift`, mirrored for the browser in
  `web/src/games/five/prompts.generated.ts`. The pack names and blurbs *are*
  interface copy and are listed in sections 2 and 3.
- **Similar Vibe word packs** — 2,273 words across 8 packs, in
  `Sources/Features/VibeBlurt/Packs/*.swift` and
  `web/src/games/blurt/words.generated.ts`.
- **Word Vibe dictionaries** — 14,855 acceptable guesses and 489 possible answers,
  in `Sources/Features/VibeWords/WordLists.swift` and
  `web/src/games/words/wordList.ts`.
- **Number Vibe puzzles** — generated from a seed rather than stored; see
  `Sources/Features/VibeSudoku/SudokuGenerator.swift` and
  `web/src/games/sudoku/generator.ts`. There is no puzzle text to review.
- **Vibe Pairings deck** — the 81 cards are combinations of four features, and the
  artwork file names and spoken card descriptions are generated from those
  feature names (`Sources/Features/VibeTrio/TrioCard.swift`,
  `web/src/games/trio/cards.ts`, artwork in `cards/`).
- **First Player question bank** — 38 questions in
  `Sources/Features/Utilities/FirstPlayer.swift:57`. The card's headings, seat
  instructions and VoiceOver labels are listed in section 2.
- **Dice-table artwork** — the felt in the 3D dice table carries the words “VIBE
  GAMES” and “vibegames.party” as texture, not as interface copy
  (`Sources/Features/Utilities/DiceTable.swift`).

Also excluded throughout, by design: accessibility **identifiers**, analytics
event names and keys, SF Symbol names, URLs and API keys, CSS class names, and
code identifiers. Accessibility **labels** and hints are included and marked
`[VoiceOver]`.

