import SwiftUI

/// A shared game's code, shown as a code.
///
/// It used to read `CODE TRAM PUFF` — a label running straight into two words,
/// which is three four-letter words in a row. The owner's note said the two code
/// words need setting off so it is clear they are the code, so the code is now a
/// caption over a box, and the two halves sit apart inside it with a dot between
/// them: one code, in two words.
///
/// The spoken label deliberately keeps the plain form (`Game code TRAM PUFF`,
/// no dot), because a code is read out and typed from memory, and every helper
/// that parses one out of a label splits on spaces.
struct GameCodeBadge: View {
    enum Size {
        /// The waiting room, where the code is the only thing on screen.
        case prominent
        /// A lobby panel, where the code shares the screen with instructions.
        case inline
    }

    /// The code as it is stored: `tram-puff`.
    let code: String
    var size: Size = .prominent
    /// The game's own accessibility identifier, so its tests still find it.
    let identifier: String
    /// A line under the code: who to tell, or what to do with it.
    var hint: String?

    private var display: String { GameCode.display(code) }
    private var words: [String] { display.split(separator: " ").map(String.init) }

    private var wordSize: CGFloat { size == .prominent ? 30 : 20 }

    var body: some View {
        VStack(spacing: 8) {
            Text("Game code")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .kerning(1.8)
                .textCase(.uppercase)
                .foregroundStyle(VibeTheme.tertiaryText)

            HStack(spacing: wordSize * 0.38) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    if index > 0 {
                        Text("·")
                            .font(.system(size: wordSize, weight: .black, design: .monospaced))
                            .foregroundStyle(VibeTheme.tertiaryText)
                    }
                    Text(word)
                        .font(.system(size: wordSize, weight: .black, design: .monospaced))
                        .kerning(size == .prominent ? 3.5 : 2)
                        .foregroundStyle(VibeTheme.primaryText)
                }
            }
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .textSelection(.enabled)
            .padding(.horizontal, size == .prominent ? 20 : 14)
            .padding(.vertical, size == .prominent ? 12 : 8)
            .background {
                RoundedRectangle(cornerRadius: size == .prominent ? 16 : 12, style: .continuous)
                    .fill(VibeTheme.surfaceStrong)
                    .overlay {
                        RoundedRectangle(cornerRadius: size == .prominent ? 16 : 12,
                                         style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
            }

            if let hint {
                Text(hint)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game code \(display)")
        .accessibilityIdentifier(identifier)
    }
}
