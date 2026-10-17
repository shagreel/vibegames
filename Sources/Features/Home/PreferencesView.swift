import SwiftUI

/// The one place a player types their name. The first-run prompt and the
/// settings sheets both use it, so the field cannot mean two different things in
/// two different places.
struct PlayerNameField: View {
    @Binding var text: String
    let identifier: String
    var onSubmit: () -> Void = {}

    var body: some View {
        TextField("Your name", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .foregroundStyle(VibeTheme.primaryText)
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VibeTheme.surfaceStrong)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .onSubmit(onSubmit)
            .accessibilityIdentifier(identifier)
    }
}

/// Everything that applies to the whole suite rather than to one game: what you
/// are called, and how the app looks.
///
/// Those two settings are `GameSettingsSections`, which is also the top of every
/// game's settings sheet — one definition, so the hub and the five games cannot
/// drift apart. What is left on this screen is what only it has: the version, the
/// policy and the way to get help, and they are here without scrolling, which the
/// bottom of the support panel is not.
struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    GameSettingsSections()
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .vibeCanvas()
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("preferences.done")
                }
            }
        }
        .followingAppearance()
    }

    /// Where a settings screen keeps the version, the privacy policy and the way
    /// to get help.
    ///
    /// The version comes from the bundle rather than a constant here, so it
    /// cannot disagree with what is installed.
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("About")

            HStack(spacing: 16) {
                Link("Privacy", destination: Support.privacyURL)
                    .accessibilityIdentifier("preferences.privacy")
                Link("Support", destination: Support.supportURL)
                    .accessibilityIdentifier("preferences.support")
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))

            Text("Vibe Games \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .accessibilityIdentifier("preferences.version")
        }
    }
}
