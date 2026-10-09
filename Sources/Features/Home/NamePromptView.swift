import SwiftUI

/// Asked for a player's name, wherever it turns out to be needed.
///
/// The suite has exactly one of these. It is shown at the front door on a first
/// run, and again from a game's lobby if someone gets that far without a name and
/// then asks for a shared game — the point being that choosing to play *solo*
/// never asks, which is what it used to do.
struct NamePromptView: View {
    let accent: LinearGradient
    let symbol: String
    let message: String
    /// Keeps the hub's prompt and a game's prompt apart for the UI tests.
    let identifierPrefix: String
    /// The name they chose, or nil if they would rather not say.
    let finish: (String?) -> Void

    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var trimmed: String? { PlayerIdentity.clean(draft) }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)

            Image(systemName: symbol)
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(accent)

            VStack(spacing: 8) {
                Text("What should we call you?")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)

                Text(message)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)

            PlayerNameField(text: $draft,
                            identifier: "\(identifierPrefix).nameField",
                            onSubmit: save)
                .focused($fieldFocused)

            VStack(spacing: 6) {
                Button("Save") { save() }
                    .buttonStyle(VibePrimaryButtonStyle(gradient: accent))
                    .disabled(trimmed == nil)
                    .accessibilityIdentifier("\(identifierPrefix).nameSave")

                Button("Not now") { finish(nil) }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier("\(identifierPrefix).nameSkip")
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 30)
        .vibeCanvas()
        .onAppear { fieldFocused = true }
    }

    private func save() {
        guard let name = trimmed else { return }
        finish(name)
    }
}

extension NamePromptView {
    /// The suite's own copy, shown once at the front door.
    static func firstRun(finish: @escaping (String?) -> Void) -> NamePromptView {
        NamePromptView(
            accent: VibeTheme.vibeWords,
            symbol: "person.crop.circle.fill",
            message: "It is only needed for games you play with other people, and you can change it later from the home screen.",
            identifierPrefix: "firstRun",
            finish: finish
        )
    }
}
