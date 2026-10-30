import SwiftUI

/// The end of a round, in the same shape in every game.
///
/// Four games had four treatments and two of them put the only way to start
/// another round in a small pill in the corner of the header, which is the one
/// thing a player wants at that moment.
///
/// This is the app's half of the panel the web client already draws (`RoundOver`
/// in `web/src/hub/RoundOver.tsx`): a title, a line of detail, whatever the game
/// has of its own, and one full-width button. "Play again" is not a parameter,
/// because the whole point is that the suite says the same thing at the same
/// moment everywhere. What a game *does* have to add — Sudoku's next difficulty,
/// Pairings' standings — goes in `extra`.
///
/// It sits in the game's column under the header, not floating over the board:
/// the board is finished, but it is still the thing being talked about.
struct RoundOverPanel<Extra: View>: View {
    private let title: String
    private let detail: String?
    private let accent: AnyShapeStyle
    private let primaryLabel: String
    private let primaryIdentifier: String
    private let action: () -> Void
    private let secondaryLabel: String?
    private let secondaryIdentifier: String?
    private let secondaryAction: (() -> Void)?
    private let extra: Extra

    init(title: String,
         detail: String? = nil,
         accent: AnyShapeStyle,
         primaryLabel: String = "Play again",
         primaryIdentifier: String,
         action: @escaping () -> Void,
         secondaryLabel: String? = nil,
         secondaryIdentifier: String? = nil,
         secondaryAction: (() -> Void)? = nil,
         @ViewBuilder extra: () -> Extra) {
        self.title = title
        self.detail = detail
        self.accent = accent
        self.primaryLabel = primaryLabel
        self.primaryIdentifier = primaryIdentifier
        self.action = action
        self.secondaryLabel = secondaryLabel
        self.secondaryIdentifier = secondaryIdentifier
        self.secondaryAction = secondaryAction
        self.extra = extra()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }

            extra

            Button(action: action) {
                Label(primaryLabel, systemImage: "arrow.clockwise")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    // The one ink that is right on a bright gradient. Not
                    // `VibeTheme.primaryText`: that token flips to white in the
                    // dark appearance, and these gradients are bright in both.
                    // It is the same near-black the web's button uses.
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accent)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(primaryIdentifier)

            if let secondaryLabel, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(secondaryIdentifier ?? "")
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
        // The board below is padded 16; the panel lines up with it rather than
        // with the 20 the header uses.
        .padding(.horizontal, 16)
    }
}

extension RoundOverPanel where Extra == EmptyView {
    /// The panel for a game that has nothing of its own to add.
    init(title: String,
         detail: String? = nil,
         accent: AnyShapeStyle,
         primaryIdentifier: String,
         action: @escaping () -> Void) {
        self.init(title: title,
                  detail: detail,
                  accent: accent,
                  primaryIdentifier: primaryIdentifier,
                  action: action) {
            EmptyView()
        }
    }
}
