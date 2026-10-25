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
    /// A solo round already on this device, waiting to be continued or replaced.
    @State private var pendingResume: SoloProgress?

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
        .soloResumePrompt($pendingResume,
                          onContinue: { model.resumeSolo() },
                          onNewGame: { model.playSolo() })
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
                    if let saved = SoloProgressStore.saved(game: VibeWordsModel.progressGame) {
                        pendingResume = saved
                    } else {
                        model.playSolo()
                    }
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
            if model.isRoundOver {
                roundOverPanel
                    .padding(.bottom, 8)
            }
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
                // The keyboard belongs to a round: a new word rebuilds it, so
                // last round's tint cannot outlive the board it described.
                .id(roundToken)
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

    /// The end of the round, in the suite's one treatment for it.
    ///
    /// The `words.playAgain` identifier lives here rather than in the header:
    /// that is what the UI tests tap, and the button it names has moved.
    private var roundOverPanel: some View {
        RoundOverPanel(title: roundOverTitle,
                       detail: roundOverDetail,
                       accent: AnyShapeStyle(VibeTheme.vibeWords),
                       primaryIdentifier: "words.playAgain") {
            Task { await model.playAgain() }
        }
    }

    /// Who won the round, in the panel's own words.
    private var roundOverTitle: String {
        if model.won { return "Solved!" }
        if let winner = model.snapshot.winner, winner.name != model.playerName {
            return "\(winner.name) solved it first"
        }
        return "The word was \(model.answer)"
    }

    private var roundOverDetail: String {
        if model.won, model.someoneElseWon {
            return "\(model.snapshot.winner?.name ?? "Somebody") got there first, mind. The next one is a new word."
        }
        if model.won { return "In \(model.guesses.count) guesses" }
        return "The next one is a new word."
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
        } else if model.someoneElseWon {
            // Said as soon as it happens, and kept on screen while this player
            // finishes their own word. Nothing more is promised: the board is
            // still playable, and saying so reads like a second rule.
            banner("\(model.snapshot.winner?.name ?? "Somebody") solved it first.",
                   symbol: "trophy.fill",
                   tint: VibeTheme.tilePresent)
                .accessibilityIdentifier("words.winner")
        } else if let message = model.message {
            // Refusals and errors. The won/lost copy now belongs to the panel,
            // so it never reaches this line.
            banner(message, symbol: "info.circle.fill", tint: VibeTheme.warn)
        }
    }

    private var waitingPanel: some View {
        VStack(spacing: 10) {
            GameCodeBadge(code: model.sharedGameID ?? "",
                          size: .inline,
                          identifier: "words.gameCode",
                          hint: model.isHost
                              ? "Read this out — everyone joins with it."
                              : "Everyone else: Word Vibe → Join with a code")

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
        GameHeaderBar(title: title,
                      subtitle: subtitle,
                      backIdentifier: "words.back",
                      backLabel: model.session == .lobby ? "Back to games" : "Leave game",
                      onBack: {
                          if model.session == .lobby { dismiss() } else { model.leaveGame() }
                      }) {
            SupportButton(game: .words)

            GameSettingsButton(prefix: "words") { showingSettings = true }

            // The way to start another round used to live here, in a pill in
            // the corner. It is the panel's button now.
            if model.isShared {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(VibeIconButtonStyle())
                .accessibilityLabel("Share game code")
            }
        }
    }

    private var shareText: String {
        GameInvite.text(game: .words, code: model.sharedGameID ?? "")
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
