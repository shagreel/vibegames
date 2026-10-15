import SwiftUI

/// The one place a player types their name. The first-run prompt and the
/// preferences screen both use it, so the field cannot mean two different things
/// in two different places.
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
struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("vibegames.appearance") private var appearance = AppearancePreference.system.rawValue
    @State private var draftName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameSection
                    appearanceSection
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
                    Button("Done") { commitName(); dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("preferences.done")
                }
            }
        }
        .onAppear { draftName = PlayerIdentity.name ?? "" }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("YOUR NAME")

            PlayerNameField(text: $draftName,
                            identifier: "preferences.nameField",
                            onSubmit: commitName)
                // Written as it is typed rather than only on the way out, so a
                // name that has been entered is already in force if the screen
                // is swiped away. A field left empty does not erase the name.
                .onChange(of: draftName) { _, _ in
                    if let clean = PlayerIdentity.clean(draftName) { PlayerIdentity.name = clean }
                }

            Text("Shown to everyone in a shared game. The other games do not need it.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("APPEARANCE")

            Picker("Appearance", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { option in
                    Text(option.shortTitle).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("preferences.appearance")

            Text("Match System follows the device's light or dark setting.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .kerning(1.5)
            .foregroundStyle(VibeTheme.tertiaryText)
    }

    /// Where a settings screen keeps the version, the privacy policy and the way
    /// to get help — and where they are on screen without scrolling, which the
    /// bottom of the support panel is not.
    ///
    /// The version comes from the bundle rather than a constant here, so it
    /// cannot disagree with what is installed.
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("ABOUT")

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

    private func commitName() {
        if let clean = PlayerIdentity.clean(draftName) { PlayerIdentity.name = clean }
    }
}
