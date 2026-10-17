import SwiftUI

/// Vibe Pairings' settings sheet.
///
/// The player's two settings, and — in a room — the one choice the game has: a
/// race can be played with hints or without. The deck is the deck, and the only
/// other decision is which card to keep.
struct VibeTrioSettingsView: View {
    @ObservedObject var model: VibeTrioModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    GameSettingsSections()
                    if model.isShared {
                        hintsSection
                    }
                }
                .padding(20)
            }
            .vibeCanvas()
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("trio.settings.done")
                }
            }
            .toolbarBackground(VibeTheme.canvasTop, for: .navigationBar)
        }
        .followingAppearance()
    }

    // MARK: - Hints

    /// The room's hint setting: the host's before the start, everybody's to read.
    ///
    /// A race with a hint button is a different game — one player can see a
    /// pairing and the others cannot — so it is a fact about the room rather
    /// than a switch on one phone.
    private var hintsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("Hints")

            SettingsCard {
                if model.canChangeHints {
                    SettingsRow(symbol: "lightbulb.fill",
                                title: "Hints in this race",
                                subtitle: "On gives every player the Hint button") {
                        Toggle("", isOn: Binding(
                            get: { model.hintsEnabled },
                            set: { on in Task { await model.setHints(on) } }
                        ))
                        .labelsHidden()
                        .tint(VibeTheme.vibeTrio)
                        .accessibilityIdentifier("trio.hintsToggle")
                    }
                } else {
                    SettingsRow(symbol: "lightbulb.fill",
                                title: "Hints in this race",
                                subtitle: model.hintsEnabled
                                    ? "On, for everybody"
                                    : "Off, for everybody — only the host can change it, before the start") {
                        EmptyView()
                    }
                }
            }
        }
    }
}
