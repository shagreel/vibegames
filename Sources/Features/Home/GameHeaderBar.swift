import SwiftUI

/// The strip across the top of every game.
///
/// Five games had five copies of this markup — the same back chevron, the same
/// title, the same subtitle, the same heart in the corner — and the owner's note
/// about it was that on a small screen the subtitle is cut off: "2 players · 3
/// good pairings · 0:42 · code TRAM PUFF" does not fit on one line beside three
/// buttons. So it is one definition, and the subtitle is allowed a second line —
/// and the title shrinks rather than wrapping into two lines of its own.
///
/// What each game keeps is its corner: the heart and the settings button are
/// passed in by the game, in the order it wants them, after anything else it
/// needs there. Nothing here draws a transform, for the reason the web header
/// learned: a transform near a `position: fixed` child becomes its containing
/// block.
struct GameHeaderBar<Corner: View>: View {
    private let title: String
    private let subtitle: String
    private let backIdentifier: String
    private let backLabel: String
    private let onBack: () -> Void
    private let corner: Corner

    init(title: String,
         subtitle: String,
         backIdentifier: String,
         backLabel: String,
         onBack: @escaping () -> Void,
         @ViewBuilder corner: () -> Corner) {
        self.title = title
        self.subtitle = subtitle
        self.backIdentifier = backIdentifier
        self.backLabel = backLabel
        self.onBack = onBack
        self.corner = corner()
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(VibeIconButtonStyle())
            .accessibilityLabel(backLabel)
            .accessibilityIdentifier(backIdentifier)

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .kerning(3.5)
                    .foregroundStyle(VibeTheme.primaryText)
                    // One line, shrinking: a title that wraps to two lines makes
                    // the header taller and moves the board down.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            // The corner buttons keep their size; the words give way to them.
            .layoutPriority(-1)

            HStack(spacing: 6) {
                corner
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
}
