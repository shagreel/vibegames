import SwiftUI

/// The ways to say thanks. Kept in one place because the hub strip, the heart
/// button and the panel all point at the same three things.
enum Support {
    /// Venmo takes a username, not an email, and the web profile is the only
    /// link that works from a phone without the app installed.
    static let venmoHandle = "@chill-gelato"
    static let venmoURL = URL(string: "https://venmo.com/u/chill-gelato")!

    /// Where the browser versions live. Sharing costs nothing and helps as much
    /// as anything else here.
    static let playURL = URL(string: "https://play.vibegames.party")!

    static let heading = "Made with love"

    static let blurb = """
        I built these games for my own family. We play them in the evenings \
        — it is how we wind down together and stay close — and I wanted to share \
        that with other families.

        Every game is free. Nothing to unlock, no adverts, no account. If you would \
        like to say thanks, I would love to hear what you think of them, or you \
        could buy my family a treat to help cover what it costs to keep them running.
        """
}

/// The heart in the corner, and the panel behind it.
///
/// One component so every screen gets the same thing, and so the panel cannot
/// drift between them. It is on every screen because feedback about the game you
/// are in is the feedback worth having, and nobody goes looking for a settings
/// page to report a bug.
struct SupportButton: View {
    /// Which game the heart was tapped in, when it is not the hub. Named in the
    /// note, so an issue arrives with some context.
    var game: AppAnalytics.Game?

    @State private var showing = false

    var body: some View {
        Button {
            showing = true
            AppAnalytics.supportOpened(game: game)
        } label: {
            Image(systemName: "heart.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VibeTheme.heart)
                .frame(width: 40, height: 40)
                .background(Circle().fill(VibeTheme.surfaceStrong))
                .overlay(Circle().stroke(VibeTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Support Vibe Games")
        .accessibilityIdentifier("hub.support")
        .sheet(isPresented: $showing) {
            SupportView(game: game)
        }
    }
}

/// What the heart opens: why the games exist, how to say thanks, and the box to
/// say what is wrong.
struct SupportView: View {
    /// Which game the panel was opened from, when it is not the hub.
    var game: AppAnalytics.Game?

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

                    FeedbackForm(game: game)

                    Divider().padding(.vertical, 2)

                    Text("Other ways to help")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .kerning(1.5)
                        .foregroundStyle(VibeTheme.tertiaryText)

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
                        .simultaneousGesture(TapGesture().onEnded {
                            // The one signal that a treat was ever on its way:
                            // nothing comes back from Venmo.
                            AppAnalytics.donationTapped()
                        })

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
            // The panel is a form on a phone: without this the keyboard covers
            // Send and the only way to it is to guess that you can scroll.
            .scrollDismissesKeyboard(.interactively)
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

/// The form.
///
/// One box and a send button, deliberately: anything more would be a form to
/// fill in rather than a message to leave.
private struct FeedbackForm: View {
    /// Which game the note was written in, when it was written in one.
    let game: AppAnalytics.Game?

    @State private var text = ""
    @State private var sending = false
    @State private var sent = false
    @State private var problem: String?
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool {
        !sending && trimmed.count >= FeedbackService.minimumLength
    }

    var body: some View {
        if sent {
            thanks
        } else {
            form
        }
    }

    private var thanks: some View {
        VStack(spacing: 4) {
            Text("Thank you — that has gone straight to me.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
            Text("I read everything, even when I cannot reply to it.")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityIdentifier("feedback.sent")
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tell me what you think, or what is not working")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)

            TextEditor(text: $text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VibeTheme.surfaceStrong)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(VibeTheme.hairline, lineWidth: 1)
                        }
                }
                .focused($focused)
                .disabled(sending)
                .accessibilityIdentifier("feedback.text")

            if let problem {
                Text(problem)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("feedback.problem")
            }

            Button {
                Task { await send() }
            } label: {
                Text(sending ? "Sending…" : "Send")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(VibeTheme.surfaceStrong)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.5)
            .accessibilityIdentifier("feedback.send")

            Text("No account, no email address, nothing to sign up for — it reaches me as a note"
                 + (game.map { " about \($0.title)" } ?? "") + ".")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func send() async {
        sending = true
        problem = nil
        do {
            try await FeedbackService.send(trimmed, from: .ios, game: game?.title)
            focused = false
            sent = true
            // Only on the way through, not on an attempt: a note that failed to
            // send is not feedback anybody received.
            AppAnalytics.feedbackSent(game: game)
        } catch {
            problem = error.localizedDescription
        }
        sending = false
    }
}
}
