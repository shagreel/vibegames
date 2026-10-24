import SwiftUI

/// Who goes first: one question, one answer.
///
/// The whole screen is the card, and the card is the button: tap it — or shake
/// the phone, the same as the dice — for another question. There is nothing else
/// on it, because the thing is passed around a table and read out loud, and a
/// screen with three buttons on it gets pressed by the wrong person.
struct FirstPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draw = FirstPlayer.draw()
    @State private var showingSettings = false
    /// Bumped on every draw, so the card's appearance can change without the
    /// screen animating the same view twice.
    @State private var drawn = 0

    /// Shaking the phone draws again, the way it rolls the dice.
    @State private var shake = ShakeMonitor()

    var body: some View {
        VStack(spacing: 0) {
            GameHeaderBar(title: "FIRST PLAYER",
                          subtitle: "One question, one answer.",
                          backIdentifier: "firstPlayer.back",
                          backLabel: "Back to utilities",
                          onBack: { dismiss() }) {
                SupportButton()
                GameSettingsButton(prefix: "firstPlayer") { showingSettings = true }
            }

            Spacer(minLength: 0)
            card
            Spacer(minLength: 0)
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .onAppear {
            Haptics.shared.prepare()
            shake.start { again() }
        }
        .onDisappear { shake.stop() }
        .sheet(isPresented: $showingSettings) {
            FirstPlayerSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var card: some View {
        Button {
            again()
        } label: {
            VStack(spacing: 26) {
                Text(draw.question)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(VibeTheme.hairline)
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                Text(draw.seat.instruction)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tap for another")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)
            .padding(.vertical, 34)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(VibeTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
                    // The tool colour, from the utilities list: a decider is not
                    // a game and should not look like one.
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(VibeTheme.vibeUtility)
                            .frame(width: 64, height: 4)
                            .padding(.top, 16)
                    }
            }
        }
        .buttonStyle(.plain)
        // The card is the only thing on the screen that does anything, and it is
        // the thing being read out, so its label is the whole sentence.
        .accessibilityLabel("\(draw.question) \(draw.seat.instruction).")
        .accessibilityHint("Draws another question")
        .accessibilityIdentifier("firstPlayer.card")
        .padding(.horizontal, 20)
        .padding(.top, 28)
        // A key that changes on every draw, so VoiceOver says the new sentence
        // rather than staying quiet because the element is "the same".
        .id(drawn)
    }

    private func again() {
        Haptics.shared.tap()
        draw = FirstPlayer.draw(avoiding: draw)
        drawn += 1
    }
}

/// The settings sheet: the two suite-wide settings and nothing else. A decider
/// has no rules of its own to set.
private struct FirstPlayerSettingsView: View {
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(VibeTheme.canvasTop, for: .navigationBar)
        }
        .followingAppearance()
    }
}
