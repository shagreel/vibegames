import SwiftUI

/// Vibe Ten: pair the digits, clear the board, solo or as a room.
struct VibeTenView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VibeTenModel()
    /// A solo game already on this device, waiting to be continued or replaced.
    @State private var pendingResume: SoloProgress?

    @State private var joinCode = ""
    @State private var showingSettings = false
    @State private var showingNamePrompt = false
    @State private var pendingNameAction: (() -> Void)?

    var body: some View {
        Group {
            if model.session == .lobby {
                lobby
            } else if model.isWaitingForHost {
                waiting
            } else {
                game
            }
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) {
            VibeTenSettingsView(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNamePrompt) {
            NamePromptView(accent: VibeTheme.vibeTen,
                           symbol: "10.circle.fill",
                           message: "So the others in the room know whose score is whose.",
                           identifierPrefix: "ten") { chosen in
                showingNamePrompt = false
                if let chosen { model.submitName(chosen) }
                pendingNameAction?()
                pendingNameAction = nil
            }
        }
        .task { AppAnalytics.screen("ten") }
        .onChange(of: model.boardToken) { _, _ in
            guard model.board != nil else { return }
            AppAnalytics.gameStart(.ten, mode: model.isShared ? .shared : .solo)
        }
        .onChange(of: model.finished) { _, isOver in
            guard isOver else { return }
            AppAnalytics.gameFinish(.ten,
                                    mode: model.isShared ? .shared : .solo,
                                    outcome: model.cleared ? .won : .completed,
                                    seconds: model.lastRoundSeconds)
        }
        .onDisappear { model.endSession() }
        .soloResumePrompt($pendingResume,
                          onContinue: { model.resumeSolo() },
                          onNewGame: { model.playSolo() })
    }

    // MARK: - Header

    private func header(title: String, subtitle: String) -> some View {
        GameHeaderBar(title: title,
                      subtitle: subtitle,
                      backIdentifier: "ten.back",
                      backLabel: model.session == .lobby ? "Back to games" : "Leave game",
                      onBack: {
                          if model.session == .lobby { dismiss() } else { model.leaveGame() }
                      }) {
            SupportButton(game: .ten)
            GameSettingsButton(prefix: "ten") { showingSettings = true }

            if model.isShared {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(VibeIconButtonStyle())
                .accessibilityLabel("Share game code")
                .accessibilityIdentifier("ten.share")
            }
        }
    }

    private var shareText: String {
        GameInvite.text(game: .ten, code: model.sharedGameID ?? "")
    }

    // MARK: - Lobby

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 18) {
                header(title: "VIBE TEN",
                       subtitle: "Pair the digits, drop the ones above, clear the board.")

                if let warning = model.backendUnavailableMessage {
                    banner(warning, symbol: "wifi.slash", tint: VibeTheme.warn)
                }

                actionCard(title: "Play on this device",
                           subtitle: "A board of your own, no connection needed",
                           symbol: "ipad.and.iphone",
                           identifier: "ten.playSolo") {
                    if let saved = SoloProgressStore.saved(game: VibeTenModel.progressGame) {
                        pendingResume = saved
                    } else {
                        model.playSolo()
                    }
                }

                actionCard(title: "Race your friends",
                           subtitle: "The same board for everyone. Most pairs wins.",
                           symbol: "person.2.fill",
                           identifier: "ten.createGame",
                           isEnabled: model.backendUnavailableMessage == nil) {
                    requireName { Task { await model.createSharedGame() } }
                }

                joinCard

                InstructionsCard(accent: VibeTheme.vibeTen,
                                 identifier: "ten.instructions.open") {
                    GameInstructionsPage(instructions: .ten)
                }
            }
            .padding(20)
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
                    .accessibilityIdentifier("ten.joinField")

                Button("Join") { join() }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.vibeTen)
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty
                              || model.backendUnavailableMessage != nil)
                    .accessibilityIdentifier("ten.joinButton")
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Waiting room

    private var waiting: some View {
        VStack(spacing: 14) {
            header(title: "VIBE TEN", subtitle: "Waiting to start")

            GameCodeBadge(code: model.sharedGameID ?? "",
                          size: .inline,
                          identifier: "ten.gameCode",
                          hint: model.isHost
                              ? "Read this out — everyone joins with it."
                              : "Everyone else: Vibe Ten → Join with a code")

            Text(model.isHost
                 ? "Start when everyone has joined. Everyone plays the same board."
                 : "Waiting for \(model.snapshot.creator ?? "the host") to start…")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
                .multilineTextAlignment(.center)

            if model.isHost {
                Button {
                    Task { await model.startSharedGame() }
                } label: {
                    Text("Start")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(VibeTheme.vibeTen)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ten.startShared")
                .padding(.horizontal, 20)
            }

            roster
            Spacer()
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IN THE ROOM (\(model.snapshot.playerCount))")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(VibeTheme.tertiaryText)

            ForEach(model.snapshot.players.keys.sorted(), id: \.self) { id in
                Text(model.snapshot.players[id] ?? "Someone")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    // MARK: - Playing

    private var game: some View {
        VStack(spacing: 8) {
            header(title: "VIBE TEN", subtitle: model.subtitle)

            if model.finished {
                roundOver
            }

            if model.isShared, !model.finished {
                standingsBar
            }

            boardView

            if let message = model.message, model.canPlay {
                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.secondaryText)
            }
        }
        // The board takes whatever the header and the panel leave, so the grid
        // is as big as the phone allows.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Dealing yourself another row, on the empty row it drops into.
    ///
    /// The bottom row of the grid is dead space whenever it is empty, so the
    /// button goes there rather than in a strip of its own: the board hangs from
    /// the top, and the offer appears on the edge the new rows extend.
    private func addRowButton(width: CGFloat, height: CGFloat) -> some View {
        Button {
            Haptics.shared.tap()
            model.addRows()
        } label: {
            Label(model.rowsPerAdd == 1 ? "Add a row" : "Add \(model.rowsPerAdd) rows",
                  systemImage: "plus")
                .font(.system(size: max(10, height * 0.34), weight: .bold, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .frame(width: width, height: height)
                .background {
                    RoundedRectangle(cornerRadius: max(4, height * 0.22), style: .continuous)
                        .fill(VibeTheme.vibeTenBorder.opacity(0.22))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: max(4, height * 0.22), style: .continuous)
                        .strokeBorder(VibeTheme.vibeTenBorder.opacity(0.7),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.rowsPerAdd == 1
                            ? "Add a row at the bottom"
                            : "Add \(model.rowsPerAdd) rows at the bottom")
        .accessibilityIdentifier("ten.addRow")
    }

    /// A live score line for a room: everyone's pairs, in order.
    private var standingsBar: some View {
        HStack(spacing: 12) {
            ForEach(model.standings.prefix(4)) { standing in
                HStack(spacing: 4) {
                    Text(standing.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                        .lineLimit(1)
                    Text("\(standing.score)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(standing.finishedAt == nil ? VibeTheme.primaryText
                                                                    : VibeTheme.tertiaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var boardView: some View {
        GeometryReader { geo in
            // The board's own shape, so a six-column game draws six columns and
            // the digits grow into the space that leaves.
            let columns = model.board?.columns ?? VibeTenBoard.defaultColumns
            let rows = model.board?.rows ?? VibeTenBoard.defaultRows
            let gap: CGFloat = 2
            let width = (geo.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let height = (geo.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            let cell = min(width, height)
            let gridWidth = cell * CGFloat(columns) + gap * CGFloat(columns - 1)
            let gridHeight = cell * CGFloat(rows) + gap * CGFloat(rows - 1)

            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<columns, id: \.self) { column in
                    VStack(spacing: gap) {
                        // Row 0 is the top row: the board hangs from the top, so
                        // the rows below it rise into a gap.
                        ForEach(0..<rows, id: \.self) { row in
                            cellView(column: column, row: row, size: cell)
                        }
                    }
                }
            }
            .frame(width: gridWidth, height: gridHeight)
            .overlay(alignment: .bottom) {
                if model.canAddRow {
                    addRowButton(width: gridWidth, height: cell)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        // A container, so the grid can be found by name while each digit keeps
        // its own element: an identifier on a plain container is inherited by
        // every child, which hid all 162 of them.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ten.board")
    }

    private func cellView(column: Int, row: Int, size: CGFloat) -> some View {
        let position = VibeTenBoard.Position(column: column, row: row)
        let value = model.board?.value(at: position)
        let isSelected = model.selected == position

        let dimmed = model.board?.isDimmed(at: position) ?? true

        return Group {
            if let value, !dimmed {
                // A button, not a tap on a label: a digit is the one thing you
                // press in this game, and VoiceOver should say so.
                Button {
                    model.tap(position)
                } label: {
                    Text("\(value)")
                        .font(.system(size: size * 0.62, weight: .black, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                        .frame(width: size, height: size)
                        .background {
                            RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous)
                                .fill(VibeTheme.surfaceStrong)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous)
                                .stroke(isSelected ? VibeTheme.vibeTenBorder : VibeTheme.hairline,
                                        lineWidth: isSelected ? 2.5 : 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Column \(column + 1) row \(row + 1): \(value)")
                .accessibilityIdentifier("ten.cell.\(column).\(row)")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            } else if let value {
                // Taken in dim mode: still there to read, clearly out of play —
                // no fill and a dotted edge, so it cannot be mistaken for a
                // square that is waiting to be pressed.
                Text("\(value)")
                    .font(.system(size: size * 0.62, weight: .black, design: .rounded))
                    .foregroundStyle(VibeTheme.dimmedText)
                    .frame(width: size, height: size)
                    .overlay {
                        RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous)
                            .strokeBorder(VibeTheme.hairline.opacity(0.45),
                                          style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Column \(column + 1) row \(row + 1): \(value), taken")
                    .accessibilityIdentifier("ten.cell.\(column).\(row)")
            } else {
                Color.clear
                    .frame(width: size, height: size)
            }
        }
    }

    // MARK: - Round over

    private var roundOver: some View {
        RoundOverPanel(title: model.cleared ? "Cleared it!" : "No moves left",
                       detail: detail,
                       accent: AnyShapeStyle(VibeTheme.vibeTen),
                       primaryIdentifier: "ten.playAgain",
                       action: { Task { await model.playAgain() } }) {
            if model.isShared {
                standingsList
            }
        }
        .padding(.horizontal, 16)
    }

    private var detail: String {
        let pairs = "\(model.score) \(model.score == 1 ? "pair" : "pairs")"
        if model.isShared {
            if let best = model.winners.first {
                return "\(best.name) wins with \(best.score)."
            }
            return "\(pairs) taken. Waiting for the rest of the room."
        }
        return model.cleared
            ? "Every digit gone. \(pairs) taken."
            : "\(pairs) taken, and nothing left that pairs."
    }

    private var standingsList: some View {
        VStack(spacing: 6) {
            ForEach(Array(model.standings.enumerated()), id: \.element.id) { index, standing in
                HStack {
                    Text("\(index + 1). \(standing.name)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    Spacer()
                    Text("\(standing.score)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    if standing.finishedAt == nil {
                        Text("playing")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(VibeTheme.tertiaryText)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func join() {
        let code = joinCode
        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        requireName { Task { await model.joinSharedGame(code: code) } }
    }

    private func requireName(_ action: @escaping () -> Void) {
        guard model.hasName else {
            pendingNameAction = action
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
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(VibeTheme.vibeTen)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(VibeTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityIdentifier(identifier)
    }

    private func banner(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(VibeTheme.primaryText)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.16))
        }
    }
}

/// The player's name, the appearance, and how a matched pair is taken.
struct VibeTenSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: VibeTenModel

    /// The sheet reads the rules in play — the room's in a room, this device's
    /// solo — and writes the local choice, which is only possible before the
    /// game begins.
    private var modeBinding: Binding<VibeTenMode> {
        Binding(get: { model.effectiveMode }, set: { model.mode = $0 })
    }

    private var wrapBinding: Binding<Bool> {
        Binding(get: { model.effectiveWrapRows }, set: { model.wrapRows = $0 })
    }

    private var difficultyBinding: Binding<VibeTenDifficulty> {
        Binding(get: { model.boardDifficulty }, set: { model.difficulty = $0 })
    }

    private var columnsBinding: Binding<Int> {
        Binding(get: { model.boardShape.columns }, set: { model.columns = $0 })
    }

    private var rowsBinding: Binding<Int> {
        Binding(get: { model.boardShape.rows }, set: { model.rows = $0 })
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("When a pair is matched")

            Picker("When a pair is matched", selection: modeBinding) {
                ForEach(VibeTenMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!model.canChoosePairMode)
            .accessibilityIdentifier("tenSettings.mode")

            Text(model.effectiveMode.blurb)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(model.canChoosePairMode
                 ? "Choose it before you start. Pairs taken in Dim mode stay on the board."
                 : model.isShared
                    ? "In a room the host's rules are the game's rules. This room is playing the way it was created."
                    : "This game is using the setting it started with. Leave it to choose again.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            SettingsCard {
                SettingsRow(symbol: "arrow.turn.down.right",
                            title: "Rows join end to end",
                            subtitle: "The last square of a row is next to the first of the row below") {
                    Toggle("", isOn: wrapBinding)
                        .labelsHidden()
                        .tint(VibeTheme.vibeTenBorder)
                        .disabled(!model.canChoosePairMode)
                        .accessibilityIdentifier("tenSettings.wrapRows")
                }
            }
        }
    }

    private var addRowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("Adding rows")

            SettingsCard {
                SettingsRow(symbol: "plus.rectangle.on.rectangle",
                            title: "Offer a new row",
                            subtitle: "Solo games only") {
                    Toggle("", isOn: $model.addRowEnabled)
                        .labelsHidden()
                        .tint(VibeTheme.vibeTenBorder)
                        .accessibilityIdentifier("tenSettings.addRow")
                }
            }

            Text("When the bottom row of the grid is empty, a button appears there: tap it to hang fresh rows underneath, and the board grows down into the space.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shapeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("The board")

            Text("Difficulty")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)

            Picker("Difficulty", selection: difficultyBinding) {
                ForEach(VibeTenDifficulty.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!model.canChooseBoardShape)
            .accessibilityIdentifier("tenSettings.difficulty")

            Text(model.boardDifficulty.blurb)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Every level can be cleared — the harder ones just hide more pairs behind other digits. In a room everybody plays the level the host dealt.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Columns")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)

            Picker("Columns", selection: columnsBinding) {
                ForEach(VibeTenBoard.columnOptions, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!model.canChooseBoardShape)
            .accessibilityIdentifier("tenSettings.columns")

            Text("Rows")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)

            Picker("Rows", selection: rowsBinding) {
                ForEach(VibeTenBoard.rowOptions, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!model.canChooseBoardShape)
            .accessibilityIdentifier("tenSettings.rows")

            Text(model.canChooseBoardShape
                 ? "Fewer columns and rows means bigger digits. Choose it before you start; in a room everybody plays the shape the host dealt."
                 : "The board is set for this game. Leave it, and choose a size on the start screen before the next one.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 2)

            Text("Start with")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)

            Picker("Start with", selection: $model.startFill) {
                ForEach(VibeTenStartFill.allCases) { fill in
                    Text(fill.title).tag(fill)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!model.canChooseRowSupply)
            .accessibilityIdentifier("tenSettings.startFill")

            Text(model.canChooseRowSupply
                 ? "A third of the rows to start with leaves room for the new rows to fill."
                 : "Solo games with the new-row offer turned on can start with a third of the board.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Rows per press")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
                .padding(.top, 4)

            Picker("Rows per press", selection: $model.rowsPerAdd) {
                ForEach(VibeTenBoard.rowsPerAddOptions, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!model.canChooseRowSupply)
            .accessibilityIdentifier("tenSettings.rowsPerAdd")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    shapeSection
                    modeSection
                    addRowSection
                    GameSettingsSections()
                }
                .padding(20)
            }
            .vibeCanvas()
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("tenSettings.done")
                }
            }
            .toolbarBackground(VibeTheme.canvasTop, for: .navigationBar)
        }
        .followingAppearance()
    }
}
