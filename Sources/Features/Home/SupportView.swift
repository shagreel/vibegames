import SwiftUI

/// The ways to say thanks. Kept in one place because the heart button, the panel
/// and the website all point at the same things.
///
/// There is one way to pay in this app, and Apple takes it: a consumable tip,
/// sold by the App Store, in `TreatJar`. What there is *not* is a link to any
/// other way to pay — no Venmo, no website page that carries one — because
/// guideline 3.1.1 forbids pointing somebody at a purchasing mechanism other
/// than in-app purchase, and `Tools/check_app_no_payments.py` fails if one comes
/// back. The website keeps that route for people playing in a browser, where
/// Apple has no say in it.
enum Support {
    /// Where the browser versions live. Sharing costs nothing and is the thing
    /// that actually helps.
    static let playURL = URL(string: "https://play.vibegames.party")!

    /// The privacy policy and the support page. App Store Connect wants a URL for
    /// each, and a reviewer wants to find the policy without leaving the app to
    /// look for it — which is why both are linked from the panel's footer.
    static let privacyURL = URL(string: "https://vibegames.party/privacy")!
    static let supportURL = URL(string: "https://vibegames.party/support")!

    static let heading = "Made with love"

    static let blurb = """
        I built these games for my own family. We play them in the evenings \
        — it is how we wind down together and stay close — and I wanted to share \
        that with other families.

        Every game is free. Nothing to unlock, no adverts, no account. If you would \
        like to say thank you, you can buy my family a treat — it is a gift, and it \
        does not unlock anything, because there is nothing locked.
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
    @StateObject private var treats = TreatJar()

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

                    VStack(spacing: 12) {
                        treatRow

                        ShareLink(item: Support.playURL) {
                            SupportRow(symbol: "person.2.fill",
                                       title: "Share it with another family",
                                       detail: "They can play in a browser tonight, free",
                                       tint: VibeTheme.arm)
                        }
                        .accessibilityIdentifier("support.share")
                    }
                    .padding(.top, 4)

                    Text("Nothing here is expected. The games are free either way.")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)

                    // The two URLs App Store Connect asks for, reachable from
                    // inside the app. A reviewer looking for the privacy policy
                    // should not have to guess that it is on the website.
                    HStack(spacing: 10) {
                        Link("Privacy", destination: Support.privacyURL)
                            .accessibilityIdentifier("support.privacyPolicy")
                        Text("·").foregroundStyle(VibeTheme.tertiaryText)
                        Link("Support", destination: Support.supportURL)
                            .accessibilityIdentifier("support.supportPage")
                    }
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .vibeCanvas()
            .task { await treats.load() }
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

    /// The tip, when the store has one to sell.
    ///
    /// Hidden while loading and hidden when there is nothing to load: before the
    /// product exists in App Store Connect, and in any build without a StoreKit
    /// configuration, the store returns nothing — and a button that cannot do
    /// anything is worse than no button. A price that is not there yet is not
    /// worth a placeholder either, because the price is the only thing this row
    /// has to say.
    @ViewBuilder
    private var treatRow: some View {
        switch treats.state {
        case .ready(let price):
            Button {
                Task { await treats.buy() }
            } label: {
                SupportRow(symbol: "gift.fill",
                           title: "Buy us a treat",
                           detail: price,
                           tint: VibeTheme.heart)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("support.treat")

        case .buying:
            SupportRow(symbol: "gift.fill",
                       title: "Buy us a treat",
                       detail: "Waiting for the App Store…",
                       tint: VibeTheme.heart)
                .opacity(0.6)
                .accessibilityIdentifier("support.treatWaiting")

        case .thanked:
            SupportRow(symbol: "heart.fill",
                       title: "Thank you",
                       detail: "That means a lot. I hope your table has a good evening.",
                       tint: VibeTheme.heart)
                .accessibilityIdentifier("support.treatThanked")

        case .loading, .unavailable:
            EmptyView()
        }
    }
}

/// One line of "here is a thing you could do".
///
/// Shared by the rows in the panel rather than written twice, so they cannot
/// drift apart.
private struct SupportRow: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
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
        VStack(spacing: 8) {
            Text("Thank you — it arrived.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
            // What happens next, and a way back: a box that becomes a dead end
            // makes people hold the second thought until tomorrow. The words
            // match the web's panel, which is the same panel on a different
            // screen.
            Text("There is no reply by email, so this is where the note ends — it goes on the list and gets worked through. Found something else?")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button("Send another") {
                text = ""
                sent = false
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(VibeTheme.primaryText)
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background { Capsule().fill(VibeTheme.surfaceStrong) }
            .accessibilityIdentifier("feedback.sendAnother")
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
