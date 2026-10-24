import SwiftUI

/// A game's "how to play" page, as words.
///
/// The five games showed their instructions in five different ways — a page
/// behind a card in Vibe Pairings, a wall of prose in the lobby in Similar Vibe, a
/// single line under the buttons in Word Vibe. They are all one page behind one
/// card now, and this is the only place that decides what that page looks like.
struct GameInstructions {

    struct Section: Identifiable {
        let title: String
        let body: String
        var id: String { title }
    }

    struct Bullet: Identifiable {
        let lead: String
        let text: String
        var id: String { lead }
    }

    let game: AppAnalytics.Game
    /// Shown under the "HOW TO PLAY" heading, e.g. "Vibe Pairings".
    let name: String
    /// Names both the page and its opener, e.g. `trio.instructions` and
    /// `trio.instructions.open`.
    let identifier: String
    let intro: String
    var sections: [Section] = []
    var bullets: [Bullet] = []

    // MARK: - The pages

    static let five = GameInstructions(
        game: .five,
        name: "Vibe Five",
        identifier: "five.instructions",
        intro: "It's easy right? Just name 3 things that fit in the category...in only 5 seconds. ",
        sections: [
            Section(title: "Game host",
                    body: "We find the games works best if one player is the game host. "
                        + "It's also helpful if you can cast the screen onto a larger TV "
                        + "that everyone can see, but it's not required. The host will "
                        + "press **START** to see the first clue. The first job of the host is to "
                        + "read the clue, very clearly, so the players can understand it. "
                        + "Once the host has finished reading the clue they press the **START** "
                        + "button again. "),
            Section(title: "How a round ends",
                    body: "Either the clock runs out — the buzzer sounds and the screen flashes "
                        + "red — or the host presses **Done!** to end it early. Done! is "
                        + "deliberately silent, because the buzzer means the clock beat you. "
                        + "Either way the dial freezes on the time that was left, so the table "
                        + "can see how much time they had to spare."),
            Section(title: "Alternative Play",
                    body: "If you don't want to have a single person as a host, you can "
                        + "also pass the device from person to person. You can also play "
                        + "solo this way if you want to practice."),
        ],
        bullets: [
            Bullet(lead: "START", text: "Shows a category."),
            Bullet(lead: "Buzzer", text: "You didn't get it fast enough."),
            Bullet(lead: "Done!", text: "You got it! Congratulations."),
            Bullet(lead: "NEXT", text: "Show a new category."),
            Bullet(lead: "Packs", text: "\(CategoryLibrary.all.count) categories across "
                        + "\(CategoryPack.allCases.count) packs, switched on and off in Game Setup. "
                        + "Only the packs you leave on go into the deck, and no category comes "
                        + "round twice until the pool runs out."),
        ])

    static let words = GameInstructions(
        game: .words,
        name: "Word Vibe",
        identifier: "words.instructions",
        intro: "Guess the five-letter word in six tries. Play solo on this device, or start "
             + "a game and race everyone on the same word.",
        sections: [
            Section(title: "Reading the colours",
                    body: "**Green** is the right letter in the right place. **Amber** means the "
                        + "letter is in the word but somewhere else. **Grey** means it is not in "
                        + "the word at all."),
            Section(title: "Repeated letters",
                    body: "Exact matches are claimed first, and what is left "
                        + "of the answer then has to cover the rest: guessing "
                        + "EERIE against SPEED credits two Es and marks the "
                        + "third one absent."),
        ],
        bullets: [
            Bullet(lead: "Solo", text: "A fresh word, with no connection needed."),
            Bullet(lead: "With friends", text: "Everyone guesses the same word on their own device. "
                        + "The first to solve it is announced to the whole room."),
        ])

    static let sudoku = GameInstructions(
        game: .sudoku,
        name: "Number Vibe",
        identifier: "sudoku.instructions",
        intro: "Fill the 9x9 grid so every row, every column and every 3x3 box holds "
             + "1 to 9. Play solo, or race friends on an identical board.",
        sections: [
            Section(title: "Difficulty",
                    body: "Easy, Medium and Hard are graded by the technique a puzzle "
                        + "needs to solve it. If you host a race, you choose the difficulty "
                        + "and everybody gets the same board."),
            Section(title: "Notes",
                    body: "**Notes** lets you pencil candidates into a square. Anything that "
                        + "clashes with a number in the same row, column or box is highlighted, "
                        + "so a mistake shows up before it spreads."),
        ],
        bullets: [
            Bullet(lead: "Solo", text: "An endless supply of boards, at the difficulty you choose."),
            Bullet(lead: "Race", text: "Everyone gets the same board. First to fill it wins."),
        ])

