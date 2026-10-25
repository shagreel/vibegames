import SwiftUI

/// The 6 x 5 guess grid.
struct VibeWordsBoardView: View {
    let guesses: [String]
    let currentGuess: String
    let answer: String
    let isRoundOver: Bool
    /// Bumped whenever a guess is rejected, to shake the active row.
    let rejectionCount: Int

    /// Bumped by the parent when a fresh round begins, to re-arm the flip.
    let roundToken: Int

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 6
            let tile = min((proxy.size.width - spacing * 4) / 5,
                           (proxy.size.height - spacing * 5) / 6)

            VStack(spacing: spacing) {
                ForEach(0..<WordGameEngine.maxGuesses, id: \.self) { row in
                    rowView(row: row, tile: tile, spacing: spacing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Guess grid")
        .accessibilityValue("\(guesses.count) of \(WordGameEngine.maxGuesses) guesses used")
        .accessibilityIdentifier("words.board")
    }

    private func rowView(row: Int, tile: CGFloat, spacing: CGFloat) -> some View {
        let isCommitted = row < guesses.count
        let isActive = row == guesses.count && !isRoundOver
        let guess = isCommitted ? guesses[row] : (isActive ? currentGuess : "")
        let letters = Array(guess.uppercased())
        let feedback = isCommitted
            ? WordGameEngine.score(guess: guesses[row], answer: answer)
            : []

        return HStack(spacing: spacing) {
            ForEach(0..<WordGameEngine.wordSize, id: \.self) { column in
                VibeWordsTile(
                    letter: column < letters.count ? String(letters[column]) : "",
                    feedback: column < feedback.count ? feedback[column] : nil,
                    isActive: isActive,
                    size: tile,
                    roundToken: roundToken,
                    flipDelay: Double(column) * 0.09
                )
            }
        }
        .offset(x: isActive ? shakeOffset : 0)
        .animation(.spring(response: 0.06, dampingFraction: 0.3), value: rejectionCount)
    }

    private var shakeOffset: CGFloat {
        // Alternating nudge, reset between shakes, so a repeated rejection
        // still animates.
        rejectionCount % 2 == 0 ? -9 : 9
    }
}

/// One letter tile.
/// Whether a tile starts its life face-up.
///
/// A tile is dealt face-down and turns over when its row is scored. A board
/// picked back up arrives with rows already scored, so those tiles are born
/// face-up: there is no flip to animate, and a face still turned away is a board
/// showing nothing where the guesses should be — which is exactly what the owner
/// reported: the keyboard remembered the letters, the rows above it were blank.
enum VibeWordsTileReveal {
    static func startsFaceUp(feedback: LetterFeedback?) -> Bool {
        feedback != nil
    }
}

private struct VibeWordsTile: View {
    let letter: String
    let feedback: LetterFeedback?
    let isActive: Bool
    let size: CGFloat
    let roundToken: Int
    let flipDelay: Double

    @State private var hasFlipped: Bool

    init(letter: String,
         feedback: LetterFeedback?,
         isActive: Bool,
         size: CGFloat,
         roundToken: Int,
         flipDelay: Double) {
        self.letter = letter
        self.feedback = feedback
        self.isActive = isActive
        self.size = size
        self.roundToken = roundToken
        self.flipDelay = flipDelay
        _hasFlipped = State(initialValue: VibeWordsTileReveal.startsFaceUp(feedback: feedback))
    }

    private var isScored: Bool { feedback != nil }

    private var fill: Color {
        switch feedback {
        case .correct: return VibeTheme.tileCorrect
        case .present: return VibeTheme.tilePresent
        case .absent: return VibeTheme.tileAbsent
        case nil: return VibeTheme.tileIdle
        }
    }

    private var border: Color {
        if isScored { return .clear }
        return letter.isEmpty && !isActive
            ? VibeTheme.tileBorder.opacity(0.5)
            : VibeTheme.tileBorder
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(fill)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(border, lineWidth: 2)
                }

            Text(letter)
                .font(.system(size: size * 0.52, weight: .heavy, design: .rounded))
                .foregroundStyle(isScored ? Color.white : VibeTheme.primaryText)
                .minimumScaleFactor(0.5)
        }
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(isScored && !hasFlipped ? 90 : 0),
                          axis: (x: 0, y: 1, z: 0))
        .onChange(of: feedback) { _, newValue in
            guard newValue != nil, !hasFlipped else { return }
            withAnimation(.easeOut(duration: 0.34).delay(flipDelay)) {
                hasFlipped = true
            }
        }
        .onChange(of: roundToken) { _, _ in
            // A new round deals unscored tiles, which start face-down. A round
            // picked back up bumps the token because its word has arrived, and
            // its scored rows must stay face-up.
            hasFlipped = VibeWordsTileReveal.startsFaceUp(feedback: feedback)
        }
        .accessibilityLabel(letter.isEmpty ? "Empty" : letter)
    }
}
