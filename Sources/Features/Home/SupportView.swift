import SwiftUI

/// The ways to say thanks. Kept in one place because the hub strip, the heart
/// button and the panel all point at the same three things.
enum Support {
    /// Venmo takes a username, not an email, and the web profile is the only
    /// link that works from a phone without the app installed.
    static let venmoHandle = "@chill-gelato"
    static let venmoURL = URL(string: "https://venmo.com/u/chill-gelato")!

    static let feedbackURL = URL(string: "https://github.com/shagreel/vibegames/issues")!
    /// Where the browser versions live. Sharing costs nothing and helps as much
    /// as anything else here.
    static let playURL = URL(string: "https://play.vibegames.party")!

    static let heading = "Made with love"

    static let blurb = """
        I built these four games for my own family. We play them in the evenings \
        — it is how we wind down together and stay close — and I wanted to share \
        that with other families.

        Every game is free. Nothing to unlock, no adverts, no account. If you would \
        like to say thanks, I would love to hear what you think of them, or you \
        could buy my family a treat to help cover what it costs to keep them running.
        """
}

/// What the heart opens: why the games exist, and how to say thanks.
struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(VibeTheme.heart)
                        .shadow(color: VibeTheme.heart.opacity(0.5), radius: 22)
                        .padding(.top, 12)

                    VStack(spacing: 8) {
                        Text(Support.heading)
                            .font(.system(size: 25, weight: .heavy, design: .rounded))
                            .foregroundStyle(VibeTheme.primaryText)

                        Text(Support.blurb)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(VibeTheme.secondaryText)
                            .lineSpacing(3)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 6)

                    VStack(spacing: 10) {
                        // Venmo: the handle is shown as well as linked, because
                        // it is what someone needs if the link opens the wrong
                        // app or they would rather type it themselves.
                        Link(destination: Support.venmoURL) {
                            row(symbol: "gift.fill",
                                title: "Buy us a treat",
                                detail: "Venmo \(Support.venmoHandle)",
                                tint: VibeTheme.heart)
                        }

                        Link(destination: Support.feedbackURL) {
                            row(symbol: "bubble.left.and.text.bubble.right.fill",
                                title: "Tell me what you think",
                                detail: "Ideas, bugs, or a game you would like next",
                                tint: VibeTheme.calm)
                        }

                        ShareLink(item: Support.playURL) {
                            row(symbol: "person.2.fill",
                                title: "Share it with another family",
                                detail: "They can play in a browser tonight, free",
                                tint: VibeTheme.arm)
                        }
                    }
                    .padding(.top, 4)

                    Button {
                        UIPasteboard.general.string = Support.venmoHandle
                        copied = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy the Venmo handle",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(VibeTheme.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(VibeTheme.surfaceStrong)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("support.copyVenmo")

                    Text("Nothing here is expected. The games are free either way.")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .vibeCanvas()
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("support.done")
                }
            }
        }
    }

    private func row(symbol: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(Circle().fill(tint.opacity(0.16)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                Text(detail)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VibeTheme.tertiaryText)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
    }
}