    static let ten = GameInstructions(
        game: .ten,
        name: "Vibe Ten",
        identifier: "ten.instructions",
        intro: "Take pairs of digits off the board until nothing pairs any more. "
             + "Clear every digit and you have cleared the board.",
        sections: [
            Section(title: "What pairs",
                    body: "Two digits pair if they are **equal**, or if they **add up to ten** — "
                        + "1 with 9, 2 with 8, 3 with 7, 4 with 6, 5 with 5. "
                        + "They have to be on the same row, column or diagonal, with nothing "
                        + "in between: neighbours count, and so does a line with only gaps "
                        + "in it."),
            Section(title: "The board falls",
                    body: "Taking a pair leaves a hole, and the digits above it drop into it. "
                        + "Half the game is deciding which pair to take first, because every "
                        + "take changes what is next to what."),
            Section(title: "The board's size",
                    body: "In the game settings the grid can be **six to nine columns** and "
                        + "**twelve to eighteen rows** — the full board unless you choose "
                        + "otherwise. Fewer squares means bigger digits, and the grid always "
                        + "fills the screen. Choose it on the start screen: once a game is "
                        + "under way the board keeps its shape. A room plays the shape the "
                        + "host dealt, so everybody's board matches."),
            Section(title: "Dim mode",
                    body: "In the game settings, **Dim** leaves a taken pair on the board, "
                        + "greyed out, instead of removing it. A dimmed digit is gone as far as "
                        + "the rules are concerned: it cannot be picked again, and a pair can be "
                        + "made straight across it. When every digit in a row has been dimmed, "
                        + "the whole row clears at once and everything above drops one row."),
            Section(title: "A new row, solo",
                    body: "Playing alone, you can push a fresh row of digits in at the bottom. "
                        + "It is only possible while the top row of the grid is empty — and "
                        + "rather than taking up space of its own, the button appears in that "
                        + "empty row. A room plays the board it was dealt, so the button is "
                        + "never there in a shared game."),
            Section(title: "Playing as a room",
                    body: "Everyone gets the identical board, dealt from a seed. You each take "
                        + "pairs at your own pace on your own device. One point per pair, and "
                        + "when everybody has run out of moves, the most pairs wins. A tie goes "
                        + "to whoever ran out of moves first."),
        ],
        bullets: [
            Bullet(lead: "Solo", text: "A fresh board whenever you want one, any shape you "
                        + "like, and a new row whenever the top of the grid is free."),
            Bullet(lead: "Room", text: "The same board for everyone. Most pairs wins."),
        ])

    static let blurt = GameInstructions(
        game: .blurt,
        name: "Similar Vibe",
        identifier: "blurt.instructions",
        intro: "Describe a word without saying it, so your team can guess it before the clock stops.",
        sections: [
            Section(title: "Use similar words",
                    body: "One person is shown a word and describes it using similar words, without "
                        + "saying it. Their teammates try to guess the word. "
                        + "If they get it right a new word is shown to somebody on the **other** team. "
                        + "A round lasts about a minute. Make sure you don't have the word when "
                        + "the time runs out or the other team gets a point — whoever is left "
                        + "holding it starts the next round."),
            Section(title: "A giveaway",
                    body: "The team **not** holding the word can see it, and has one big red "
                        + "BUZZ button. If the describer says the word, or any part of it, they "
                        + "press it — and take the point."),
        ],
        bullets: [
            Bullet(lead: "Four people", text: "Two on each side at least. The app splits the room "
                        + "into teams at random."),
            Bullet(lead: "Scoring", text: "Nobody scores for guessing. The point goes to the team "
                        + "that was not holding the word when the clock stops — unless one team "
                        + "gives away their word."),
            Bullet(lead: "Winning", text: "First team to \(BlurtRules.target) points wins the game."),
        ])

