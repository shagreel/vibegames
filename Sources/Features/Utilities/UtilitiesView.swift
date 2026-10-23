import SwiftUI

/// The utilities list.
///
/// One screen in front of the tools so the hub keeps a single way in: this is
/// meant to grow — a timer, a scorekeeper, a coin — and a hub with a row of tool
/// buttons on it stops being a hub. The rows are the same tiles the games use.
struct UtilitiesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GameHeaderBar(title: "UTILITIES",
                              subtitle: "Tools for the table.",
                              backIdentifier: "utilities.back",
                              backLabel: "Back to games",
                              onBack: { dismiss() }) {
                    EmptyView()
                }

                VStack(spacing: 14) {
                    ForEach(UtilityEntry.all) { entry in
                        NavigationLink(value: entry.route) {
                            HubTile(title: entry.title,
                                    tagline: entry.tagline,
                                    symbol: entry.symbol,
                                    gradient: entry.gradient,
                                    identifier: "utility.\(entry.id)",
                                    hint: "Opens the \(entry.title.lowercased())")
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                    Text("More tools on the way.")
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            }
            .padding(.bottom, 40)
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }
}
