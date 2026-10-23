import SwiftUI

/// The tile the hub lists — one for a game, and, on the utilities screen, one
/// for each tool.
///
/// This used to live inside `GameCard`. When the utilities arrived they needed
/// the same card, and two copies of a tile is exactly how the suite stops
/// looking like one thing: the paddings, the press animation and the "SOON"
/// badge are the hub's, not a game's, so they are drawn once here.
struct HubTile: View {
    let title: String
    let tagline: String
    let symbol: String
    let gradient: LinearGradient
    let identifier: String
    /// What VoiceOver says about tapping it. Empty for a tile that cannot be
    /// tapped yet.
    var hint: String = ""
    /// Announced but not playable: dimmed, with a SOON badge, and no play mark.
    var isAvailable = true

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(gradient)
                    .frame(width: 68, height: 68)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)

                    if !isAvailable {
                        Text("SOON")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .kerning(1)
                            .foregroundStyle(VibeTheme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(VibeTheme.surfaceStrong))
                    }
                }

                Text(tagline)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isAvailable {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(VibeTheme.primaryText.opacity(0.85))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
        .accessibilityHint(isAvailable ? hint : "")
    }
}

/// The press feel every tappable tile has: a small dip, no transform that would
/// outlive the tap.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75),
                       value: configuration.isPressed)
    }
}
