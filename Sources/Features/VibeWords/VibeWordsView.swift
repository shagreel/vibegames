import SwiftUI

/// Word Vibe: guess the five-letter word, solo or with everyone in the room.
struct VibeWordsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VibeWordsModel()
    @State private var joinCode = ""
    @State private var showingNamePrompt = false
    @State private var showingSettings = false
    /// Held while a name is collected, so the tap that needed it still happens.
    @State private var pendingAction: (() -> Void)?
    @State private var roundToken = 0

    var body: some View {
        Group {
            switch model.session {
            case .lobby:
                lobby
            case .solo, .shared:
                game
            }
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingNamePrompt) {
            NamePromptView(accent: VibeTheme.vibeWords,
                           symbol: "textformat.abc",
                           message: "So everyone knows who got there first.",
                           identifierPrefix: "words") { chosen in
                showingNamePrompt = false
                if let chosen { model.submitName(chosen) }
                // Whatever they were trying to do when they were interrupted.
                let action = pendingAction
                pendingAction = nil
                action?()
            }
        }
        .task { AppAnalytics.screen(.words) }
        .sheet(isPresented: $showingSettings) {
            VibeWordsSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear { model.endSession() }
        .onChange(of: model.answer) { _, _ in
            roundToken += 1
            // A new word *is* a new round, solo and shared alike: the answer
            // only changes when one begins, and a snapshot arriving with the
            // same word leaves it untouched.
            AppAnalytics.gameStart(.words, mode: model.isShared ? .shared : .solo)
        }
        .onChange(of: model.isRoundOver) { _, isOver in
            guard isOver else { return }
            AppAnalytics.gameFinish(.words,
                                    mode: model.isShared ? .shared : .solo,
                                    outcome: model.won ? .won : .lost,
                                    score: model.guesses.count)
        }
        .onChange(of: model.countdown) { _, newValue in
            // The board is cleared when the countdown ends, so re-arm the flip.
            if newValue == nil { roundToken += 1 }
        }
    }

    // MARK: - Name

    // MARK: - Lobby

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 18) {
                header(title: "WORD VIBE", subtitle: "Five letters. Six tries. First to solve wins.")

                if let warning = model.backendUnavailableMessage {
                    banner(warning, symbol: "wifi.slash", tint: VibeTheme.warn)
                }

                actionCard(
                    title: "Play on this device",
                    subtitle: "A fresh word, no connection needed",
                    symbol: "ipad.and.iphone",
                    identifier: "words.playSolo"
                ) {
                    model.playSolo()
                }

                actionCard(
                    title: "Start a game with friends",
                    subtitle: "You get a code to share",
                    symbol: "person.2.fill",
                    identifier: "words.createGame",
                    isEnabled: model.backendUnavailableMessage == nil
                ) {
                    requireName { Task { await model.createSharedGame() } }
                }

                joinCard

                Text("Everyone plays the same word on their own device. First to guess it wins.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                InstructionsCard(accent: VibeTheme.vibeWords,
                                 identifier: "words.instructions.open") {
                    GameInstructionsPage(instructions: .words)
                }
            }
            .padding(20)
        }
    }

    private func actionCard(title: String,
                            subtitle: String,
                            symbol: String,
                            identifier: String,
                            isEnabled: Bool = true,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(VibeTheme.primaryText)
                    .frame(width: 52, height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.vibeWords)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VibeTheme.tertiaryText)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(VibeTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
            }
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("JOIN WITH A CODE")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .kerning(1.5)
                .foregroundStyle(VibeTheme.tertiaryText)

            HStack(spacing: 10) {
                TextField("cars feed", text: $joinCode)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(VibeTheme.primaryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.surfaceStrong)
                    }
                    .submitLabel(.go)
                    .onSubmit { join() }
                    .accessibilityIdentifier("words.joinField")

                Button("Join") { join() }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                    .padding(.horizontal, 22)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.vibeWords)
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty
                              || model.backendUnavailableMessage != nil)
                    .accessibilityIdentifier("words.joinButton")
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
    }

    private func join() {
        let code = joinCode
        requireName { Task { await model.joinSharedGame(code: code) } }
    }

    /// Runs a shared-game action, collecting a name first if there is not one.
    ///
    /// Solo play never comes through here: a name is only wanted by the games
    /// where somebody else has to read it.
    private func requireName(_ action: @escaping () -> Void) {
        guard model.hasName else {
            pendingAction = action
            showingNamePrompt = true
            return
        }
        action()
    }

    // MARK: - Game

    private var game: some View {
        VStack(spacing: 0) {
            header(title: "WORD VIBE", subtitle: gameSubtitle)
            statusArea
            VibeWordsBoardView(guesses: model.guesses,
                               currentGuess: model.currentGuess,
                               answer: model.answer,
                               isRoundOver: model.isRoundOver,
                               rejectionCount: model.rejectionCount,
                               roundToken: roundToken)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            VibeWordsKeyboardView(feedbackFor: model.keyboardFeedback(for:),
                                  onKey: model.press)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
                .disabled(!model.canPlay)
                .opacity(model.canPlay ? 1 : 0.55)
        }
    }

    private var gameSubtitle: String {
        if model.isShared {
            let count = model.snapshot.players.count
            return "\(count) \(count == 1 ? "player" : "players") · code \(GameCode.display(model.sharedGameID ?? ""))"
        }
        return "Solo game"
    }

    @ViewBuilder
    private var statusArea: some View {
        if let countdown = model.countdown {
            VStack(spacing: 2) {
                Text("Next word in")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                Text("\(countdown)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VibeTheme.primaryText)
            }
            .padding(.vertical, 6)
            .accessibilityIdentifier("words.countdown")
        } else if model.isWaitingForHost {
            waitingPanel
        } else if let winner = model.snapshot.winner, winner.name != model.playerName {
            banner("\(winner.name) solved it first!", symbol: "trophy.fill", tint: VibeTheme.tilePresent)
        } else if let message = model.message {
            banner(message, symbol: model.won ? "checkmark.circle.fill" : "info.circle.fill",
                   tint: model.won ? VibeTheme.tileCorrect : VibeTheme.warn)
        }
    }

    private var waitingPanel: some View {
        VStack(spacing: 10) {
            Text("CODE \(GameCode.display(model.sharedGameID ?? ""))")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .kerning(2)
                .foregroundStyle(VibeTheme.primaryText)
                .accessibilityIdentifier("words.gameCode")

            Text(model.isHost
                 ? "Start when everyone has joined."
                 : "Waiting for \(model.snapshot.creator ?? "the host") to start…")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
                .multilineTextAlignment(.center)

            if model.isHost {
                Button("Start game") {
                    Task { await model.startSharedGame() }
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .padding(.horizontal, 26)
                .frame(height: 46)
                .background {
                    Capsule().fill(VibeTheme.vibeWords)
                }
                .accessibilityIdentifier("words.startShared")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        // Scoped so this identifier does not propagate onto the child labels.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("words.waiting")
    }

    // MARK: - Shared pieces

    private func header(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Button {
                if model.session == .lobby { dismiss() } else { model.leaveGame() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(VibeIconButtonStyle())
            .accessibilityLabel(model.session == .lobby ? "Back to games" : "Leave game")
            .accessibilityIdentifier("words.back")

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .kerning(3.5)
                    .foregroundStyle(VibeTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                SupportButton(game: .words)

                GameSettingsButton(prefix: "words") { showingSettings = true }

                if model.isRoundOver {
                    Button("Play again") {
                        Task { await model.playAgain() }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background { Capsule().fill(VibeTheme.vibeWords) }
                    .accessibilityIdentifier("words.playAgain")
                } else if model.isShared {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(VibeIconButtonStyle())
                    .accessibilityLabel("Share game code")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private var shareText: String {
        let code = model.sharedGameID ?? ""
        return "Join my Word Vibe game — open the app and enter code \(GameCode.display(code))"
    }

    private func banner(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(VibeTheme.primaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background { Capsule().fill(tint.opacity(0.85)) }
        .padding(.horizontal, 20)
        // Without this the label is inherited from the SF Symbol ("Info").
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier("words.status")
    }
}
