import SwiftUI

/// The pieces every game's settings sheet is built from.
///
/// Five sheets were about to be written, and the first two had already grown
/// their own heading style, their own card and their own row. This is those,
/// once. What a game adds is its own controls; the chrome, the two suite-wide
/// settings and the way they are laid out are not the game's business.
///
/// The two suite-wide settings are here rather than only on the hub's
/// Preferences screen because a player who wants to correct their name or turn
/// the lights on is usually in the middle of a game, and having to leave it to
/// do that is how a settings screen goes unused.

/// Makes a sheet follow the appearance while it is open.
///
/// The colour scheme is set at the root of the app, and a sheet that is already
/// presented does not reliably rebuild when that changes underneath it: one
/// direction repaints and the other does not, which is what the owner reported.
/// Applying it to the sheet's own content makes the sheet decide, instead of
/// waiting for the presentation that put it on screen.
struct ThemedSheet: ViewModifier {
    @AppStorage("vibegames.appearance") private var appearance = AppearancePreference.system.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(AppearancePreference(rawValue: appearance)?.colorScheme)
    }
}

extension View {
    /// For the root of a sheet's content — every sheet in the suite, so none of
    /// them is the one that lags.
    func followingAppearance() -> some View {
        modifier(ThemedSheet())
    }
}

/// A heading over one group of settings.
struct SettingsSectionTitle: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .black, design: .rounded))
            .kerning(1.6)
            .foregroundStyle(VibeTheme.tertiaryText)
    }
}

/// The rounded panel that rows sit in.
struct SettingsCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
    }
}

/// One setting: an icon, a name, a line explaining it, and a control.
struct SettingsRow<Trailing: View>: View {
    private let symbol: String?
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    init(symbol: String? = nil,
         title: String,
         subtitle: String? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 14) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VibeTheme.calm)
                    .frame(width: 26)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// The way into a game's settings, in the corner of its header.
///
/// One glyph for one idea, in the same place on every screen — the suite's
/// existing rule for the heart, applied to the other button the games share.
struct GameSettingsButton: View {
    /// The game's short name, for the accessibility identifier: the same prefix
    /// its other controls use.
    let prefix: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .buttonStyle(VibeIconButtonStyle())
        .accessibilityLabel("Game settings")
        .accessibilityIdentifier("\(prefix).settings")
    }
}

/// Your name and whether the games are light or dark: the two settings that
/// belong to the player rather than to a game.
struct GameSettingsSections: View {
    @AppStorage("vibegames.appearance") private var appearance = AppearancePreference.system.rawValue
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            nameSection
            appearanceSection
        }
        .onAppear { draftName = PlayerIdentity.name ?? "" }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SettingsSectionTitle("Your name")
                Spacer(minLength: 8)
                if !draftName.isEmpty {
                    Button("Forget it") {
                        PlayerIdentity.forgetName()
                        draftName = ""
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
                    .accessibilityIdentifier("gameSettings.forgetName")
                }
            }

            PlayerNameField(text: $draftName,
                            identifier: "gameSettings.nameField",
                            onSubmit: commitName)
                // Written as it is typed rather than only on the way out, so a
                // name that has been entered is already in force if the sheet
                // is swiped away. A field left empty does not erase the name.
                .onChange(of: draftName) { _, _ in commitName() }

            Text("Shown to everyone in a game you play together. Up to \(PlayerIdentity.maxNameLength) characters.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("Appearance")

            Picker("Appearance", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { option in
                    Text(option.shortTitle).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("gameSettings.appearance")

            Text("Match System follows the device's light or dark setting.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func commitName() {
        // Trimmed and capped as it is typed: the rules refuse a name over 24
        // characters, and a field that lets you type one is a field that lets
        // you break every game you are in.
        if let clean = PlayerIdentity.clean(draftName) { PlayerIdentity.name = clean }
        if draftName.count > PlayerIdentity.maxNameLength {
            draftName = String(draftName.prefix(PlayerIdentity.maxNameLength))
        }
    }
}
