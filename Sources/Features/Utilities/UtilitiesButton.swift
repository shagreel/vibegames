import SwiftUI

/// The hub's one way into the utilities.
///
/// A slim row rather than another full tile: the games above it are the product,
/// and a tool should look like a drawer under them rather than a sixth game.
struct UtilitiesButton: View {
    var body: some View {
        NavigationLink(value: UtilityRoute.list) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VibeTheme.vibeUtility)
                        .frame(width: 44, height: 44)

                    Image(systemName: "dice.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Utilities")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)

                    Text("Dice, and whatever else the table needs.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VibeTheme.tertiaryText)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(VibeTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hub.utilities")
        .accessibilityHint("Opens the utilities")
    }
}
