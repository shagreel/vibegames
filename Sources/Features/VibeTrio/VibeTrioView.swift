import SwiftUI

/// Vibe Pairings: find three cards where every feature is all-same or all-different.
struct VibeTrioView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VibeTrioModel()
    @State private var joinCode = ""
    @State private var showingNamePrompt = false
    @State private var showingSettings = false
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
            NamePromptView(accent: VibeTheme.vibeTrio,
                           symbol: "square.on.square.dashed",
                           message: "So everyone knows who spotted it first.",
                           identifierPrefix: "trio") { chosen in
                showingNamePrompt = false
                if let chosen { model.submitName(chosen) }
                // Whatever they were trying to do when they were interrupted.
                let action = pendingAction
                pendingAction = nil
                action?()
            }
        }
        .task { AppAnalytics.screen(.trio) }
        .sheet(isPresented: $showingSettings) {
            VibeTrioSettingsView(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear { model.endSession() }
        // Trio ends when the deck is spent, which is nobody's win in particular
        // — the score is the result, so that is what gets reported. Observed
        // rather than logged where the table is rebuilt, because the last take
        // may well have been somebody else's and arrived over the wire.
        .onChange(of: model.isFinished) { _, finished in
            guard finished else { return }
            AppAnalytics.gameFinish(.trio,
                                    mode: model.isShared ? .shared : .solo,
                                    outcome: .completed,
                                    score: model.myScore,
                                    seconds: Int(model.elapsed))
        }
    }

    // MARK: - Name

    // MARK: - Lobby

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 18) {
                header(title: "VIBE PAIRINGS",
                       subtitle: "Three cards. Every feature same or different.")

                if let warning = model.backendUnavailableMessage {
                    banner(warning, symbol: "wifi.slash", tint: VibeTheme.warn)
                }

                actionCard(title: "Play on this device",
                           subtitle: "Clear the whole deck at your own pace",
                           symbol: "ipad.and.iphone",
                           identifier: "trio.playSolo") {
                    model.playSolo()
                }

                actionCard(title: "Race your friends",
                           subtitle: "One table of cards. Take a good pairing before anyone else does.",
                           symbol: "person.2.fill",
                           identifier: "trio.createGame",
                           isEnabled: model.backendUnavailableMessage == nil) {
                    requireName { Task { await model.createSharedGame() } }
                }

                joinCard

                instructionsCard
            }
            .padding(20)
        }
    }

    /// Sits with the other options rather than as a block of text above them:
    /// the rule is worth reading once, and everyone who knows it already would
    /// otherwise scroll past it every time. The card itself is shared with the
    /// other four games, so they cannot drift apart.
    private var instructionsCard: some View {
        InstructionsCard(accent: VibeTheme.vibeTrio,
                         identifier: "trio.instructions.open") {
            TrioInstructionsView()
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
                    .accessibilityIdentifier("trio.joinField")

                Button("Join") { join() }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.vibeTrio)
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty
                              || model.backendUnavailableMessage != nil)
                    .accessibilityIdentifier("trio.joinButton")
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
            cardLabel(title: title, subtitle: subtitle, symbol: symbol)
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }

    /// The shared face of every option on the lobby.
    private func cardLabel(title: String, subtitle: String, symbol: String) -> some View {
        Group {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.vibeTrio)
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
        }
    }

    // MARK: - Game

    private var game: some View {
        VStack(spacing: 0) {
            header(title: "VIBE PAIRINGS", subtitle: gameSubtitle)
            statusArea
            if model.isFinished {
                roundOverPanel
            } else {
                board
                bottomBar
            }
        }
    }

    private var gameSubtitle: String {
        var parts: [String] = []
        if model.isShared {
            // The count goes to everyone, as it does in Word Vibe — knowing how
            // many people are hunting is half the tension.
            parts.append(model.playerCount == 1 ? "1 player" : "\(model.playerCount) players")
        }
        parts.append(model.myScore == 1 ? "1 good pairing" : "\(model.myScore) good pairings")
        parts.append(model.formattedElapsed)
        if model.isShared, let id = model.sharedGameID {
            parts.append("code \(GameCode.display(id))")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var board: some View {
        if let table = model.table {
            // The whole table, on screen at once, at whatever size makes that
            // true — there is nothing here to scroll. Three across is kept
            // wherever it is not actually more expensive, but on a wide screen
            // four across is what fills the space.
            //
            // A shared game deals the table from the seed the moment it arrives,
            // but everyone stays face down until the host starts — otherwise the
            // host could study the cards while the room is still filling up.
            let faceDown = model.isWaitingForHost

            GeometryReader { proxy in
                let layout = TrioBoardLayout.fitting(table.visible.count, in: proxy.size)

                VStack(spacing: TrioBoardLayout.spacing) {
                    ForEach(Array(layout.rowsOfIndices(table.visible.count).enumerated()),
                            id: \.offset) { _, row in
                        HStack(spacing: TrioBoardLayout.spacing) {
                            ForEach(row, id: \.self) { index in
                                cardButton(index: index,
                                           card: table.visible[index],
                                           width: layout.cardWidth,
                                           faceDown: faceDown)
                                    // Identity follows the *card*, not the slot.
                                    // A take replaces cards where they stand, so
                                    // without this the picture in a slot simply
                                    // became a different picture between frames —
                                    // and in a race, three cards vanishing is the
                                    // whole point going past unnoticed.
                                    .id(table.visible[index].id)
                                    .transition(
                                        .asymmetric(
                                            insertion: .scale(scale: 0.72)
                                                .combined(with: .opacity),
                                            removal: .scale(scale: 0.86)
                                                .combined(with: .opacity)
                                        )
                                    )
                            }
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                // Keyed to the cards themselves, so any change to the table —
                // this device's take or somebody else's — animates.
                //
                // Deliberately slow. At a third of a second three cards vanished
                // and three appeared faster than anybody could follow, which is
                // the whole point of the change going past unnoticed — a table
                // that has lost a trio it was watching for. A second is long
                // enough to see *which* cards went, and it is only spent when
                // the table actually changes.
                .animation(.spring(response: 1.0, dampingFraction: 0.82),
                           value: table.visible.map(\.id))
            }
            // Outside the reader, so the size being fitted is the size the cards
            // actually get.
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } else {
            Spacer()
        }
    }

    private func cardButton(index: Int,
                            card: TrioCard,
                            width: CGFloat,
                            faceDown: Bool) -> some View {
        Button {
            model.tap(index)
        } label: {
            Group {
                if faceDown {
                    TrioCardBackView()
                } else {
                    TrioCardView(card: card,
                                 isSelected: model.selected.contains(index),
                                 isRejected: model.rejected.contains(index))
                }
            }
            // The width is handed down from the layout rather than left to the
            // grid, because the point of the layout is that it already knows the
            // largest size at which all of them fit.
            .frame(width: width, height: width / TrioCardView.aspectRatio)
        }
        .buttonStyle(.plain)
        .disabled(faceDown)
        .accessibilityIdentifier("trio.card.\(index)")
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if model.hintsEnabled {
                Button {
                    model.revealHint()
                } label: {
                    Label("Hint", systemImage: "lightbulb.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(VibeTheme.surfaceStrong)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!model.canPlay)
                .accessibilityIdentifier("trio.hint")
            } else {
                // The room's own answer, said out loud: the button is missing
                // because the host turned hints off, not because it is broken.
                Text("Race — no hints")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .accessibilityIdentifier("trio.hintsOff")
            }

            Text("\(model.remainingInDeck) left in the deck")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("trio.deckCount")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .padding(.top, 2)
    }

    @ViewBuilder
    private var statusArea: some View {
        if let countdown = model.countdown {
            VStack(spacing: 2) {
                Text("Next deal in")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
                Text("\(countdown)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VibeTheme.primaryText)
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("trio.countdown")
        } else if model.isWaitingForHost {
            waitingPanel
        } else if let conflict = model.conflictNotice {
            banner(conflict, symbol: "hand.raised.fill", tint: VibeTheme.warn)
                .accessibilityIdentifier("trio.conflict")
        } else if let error = model.errorMessage {
            banner(error, symbol: "exclamationmark.triangle.fill", tint: VibeTheme.warn)
        }
    }

    /// The end of the game, in the suite's one treatment for it.
    ///
    /// The standings are this game's own addition: the panel's title says who
    /// won, and these say what each player took. The panel carries `trio.result`
    /// — it is the whole result now, not the one line of text that used to say
    /// it — and the standings keep the identifier the UI tests wait for.
    private var roundOverPanel: some View {
        RoundOverPanel(title: resultTitle,
                       detail: resultDetail,
                       accent: AnyShapeStyle(VibeTheme.vibeTrio),
                       primaryIdentifier: "trio.playAgain",
                       action: { Task { await model.playAgain() } }) {
            standings
        }
        // Grouped, not propagated: without this the identifier would be copied
        // onto every child, including the button.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trio.result")
    }

    /// The score line under the result, in the words the leaderboard used.
    private var resultDetail: String {
        if model.isShared {
            return "\(model.formattedElapsed) · \(model.playerCount == 1 ? "1 player" : "\(model.playerCount) players")"
        }
        return "\(model.myScore == 1 ? "1 good pairing" : "\(model.myScore) good pairings") in \(model.formattedElapsed)"
    }

    /// The end state: who took what, best first, ties level at the top.
    ///
    /// Only players who took something appear, because only a take carries a
    /// name — and taking two when the whole table is hunting is worth a trophy.
    private var standings: some View {
        let rows = model.standings
        let best = rows.first?.score ?? 0

        return VStack(spacing: 10) {
            if rows.isEmpty {
                Text("Nobody cleared a good pairing this time.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        standingRow(row, rank: index + 1, isLeader: row.score == best && best > 0)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(VibeTheme.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trio.leaderboard")
    }

    private var resultTitle: String {
        guard model.isShared else { return "Deck cleared" }
        let winners = model.leaders
        switch winners.count {
        case 0: return "Nobody scored"
        case 1: return winners[0].isMe ? "You win!" : "\(winners[0].name) wins"
        default: return "Tie at \(winners[0].score)"
        }
    }

    private func standingRow(_ row: TrioStanding, rank: Int, isLeader: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(VibeTheme.tertiaryText)
                .frame(width: 20, alignment: .trailing)

            Text(row.name)
                .font(.system(size: 16, weight: row.isMe ? .black : .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .lineLimit(1)

            if isLeader {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(VibeTheme.vibeTrio)
            }

            Spacer(minLength: 8)

            Text("\(row.score)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(VibeTheme.primaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(row.isMe ? VibeTheme.surfaceStrong : .clear)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trio.standing.\(rank)")
    }

    private var waitingPanel: some View {
        VStack(spacing: 10) {
            GameCodeBadge(code: model.sharedGameID ?? "",
                          size: .inline,
                          identifier: "trio.gameCode",
                          hint: model.isHost
                              ? "Read this out — everyone joins with it."
                              : "Everyone else: Vibe Pairings → Join with a code")

            Text(model.isHost
                 ? "Start when everyone has joined. Clear the deck together — first good pairing taken is yours."
                 : "Waiting for \(model.snapshot.creator ?? "the host") to start…")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
                .multilineTextAlignment(.center)

            if model.isHost {
                Button("Start game") {
                    Task { await model.startSharedGame() }
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 26)
                .frame(height: 46)
                .background { Capsule().fill(VibeTheme.vibeTrio) }
                .accessibilityIdentifier("trio.startShared")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trio.waiting")
    }

    // MARK: - Shared pieces

    private func header(title: String, subtitle: String) -> some View {
        GameHeaderBar(title: title,
                      subtitle: subtitle,
                      backIdentifier: "trio.back",
                      backLabel: model.session == .lobby ? "Back to games" : "Leave game",
                      onBack: {
                          if model.session == .lobby { dismiss() } else { model.leaveGame() }
                      }) {
            SupportButton(game: .trio)

            GameSettingsButton(prefix: "trio") { showingSettings = true }

            // The way to start another deck used to live here, in a pill in
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
        GameInvite.text(game: .trio, code: model.sharedGameID ?? "")
    }

    private func banner(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background { Capsule().fill(tint.opacity(0.85)) }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier("trio.status")
    }
}
