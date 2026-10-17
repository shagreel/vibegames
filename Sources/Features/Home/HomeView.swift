import SwiftUI

/// Hub screen: pick a game.
struct HomeView: View {
    @AppStorage(PlayerIdentity.nameKey) private var storedName = ""
    @AppStorage(PlayerIdentity.askedKey) private var promptAnswered = ""

    @State private var showingPreferences = false
    @State private var showingNamePrompt = false

    /// Read through `PlayerIdentity` so a field of nothing but spaces counts as
    /// no name here too, rather than only where the games look.
    private var name: String? { PlayerIdentity.clean(storedName) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(GameEntry.all) { entry in
                    GameCard(entry: entry)
                }

                playInBrowserCard

                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showingNamePrompt) {
            NamePromptView.firstRun { chosen in
                if let chosen { PlayerIdentity.name = chosen }
                // Answered or waved away, it does not ask again — a skipped
                // prompt can still be filled in from the name chip.
                promptAnswered = PlayerIdentity.askedValue
                showingNamePrompt = false
            }
        }
        .task {
            AppAnalytics.screen("hub")
            // Asked once, at the front door. The games that need a name used to
            // ask for it themselves, in the middle of their own lobby.
            if name == nil, promptAnswered.isEmpty { showingNamePrompt = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text("VIBE GAMES")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .kerning(1)
                    .foregroundStyle(VibeTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 12)
                SupportButton()
                preferencesButton
            }

            Text("Quick party games. Pass it round.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)

            nameChip

        }
        .padding(.bottom, 6)
    }

    /// The whole of the settings, in one place. It used to be appearance only,
    /// which left the player's name with nowhere to live but inside each game.
    private var preferencesButton: some View {
        Button {
            showingPreferences = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VibeTheme.primaryText)
                .frame(width: 40, height: 40)
                .background(Circle().fill(VibeTheme.surfaceStrong))
                .overlay(Circle().stroke(VibeTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preferences")
        .accessibilityIdentifier("hub.preferences")
    }

    /// Says who the app thinks you are, and is the short way to change it.
    private var nameChip: some View {
        Button {
            showingPreferences = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: name == nil ? "person.badge.plus" : "person.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(name.map { "Playing as \($0)" } ?? "Add your name")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(name == nil ? VibeTheme.secondaryText : VibeTheme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(VibeTheme.surface))
            .overlay(Capsule().stroke(VibeTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityIdentifier("hub.playerName")
    }

    /// The browser version is live, so it is a place to play rather than a line
    /// about something on its way. The whole card is the `Link`, because a card
    /// that looked tappable next to a QR code should open the same thing the QR
    /// code does. Same margins, radius, fill and type as the game cards around
    /// it.
    private var playInBrowserCard: some View {
        Link(destination: Support.playURL) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Play in your browser")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)

                    // No count in the copy: the number of games goes stale, and
                    // the suite stopped saying "five" for that reason.
                    Text("The same games, nothing to install.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 14) {
                    qrPlate

                    VStack(alignment: .leading, spacing: 4) {
                        Text("play.vibegames.party")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(VibeTheme.primaryText)

                        Text("Scan with another device, or tap to open.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(VibeTheme.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VibeTheme.tertiaryText)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(VibeTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("Play in your browser. The same games, nothing to install. play.vibegames.party")
        .accessibilityHint("Opens play.vibegames.party")
        .accessibilityIdentifier("hub.playInBrowser")
    }

    /// Black on white in both appearances, with its own quiet zone. A QR code on
    /// the dark card would not scan, and this is the one place a bare white is
    /// right: the code is fixed black-on-white rather than a themed colour.
    private var qrPlate: some View {
        Image("browser-qr")
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: 120, height: 120)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            }
            // The URL beside it is the readable version, so the picture says
            // nothing VoiceOver needs to hear twice.
            .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                Text("More games on the way.")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(VibeTheme.tertiaryText)

            // The ways-to-help line came out when the tip went in. Pointing at a
            // page whose ways to help include a Venmo link is exactly the
            // steering guideline 3.1.1 forbids for something sold in the app, and
            // the tip is sold in the app now.
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// A single game tile.
struct GameCard: View {
    let entry: GameEntry

    var body: some View {
        if let route = entry.route {
            NavigationLink(value: route) {
                card
            }
            .buttonStyle(PressableCardStyle())
        } else {
            card
                .opacity(0.5)
                .accessibilityLabel("\(entry.title), coming soon")
        }
    }

    private var card: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(entry.gradient)
                    .frame(width: 68, height: 68)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

                Image(systemName: entry.symbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)

                    if !entry.isAvailable {
                        Text("SOON")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .kerning(1)
                            .foregroundStyle(VibeTheme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(VibeTheme.surfaceStrong))
                    }
                }

                Text(entry.tagline)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if entry.isAvailable {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(VibeTheme.primaryText.opacity(0.85))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("game.\(entry.id)")
        .accessibilityHint(entry.isAvailable ? "Opens the game" : "")
    }
}

private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75),
                       value: configuration.isPressed)
    }
}