    /// Every game that has a prose page, in the order the hub lists them. Vibe
    /// Pairings has one of its own — `TrioInstructionsView`, drawn from real
    /// cards rather than written out — so it is not in this list.
    static let all: [GameInstructions] = [.five, .words, .sudoku, .ten, .blurt]
}

// MARK: - The page

/// The shell every "how to play" page shares.
///
/// One back button, one title block, one spacing scale, so the pages cannot drift
/// apart as games are added. A game supplies its words; the shape of the page is
/// not its business — which is why Vibe Pairings, whose page is all diagrams, uses
/// the same shell as the four that are text.
struct GameInstructionsScaffold<Content: View>: View {
    let game: AppAnalytics.Game
    let name: String
    let identifier: String
    let intro: String
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                Text(.init(intro))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                content()
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier(identifier)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(VibeIconButtonStyle())
            .accessibilityLabel("Back")
            .accessibilityIdentifier("\(identifier).back")

            VStack(spacing: 3) {
                Text("HOW TO PLAY")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .kerning(3.5)
                    .foregroundStyle(VibeTheme.primaryText)
                Text(name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity)

            SupportButton(game: game)
        }
        .padding(.top, 10)
    }
}

/// A page for the games whose instructions are words rather than diagrams.
struct GameInstructionsPage: View {
    let instructions: GameInstructions

    var body: some View {
        GameInstructionsScaffold(game: instructions.game,
                                 name: instructions.name,
                                 identifier: instructions.identifier,
                                 intro: instructions.intro) {
            ForEach(instructions.sections) { section in
                InstructionsSection(title: section.title, text: section.body)
            }
            InstructionsBullets(title: "Playing", bullets: instructions.bullets)
        }
    }
}

// MARK: - The card that opens it

/// The "How to play" card, identical on every lobby.
///
/// It sits last among the options rather than as a block of text above them: the
/// rules are worth reading once, and everybody who knows them would otherwise
/// scroll past them every time. The accent is the game's own colour, so it still
/// belongs on the page it is on.
struct InstructionsCard<Accent: ShapeStyle>: View {
    let accent: Accent
    let identifier: String
    let destination: AnyView

    init<Destination: View>(accent: Accent,
                            identifier: String,
                            @ViewBuilder destination: () -> Destination) {
        self.accent = accent
        self.identifier = identifier
        self.destination = AnyView(destination())
    }

    var body: some View {
        NavigationLink { destination } label: {
            HStack(spacing: 16) {
                Image(systemName: "book.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accent)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("How to play")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    Text("The rules, and what the buttons do")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VibeTheme.tertiaryText)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(VibeTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// The same opener for a screen that has no room for a card.
///
/// Vibe Five is the one game with no lobby: its main page is the round itself,
/// with the category filling the screen and a full-width button under it. A card
/// there would push the game around, so the opener is a quiet line of text — the
/// same words, the same destination, and the page behind it is identical.
struct InstructionsLink: View {
    let identifier: String
    let destination: AnyView

    init<Destination: View>(identifier: String, @ViewBuilder destination: () -> Destination) {
        self.identifier = identifier
        self.destination = AnyView(destination())
    }

    var body: some View {
        NavigationLink { destination } label: {
            HStack(spacing: 7) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("How to play")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(VibeTheme.secondaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Shared pieces
/// A titled block of prose, used by every page.
struct InstructionsSection: View {
    let title: String
    /// Not called `body`: a `View` already has one of those, and the clash is a
    /// compile error rather than a shadowing warning.
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .kerning(1.5)
                .foregroundStyle(VibeTheme.tertiaryText)

            Text(.init(text))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
    }
}

/// The "what you actually do" list, the same on every page.
struct InstructionsBullets: View {
    let title: String
    let bullets: [GameInstructions.Bullet]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .kerning(1.5)
                .foregroundStyle(VibeTheme.tertiaryText)

            ForEach(bullets) { bullet in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(VibeTheme.tertiaryText)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    (Text(bullet.lead).bold() + Text(" — ") + Text(.init(bullet.text)))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
    }
}

extension View {
    /// The card every instructions block is drawn on.
    func cardSurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
    }
}
