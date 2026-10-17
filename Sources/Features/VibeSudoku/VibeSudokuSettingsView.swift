import SwiftUI

/// Sheet for the one thing Number Vibe lets you choose.
///
/// The choice lived on the keypad for a day, which was the wrong place for a
/// setting: it sat next to the keys you are using while solving, and it changed
/// shape under your thumb as it was tapped. It is behind the settings button
/// now, with the player's name and the appearance above it, and it is a switch
/// rather than two rows — the choice is one thing with two states, and the rows
/// took a third of the sheet to say so.
///
/// The keypad goes back to the three things a player actually touches while
/// solving: notes, erase and the digits.
struct VibeSudokuSettingsView: View {
    @ObservedObject var model: VibeSudokuModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    GameSettingsSections()
                    notesSection
                    explanation
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
                        .accessibilityIdentifier("sudokuSettings.done")
                }
            }
            .toolbarBackground(VibeTheme.canvasTop, for: .navigationBar)
        }
        .followingAppearance()
    }

    // MARK: - Sections

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("Notes per square")

            SettingsCard {
                SettingsRow(symbol: "pencil",
                            title: "Nine marks per square",
                            subtitle: "Off draws four big ones. On draws every candidate, three by three.") {
                    Toggle("", isOn: Binding(
                        get: { model.noteLimit == 9 },
                        set: { model.setNoteLimit($0 ? 9 : 4) }
                    ))
                    .labelsHidden()
                    .tint(VibeTheme.sudokuSelection)
                    .accessibilityIdentifier("sudokuSettings.nineMarks")
                }
            }
        }
    }

    private var explanation: some View {
        Text("""
            A square can hold nine candidates, and four of them make a hard puzzle \
            harder. Nine are every candidate, each in its own little box, the way \
            pencil marks are read on paper — but nine marks in a phone-sized square \
            are hard to read, and an unreadable note is worse than no note at all. \
            Whichever you pick is kept for next time.
            """)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(VibeTheme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
