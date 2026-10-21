import SwiftUI

/// Number Vibe: build the grid, solo or racing everyone else.
struct VibeSudokuView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VibeSudokuModel()
    @State private var joinCode = ""
    @State private var showingNamePrompt = false
    @State private var isShowingSettings = false
    /// Held while a name is collected, so the tap that needed it still happens.
    @State private var pendingAction: (() -> Void)?

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
            NamePromptView(accent: VibeTheme.vibeSudoku,
                           symbol: "square.grid.3x3.fill",
                           message: "So everyone can see who finished first.",
                           identifierPrefix: "sudoku") { chosen in
                showingNamePrompt = false
                if let chosen { model.submitName(chosen) }
                // Whatever they were trying to do when they were interrupted.
                let action = pendingAction
                pendingAction = nil
                action?()
            }
        }
        .task { AppAnalytics.screen(.sudoku) }
        .sheet(isPresented: $isShowingSettings) {
            VibeSudokuSettingsView(model: model)
                // One setting fits the medium sheet; the tall one is there for
                // small phones and long explanations.
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear { model.endSession() }
        // The puzzle's seed *is* the round. A solo game, a shared game starting
        // and a rematch all arrive here as a new seed, so one hook covers them.
        .onChange(of: model.puzzle?.seed) { _, seed in
            guard seed != nil else { return }
            AppAnalytics.gameStart(.sudoku,
                                   mode: model.isShared ? .shared : .solo,
                                   grade: model.difficulty.rawValue)
        }
        // The finish this device reports is its own board being done. Somebody
        // else getting there first is not the end of this player's round, and
        // telling the story that way is what made a late arrival look like a
        // loss they could do nothing about.
        .onChange(of: model.isRoundOver) { _, isOver in
            guard isOver else { return }
            AppAnalytics.gameFinish(.sudoku,
                                    mode: model.isShared ? .shared : .solo,
                                    outcome: .won,
                                    seconds: Int(model.elapsed))
        }
    }

    // MARK: - Name

    // MARK: - Lobby

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 18) {
                header(title: "NUMBER VIBE",
                       subtitle: "Fill the grid. First to finish wins.")

                if let warning = model.backendUnavailableMessage {
                    banner(warning, symbol: "wifi.slash", tint: VibeTheme.warn)
                }

                difficultyCard
                soloCard
                sharedCard
                joinCard

                InstructionsCard(accent: VibeTheme.vibeSudoku,
                                 identifier: "sudoku.instructions.open") {
                    GameInstructionsPage(instructions: .sudoku)
                }
            }
            .padding(20)
        }
    }

    private var difficultyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DIFFICULTY")
                Spacer()
                Text("Solo and hosted games")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
            }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .kerning(1.5)
                .foregroundStyle(VibeTheme.tertiaryText)

            Picker("Difficulty", selection: $model.difficulty) {
                ForEach(SudokuDifficulty.allCases) { difficulty in
                    Text(difficulty.title).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("sudoku.difficulty")

            Text(model.difficulty.blurb)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
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

    private var soloCard: some View {
        actionCard(title: "Play on this device",
                   subtitle: "\(model.difficulty.title) puzzle, no connection needed",
                   symbol: "ipad.and.iphone",
                   identifier: "sudoku.playSolo") {
            model.playSolo()
        }
    }

    private var sharedCard: some View {
        actionCard(title: "Race your friends",
                   subtitle: "You pick the board, everyone races it",
                   symbol: "person.2.fill",
                   identifier: "sudoku.createGame",
                   isEnabled: model.backendUnavailableMessage == nil) {
            requireName { Task { await model.createSharedGame() } }
        }
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
                    .accessibilityIdentifier("sudoku.joinField")

                Button("Join") { join() }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                    .padding(.horizontal, 22)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.vibeSudoku)
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty
                              || model.backendUnavailableMessage != nil)
                    .accessibilityIdentifier("sudoku.joinButton")
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
                            .fill(VibeTheme.vibeSudoku)
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

    // MARK: - Game

    private var game: some View {
        VStack(spacing: 0) {
            header(title: "NUMBER VIBE", subtitle: gameSubtitle)
            statusArea

            if model.isRoundOver {
                roundOverPanel
                    .padding(.bottom, 8)
            }

            if let puzzle = model.puzzle {
                SudokuBoardView(puzzle: puzzle,
                                values: model.values,
                                notes: model.notes,
                                noteLimit: model.noteLimit,
                                selectedCell: model.selectedCell,
                                conflictingCells: model.conflictingCells,
                                onSelect: model.select)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                    // Sit the grid directly above the keypad: the two are used
                    // together, so keep them within one thumb's travel.
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }

            SudokuKeypadView(isNoteMode: model.isNoteMode,
                             onDigit: model.enter,
                             onErase: model.erase,
                             onToggleNotes: { model.isNoteMode.toggle() })
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .disabled(!model.canPlay)
                .opacity(model.canPlay ? 1 : 0.5)
        }
    }

    private var gameSubtitle: String {
        var parts: [String] = []
        if let puzzle = model.puzzle {
            parts.append(model.isShared ? puzzle.difficulty.title : "Solo · \(puzzle.difficulty.title)")
        }
        parts.append(model.formattedElapsed)
        parts.append("\(model.filledCount)/81")
        if model.isShared, let id = model.sharedGameID {
            parts.append("code \(GameCode.display(id))")
        }
        return parts.joined(separator: " · ")
    }

    /// The end of the board, in the suite's one treatment for it.
    ///
    /// The next board's difficulty is chosen here, where the player is about to
    /// start it, rather than only in the lobby — having to leave the screen to
    /// change it is how that setting went unused. A shared board is the host's
    /// choice, so the picker is solo only.
    private var roundOverPanel: some View {
        RoundOverPanel(
            title: "Solved!",
            detail: roundOverDetail,
            accent: AnyShapeStyle(VibeTheme.vibeSudoku),
            primaryIdentifier: "sudoku.playAgain",
            action: { Task { await model.playAgain() } }
        ) {
            if !model.isShared {
                nextBoardDifficulty
            }
        }
    }

    /// What the panel says under "Solved!".
    ///
    /// In a room the first grid finished is the win, so somebody finishing later
    /// is told who was quicker as well as what their own board took — the same
    /// two lines Word Vibe gives.
    private var roundOverDetail: String {
        if model.someoneElseWon {
            return "\(model.snapshot.winner?.name ?? "Somebody") got there first, mind. The next board is a new one."
        }
        return "\(model.filledCount) of 81 · \(model.formattedElapsed)"
    }

    private var nextBoardDifficulty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next board")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(VibeTheme.tertiaryText)

            Picker("Difficulty for the next board", selection: $model.difficulty) {
                ForEach(SudokuDifficulty.allCases) { difficulty in
                    Text(difficulty.title).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("sudoku.roundOver.difficulty")
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if let countdown = model.countdown {
            VStack(spacing: 2) {
                Text("Next puzzle in")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                Text("\(countdown)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VibeTheme.primaryText)
            }
            .padding(.vertical, 6)
            .accessibilityIdentifier("sudoku.countdown")
        } else if let notice = model.noteNotice {
            banner(notice, symbol: "pencil", tint: VibeTheme.tertiaryText)
        } else if model.isWaitingForHost {
            waitingPanel
        } else if model.someoneElseWon, !model.solved {
            // Said the moment it happens, and kept on screen while this player
            // finishes: the grid is still theirs to complete, so the notice is
            // news rather than the end of the round.
            banner("\(model.snapshot.winner?.name ?? "Somebody") solved it first — finish yours if you like.",
                   symbol: "trophy.fill",
                   tint: VibeTheme.tilePresent)
                .accessibilityIdentifier("sudoku.winner")
        } else if let error = model.errorMessage {
            // The solved lines moved into the panel. What is left here is what
            // the panel cannot say — a restart that would not start.
            banner(error, symbol: "exclamationmark.triangle.fill", tint: VibeTheme.warn)
        }
    }

    private var waitingPanel: some View {
        VStack(spacing: 10) {
            GameCodeBadge(code: model.sharedGameID ?? "",
                          size: .inline,
                          identifier: "sudoku.gameCode",
                          hint: model.isHost
                              ? "Read this out — everyone joins with it."
                              : "Everyone else: Number Vibe → Join with a code")

            Text(model.isHost
                 ? "Start when everyone has joined. Everyone races the same \(model.snapshot.difficulty.title) board."
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
                .background { Capsule().fill(VibeTheme.vibeSudoku) }
                .accessibilityIdentifier("sudoku.startShared")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sudoku.waiting")
    }

    // MARK: - Shared pieces

    private func header(title: String, subtitle: String) -> some View {
        GameHeaderBar(title: title,
                      subtitle: subtitle,
                      backIdentifier: "sudoku.back",
                      backLabel: model.session == .lobby ? "Back to games" : "Leave game",
                      onBack: {
                          if model.session == .lobby { dismiss() } else { model.leaveGame() }
                      }) {
            SupportButton(game: .sudoku)

            // The settings button the other games have, in the same place:
            // notes per square is a setting, and settings live behind it.
            GameSettingsButton(prefix: "sudoku") { isShowingSettings = true }

            // The way to start another board used to live here, in a pill in
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
        GameInvite.text(game: .sudoku, code: model.sharedGameID ?? "")
    }

    private func banner(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(2)
        }
        .foregroundStyle(VibeTheme.primaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background { Capsule().fill(tint.opacity(0.85)) }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier("sudoku.status")
    }
}
