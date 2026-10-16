import SwiftUI

/// Word Vibe's settings sheet.
///
/// Like Vibe Pairings, the game has no choices of its own: there is one word,
/// six guesses and no dial to turn. This is where the player changes what they
/// are called and whether the games are light or dark, without leaving the game
/// to find the hub's Preferences screen.
struct VibeWordsSettingsView: View {
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
                        .accessibilityIdentifier("words.settings.done")
                }
            }
            .toolbarBackground(VibeTheme.canvasTop, for: .navigationBar)
        }
    }
}
