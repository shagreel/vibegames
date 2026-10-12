import SwiftUI

/// A game's "how to play" page, as words.
///
/// The five games showed their instructions in five different ways — a page
/// behind a card in Vibe Trio, a wall of prose in the lobby in Vibe Blurt, a
/// single line under the buttons in Vibe Words. They are all one page behind one
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
    /// Shown under the "HOW TO PLAY" heading, e.g. "Vibe Trio".
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
        intro: "A category, five seconds, and one phone passed round the table. "
             + "Name three things that fit before the buzzer.",
        sections: [
            Section(title: "The category waits for you",
                    body: "Press **START** and the category fills the screen with a "
                        + "GET READY badge. No timer is running and none is shown, so read it "
                        + "out, explain it, and argue about it for as long as you like."),
            Section(title: "Then the clock",
                    body: "Press **START** again when the table is ready. The dial appears and "
                        + "drains from five to zero, with a tick for each of the last three "
                        + "seconds. The dial appearing *is* the signal that time is running."),
            Section(title: "How a round ends",
                    body: "Either the clock runs out — the buzzer sounds and the screen flashes "
                        + "red — or the player presses **Done!** to end it early. Done! is "
                        + "deliberately silent, because the buzzer means the clock beat you. "
                        + "Either way the dial freezes on the time that was left, so the table "
                        + "can see what they had to spare."),
        ],
        bullets: [
            Bullet(lead: "START", text: "Deals a category. Nothing is running yet."),
            Bullet(lead: "Done!", text: "Ends the round early. Silent, so the buzzer keeps its meaning."),
            Bullet(lead: "NEXT", text: "Deals a fresh category and waits for you to start the clock again."),
            Bullet(lead: "Packs", text: "\(CategoryLibrary.all.count) categories across "
                        + "\(CategoryPack.allCases.count) packs, switched on and off in Game Setup. "
                        + "Only the packs you leave on go into the deck, and no category comes "
                        + "round twice until the pool runs out."),
        ])

    static let words = GameInstructions(
        game: .words,
        name: "Vibe Words",
        identifier: "words.instructions",
        intro: "Guess the five-letter word in six tries. Play solo on this phone, or start "
             + "a game and race everyone on the same word.",
        sections: [
            Section(title: "Reading the colours",
                    body: "**Green** is the right letter in the right place. **Amber** means the "
                        + "letter is in the word but somewhere else. **Grey** means it is not in "
                        + "the word at all."),
            Section(title: "Repeated letters",
                    body: "Counted properly rather than one letter at a time. Exact matches are "
                        + "claimed first, and what is left of the answer then has to cover the "
                        + "rest: guessing EERIE against SPEED credits two Es and marks the "
                        + "third one absent."),
        ],
        bullets: [
            Bullet(lead: "Solo", text: "A fresh word, with no connection needed."),
            Bullet(lead: "With friends", text: "You get a code to share — two short words, like "
                        + "cars-feed — and everyone guesses the same word on their own phone. "
                        + "The first to solve it is announced to the whole room."),
            Bullet(lead: "The words", text: "\(WordLists.valid.count) can be guessed, and "
                        + "\(WordLists.answers.count) of them can be the answer."),
        ])

    static let sudoku = GameInstructions(
        game: .sudoku,
        name: "Vibe Sudoku",
        identifier: "sudoku.instructions",
        intro: "Fill the 9x9 grid so every row, every column and every 3x3 box holds "
             + "1 to 9. Play solo, or race friends on an identical board.",
        sections: [
            Section(title: "Difficulty means something",
                    body: "Easy, Medium and Hard are graded by the technique a puzzle actually "
                        + "needs, not by how many clues it has — so Hard is hard rather than "
                        + "merely sparse. If you host a race, guests play whatever difficulty "
                        + "you picked, so everybody gets the same board."),
            Section(title: "If you get stuck",
                    body: "**Notes** lets you pencil candidates into a square. Anything that "
                        + "clashes with a number in the same row, column or box is highlighted, "
                        + "so a mistake shows up before it spreads."),
        ],
        bullets: [
            Bullet(lead: "Solo", text: "An endless supply of boards, at the difficulty you choose."),
            Bullet(lead: "Race", text: "Everyone gets the same board. First to fill it wins."),
            Bullet(lead: "Nothing is stored", text: "A puzzle is a pure function of its seed, so "
                        + "a shared game sends one number instead of a grid — and the solution "
                        + "is never written anywhere."),
        ])

    static let blurt = GameInstructions(
        game: .blurt,
        name: "Vibe Blurt",
        identifier: "blurt.instructions",
        intro: "Two teams, a phone each, and a word nobody wants to be holding. "
             + "Describe it without saying it, and get rid of it before the clock stops.",
        sections: [
            Section(title: "The word is a hot potato",
                    body: "One person is shown a word and describes it; their team-mates guess. "
                        + "Get it right and the word passes to somebody on the **other** team. "
                        + "The clock does not stop or reset — it belongs to the round, not to "
                        + "the word."),
            Section(title: "Nobody can count the clock down",
                    body: "A round lasts a random 50 to 70 seconds and there is no number on "
                        + "screen. The ticking stays steady and then hurries and grows louder as "
                        + "the end approaches; in a browser, which has no sound here, the bar "
                        + "changes colour and pulses instead."),
            Section(title: "The other team is watching",
                    body: "The team **not** holding the word can see it, and has one big red "
                        + "BUZZ button. If the describer says the word, or any part of it, they "
                        + "press it — and they take the point instead."),
        ],
        bullets: [
            Bullet(lead: "Four people", text: "Two on each side at least. The app splits the room "
                        + "into teams at random."),
            Bullet(lead: "Scoring", text: "Nobody scores for guessing. The point goes to the team "
                        + "that was not holding the word when the clock stopped — or to the team "
                        + "that caught a blurt."),
            Bullet(lead: "First to \(BlurtRules.target)", text: "Wins the game."),
            Bullet(lead: "Words", text: "\(BlurtWords.all.count) to describe across "
                        + "\(BlurtPack.allCases.count) packs, chosen before the game starts."),
        ])

    /// Every game that has a page, in the order the hub lists them.
    static let all: [GameInstructions] = [.five, .words, .sudoku, .blurt]
}

// MARK: - The page

/// The shell every "how to play" page shares.
///
/// One back button, one title block, one spacing scale, so the pages cannot drift
/// apart as games are added. A game supplies its words; the shape of the page is
/// not its business — which is why Vibe Trio, whose page is all diagrams, uses
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
