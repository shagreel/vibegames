import SwiftUI

/// Vibe Pairings' settings sheet.
///
/// The game has no choices of its own — the deck is the deck, and the only
/// decision in it is which card to keep — so this is the two settings that are
/// the player's rather than the game's: what they are called and whether the
/// games are light or dark.
struct VibeTrioSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    GameSettingsSections()
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
    }
}
