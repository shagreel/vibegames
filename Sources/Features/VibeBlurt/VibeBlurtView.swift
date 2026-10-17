import SwiftUI

/// Similar Vibe — the describing game.
///
/// Everyone is on their own device in one room. Two teams; one person at a time
/// is handed a word and has to get their team to say it without saying it
/// themselves. Nobody scores for guessing: the point goes to whichever team is
/// *not* holding the word when the clock stops, which is what makes the whole
/// thing a race to get rid of it.
///
/// The word itself never reaches the other phones. It is not hidden in the
/// payload — it is not in the payload at all: every device derives the same deck
/// from the room's seed, and only the describer's screen renders the current one.
struct VibeBlurtView: View {
    @StateObject private var model = VibeBlurtModel()
    @Environment(\.dismiss) private var dismiss

    @State private var joinCode = ""
    @State private var showingNamePrompt = false
    @State private var showingSettings = false
    @State private var showingCode = false
    @State private var pendingAction: (() -> Void)?

    var body: some View {
        Group {
            if !model.isShared {
                lobby
            } else if model.winner != nil {
                finished
            } else if let play = model.play {
                turn(play)
            } else {
                waitingForStart
            }
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            AppAnalytics.screen(.blurt)
            // The end of a round is announced by sound alone, so the audio stack
            // is readied when the screen opens rather than at the buzzer.
            SoundEngine.shared.warmUp()
        }
        .onDisappear { model.endSession() }
        .sheet(isPresented: $showingSettings) {
            VibeBlurtSettingsView(packs: model.snapshot.packs,
                                  isEditable: model.canChangeSettings) { packs in
                Task { await model.updateSettings(packs: packs) }
            }
        }
        .sheet(isPresented: $showingCode) {
            codeSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNamePrompt) {
            NamePromptView(accent: VibeTheme.vibeBlurt,
                           symbol: "bubble.left.and.exclamationmark.bubble.right.fill",
                           message: "So your team knows who is describing.",
                           identifierPrefix: "blurt") { chosen in
                showingNamePrompt = false
                if let chosen { model.submitName(chosen) }
                let action = pendingAction
                pendingAction = nil
                action?()
            }
        }
        // The buzz for being caught is fired by the model, not from here: see
        // `buzzWhenCaught`. It has to survive the whole screen being replaced in
        // the same update, which is what happens when a round ends.
        .onChange(of: model.play?.turn) { _, _ in
            AppAnalytics.gameStart(.blurt, mode: .shared)
        }
        .onChange(of: model.winner) { _, winner in
            guard let winner else { return }
            // A blurt game has no "won" for the describer: the score belongs to
            // the team, and either way the game reached its own end.
            AppAnalytics.gameFinish(.blurt,
                                    mode: .shared,
                                    outcome: .completed,
                                    score: model.score(of: winner))
        }
    }

    // MARK: - Lobby

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 18) {
                header(title: "SIMILAR VIBE",
                       subtitle: "Describe it. Don't say it.")

                if let warning = model.backendUnavailableMessage {
                    banner(warning, symbol: "wifi.slash", tint: VibeTheme.warn)
                }

                actionCard(title: "Start a game",
                           subtitle: "Everyone joins on their own device",
                           symbol: "person.2.fill",
                           identifier: "blurt.createGame",
                           isEnabled: model.backendUnavailableMessage == nil) {
                    requireName { Task { await model.createGame() } }
                }

                joinCard

                InstructionsCard(accent: VibeTheme.vibeBlurt,
                                 identifier: "blurt.instructions.open") {
                    GameInstructionsPage(instructions: .blurt)
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
                    .accessibilityIdentifier("blurt.joinField")

                Button("Join") { join() }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.vibeBlurt)
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty
                              || model.backendUnavailableMessage != nil)
                    .accessibilityIdentifier("blurt.joinButton")
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
        requireName { Task { await model.joinGame(code: code) } }
    }

    // MARK: - Before the start

    private var waitingForStart: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: "SIMILAR VIBE", subtitle: "Waiting to start")

                codeCard
                roster
                settingsCard

                if model.isHost {
                    Button {
                        Task { await model.startGame() }
                    } label: {
                        Text("Start")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(model.canStart
                                          ? AnyShapeStyle(VibeTheme.vibeBlurt)
                                          : AnyShapeStyle(VibeTheme.surfaceStrong))
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canStart)
                    .accessibilityIdentifier("blurt.start")

                    Text(model.startHint)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Waiting for \(model.snapshot.creator ?? "the host") to start.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    /// The code, big enough to read out across a room.
    ///
    /// Everybody joining does it by ear — nobody is going to type a code into
    /// somebody else's phone — so it is the largest thing on the screen, spaced
    /// out so eight characters cannot be misheard in a noisy kitchen, and
    /// selectable in case somebody would rather text it.
    private var codeCard: some View {
        VStack(spacing: 10) {
            GameCodeBadge(code: model.sharedGameID ?? "",
                          size: .prominent,
                          identifier: "blurt.gameCode",
                          hint: "Everyone else: Similar Vibe → Join with a code")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
    }

    /// The code on its own, for a game that has already started.
    ///
    /// It reuses `codeCard` rather than drawing the code again, so the one place
    /// that decides how a code looks stays the one place a code is drawn.
    private var codeSheet: some View {
        VStack(spacing: 18) {
            codeCard

            if let code = model.sharedGameID {
                ShareLink(item: shareText(code)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(VibeTheme.surfaceStrong)
                        }
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .vibeCanvas()
    }

    /// What the room is playing: how long a turn is and what gets described.
    /// Read-only for everybody but the host, and read-only for the host once the
    /// game is under way.
    private var settingsCard: some View {
        Button {
            guard model.canChangeSettings else { return }
            showingSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VibeTheme.vibeBlurt)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    Text(packSummary)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                }

                Spacer(minLength: 0)

                if model.canChangeSettings {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VibeTheme.tertiaryText)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(VibeTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(VibeTheme.hairline, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!model.canChangeSettings)
        .accessibilityIdentifier("blurt.settings")
    }

    private var packSummary: String {
        model.snapshot.allPacksOn
            ? "all \(BlurtPack.allCases.count) packs"
            : "\(model.snapshot.packs.count) of \(BlurtPack.allCases.count) packs"
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IN THE ROOM (\(model.snapshot.players.count))")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .kerning(1.5)
                .foregroundStyle(VibeTheme.tertiaryText)

            ForEach(model.snapshot.players.sorted(by: { $0.value < $1.value }), id: \.key) { player in
                HStack(spacing: 10) {
                    Circle()
                        .fill(player.key == model.myShortID
                              ? AnyShapeStyle(VibeTheme.vibeBlurt)
                              : AnyShapeStyle(VibeTheme.surfaceStrong))
                        .frame(width: 10, height: 10)
                    Text(player.value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    if player.key == model.myShortID {
                        Text("you")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(VibeTheme.tertiaryText)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
    }

    // MARK: - A turn

    @ViewBuilder
    private func turn(_ play: BlurtPlay) -> some View {
        VStack(spacing: 14) {
            header(title: "SIMILAR VIBE", subtitle: "First to \(BlurtRules.target)")

            scoreboard(play)

            if play.state == .ended {
                resultBanner(play)
            }

            if play.state == .running {
                clock(play)
            }

            Spacer(minLength: 0)

            if play.state == .running {
                if model.isDescriber {
                    describerCard
                } else if model.isOnBuzzTeam {
                    buzzCard(play)
                } else {
                    guessingCard
                }
            } else {
                // `.ready` and `.ended` share this screen: the result of the last
                // turn, then who is up next. One screen rather than two, because
                // the handover is the same moment either way.
                handoverCard(play)
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 18)
    }

    /// The two teams, their scores, and **who is on them**.
    ///
    /// The names matter as much as the scores: with four people passing one word
    /// around, the first thing anybody asks is which side they are on, and a
    /// scoreboard that only says "Team One: 3" does not answer it.
    private func scoreboard(_ play: BlurtPlay) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(BlurtTeam.allCases, id: \.rawValue) { team in
                let mine = model.myTeam == team
                VStack(spacing: 3) {
                    Text(team.title.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .kerning(1.2)

                    Text("\(model.score(of: team))")
                        .font(.system(size: 30, weight: .black, design: .rounded))

                    Text(model.names(on: team).joined(separator: ", "))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .opacity(0.9)

                    if mine {
                        Text("YOUR TEAM")
                            .font(.system(size: 9.5, weight: .black, design: .rounded))
                            .kerning(0.8)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background { Capsule().fill(.white.opacity(0.25)) }
                            .padding(.top, 2)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(VibeTheme.blurtTeam(team).opacity(mine ? 1 : 0.45))
                }
                .overlay {
                    if mine {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.7), lineWidth: 2)
                    }
                }
                .accessibilityIdentifier("blurt.score.\(team.rawValue)")
                .accessibilityLabel("\(team.title): \(model.score(of: team)), "
                                    + "\(model.names(on: team).joined(separator: ", "))"
                                    + (mine ? ", your team" : ""))
            }
        }
        .padding(.horizontal, 20)
    }

    /// The bar, and deliberately **no number**.
    ///
    /// A round lasts a random 50–70 seconds so that nobody can count it down, and
    /// the bar is not a countdown either: it fills with a sixth of the round
    /// still to go, so its end is not the buzzer. What says "nearly" is the
    /// colour changing and the bar pulsing — neither of which can be counted.
    ///
    /// The pulse runs off the display clock rather than the model's quarter-second
    /// tick, which is far too coarse to blink smoothly.
    private func clock(_ play: BlurtPlay) -> some View {
        let urgent = model.urgency > 0
        return VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(VibeTheme.surfaceStrong)

                    TimelineView(.animation) { context in
                        Capsule()
                            .fill(urgent ? VibeTheme.blurtUrgent : VibeTheme.blurtTeam(play.team))
                            .frame(width: max(0, proxy.size.width * model.barFill))
                            .opacity(urgent
                                     ? BlurtTiming.pulseOpacity(at: context.date.timeIntervalSinceReferenceDate)
                                     : 1)
                    }
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
        // What a screen reader gets instead of a number. It is not a countdown
        // out loud either, for the same reason it is not one on screen.
        .accessibilityElement()
        .accessibilityIdentifier("blurt.clock")
        .accessibilityLabel(urgent ? "Time is nearly up" : "Time is running")
    }

    /// The describer's screen. This is the only place in the app the word is
    /// drawn, and it is drawn from a deck derived on this device.
    private var describerCard: some View {
        VStack(spacing: 18) {
            Text("YOUR WORD — DON'T SAY IT")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(VibeTheme.tertiaryText)

            Text(model.currentWord)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(VibeTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .padding(.horizontal, 18)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(VibeTheme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(VibeTheme.blurtTeam(model.describingTeam ?? .one)
                                            .opacity(0.35),
                                        lineWidth: 2)
                        }
                }
                .accessibilityIdentifier("blurt.word")

            Button {
                Task { await model.gotIt() }
            } label: {
                Text("Got it — pass it on")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(VibeTheme.vibeBlurt)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("blurt.gotIt")

            Text("The word goes to the other team. The clock keeps running.")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }

    /// The team that is not holding the word.
    ///
    /// They are shown the word, which is the whole reason the BUZZ is worth
    /// having: catching somebody saying it is a judgement they can actually
    /// make, rather than a guess from hearing one word out of a sentence. The
    /// button is round, red and enormous because the moment it is needed lasts
    /// about a second.
    private func buzzCard(_ play: BlurtPlay) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("WATCH FOR IT")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .kerning(1.6)
                    .foregroundStyle(VibeTheme.tertiaryText)
                Text(model.currentWord)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(VibeTheme.primaryText)
                    .accessibilityIdentifier("blurt.watchedWord")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(VibeTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(VibeTheme.blurtUrgent.opacity(0.5), lineWidth: 2)
                    }
            }

            // The rule, said as a rule and with the name in it: the button is
            // only for one thing, and it is easy to press out of excitement.
            // The name is the resolved holder, so it is always somebody in the
            // room — it is empty in exactly one case, where the whole of the
            // describing side has gone and there is nobody to name.
            Text(model.describerName.isEmpty
                 ? "Watch close — if they say the word above, buzz them!"
                 : "Watch close — if \(model.describerName) says the word above, buzz them!")
                .font(.system(size: 16.5, weight: .bold, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("blurt.buzzRule")

            Button {
                Task { await model.buzz() }
            } label: {
                Text("BUZZ")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(.white)
                    .frame(width: 176, height: 176)
                    .background { Circle().fill(VibeTheme.blurtUrgent) }
                    .overlay { Circle().stroke(.white.opacity(0.3), lineWidth: 5) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("blurt.buzz")
            .accessibilityLabel(model.describerName.isEmpty
                                ? "Buzz"
                                : "Buzz — \(model.describerName) said the word")

            Text("Saying any part of it counts too.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
        }
        .padding(.horizontal, 20)
    }

    /// The holding team's other members. They are guessing, so this is the one
    /// screen in the room the word must never reach.
    private var guessingCard: some View {
        VStack(spacing: 12) {
            Text("GUESS IT")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .kerning(2.4)
                .foregroundStyle(myTint)

            Text("\(model.describerName) is describing a word to you")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // The instruction, said as an instruction. The headline above says
            // what is happening; this says what to do about it, in the team's
            // own colour so it reads as your job rather than as description.
            Text("Shout it out!")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(myTint)
                .accessibilityIdentifier("blurt.guessingCall")

            Text("Get it right and the word passes to the other team — the clock keeps running.")
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        // The one screen in the room that must never show the word, and until
        // now the one screen with no name to look it up by.
        .accessibilityIdentifier("blurt.guessing")
    }

    /// This player's team colour, which is not always team one's.
    private var myTint: Color { VibeTheme.blurtTeam(model.myTeam ?? .one) }

    private func resultBanner(_ play: BlurtPlay) -> some View {
        let scored = play.scorer
        return Text(model.lastRoundSummary)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background {
                Capsule().fill(scored.map { VibeTheme.blurtTeam($0) } ?? VibeTheme.surfaceStrong)
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("blurt.status")
    }

    private func handoverCard(_ play: BlurtPlay) -> some View {
        VStack(spacing: 16) {
            // No team tag above this, deliberately. It said which side was about
            // to play, in that side's colour, and read as "you are on this team"
            // — the one thing this screen is not saying. Whose turn it is is the
            // name below; which side *you* are on is the line under that.
            //
            // No "has left" branch either: the name here is the resolved holder,
            // so it is always somebody in the room. The line below says what to do
            // about a describer who walked out.
            Text(model.isDescriber
                 ? "You're up"
                 : model.describerName.isEmpty
                   ? "Nobody is left to describe"
                   : "\(model.describerName) is up")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)

            // Which side *you* are on, said outright. The scoreboard above shows
            // it, but this is the screen everyone is looking at between rounds.
            if let mine = model.myTeam {
                Text(mine == play.team ? "You're on \(mine.title) — guessing" : "You're on \(mine.title) — watching")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.blurtTeam(mine))
                    .accessibilityIdentifier("blurt.myTeam")
            }

            Text(model.isDescriber
                 ? "Hold the device so only you can see it, then start the clock."
                 : model.canStartThisRound
                   ? "They have left the room, and nothing is running yet. Anyone on their team can take the round."
                   : model.describerName.isEmpty
                     ? "Nobody on that side is in the room, so there is no round to take."
                     : "Pass the device to \(model.describerName). Everyone else, watch for the word.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if model.canStartThisRound {
                Button {
                    Task { await model.beginTurn() }
                } label: {
                    Text("Start the clock")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(VibeTheme.vibeBlurt)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("blurt.ready")
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Finished

    private var finished: some View {
        VStack(spacing: 18) {
            header(title: "SIMILAR VIBE", subtitle: "That's the game")

            Spacer()

            if let winner = model.winner {
                RoundOverPanel(
                    title: "\(winner.title) wins",
                    detail: "\(model.score(of: .one)) – \(model.score(of: .two))",
                    accent: AnyShapeStyle(VibeTheme.vibeBlurt),
                    primaryIdentifier: "blurt.playAgain",
                    action: { Task { await model.playAgain() } }
                ) {
                    teamScores
                }
                // The panel is the winner announcement now, so it carries the
                // identifier the title used to. Grouped rather than propagated,
                // so the button underneath keeps its own.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("blurt.winner")
            }

            Spacer()
        }
        .padding(.bottom, 20)
    }

    /// Both teams' totals, and who was on each side.
    private var teamScores: some View {
        HStack(spacing: 10) {
            ForEach(BlurtTeam.allCases, id: \.rawValue) { team in
                VStack(spacing: 4) {
                    Text(team.title.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .kerning(1.2)
                    Text("\(model.score(of: team))")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                    Text(model.names(on: team).joined(separator: ", "))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(VibeTheme.blurtTeam(team)
                            .opacity(model.myTeam == team ? 1 : 0.5))
                }
            }
        }
    }

    // MARK: - Shared pieces

    private func header(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Button {
                if model.isShared { model.leaveGame() } else { dismiss() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(VibeIconButtonStyle())
            .accessibilityLabel(model.isShared ? "Leave game" : "Back to games")
            .accessibilityIdentifier("blurt.back")

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
                SupportButton(game: .blurt)

                GameSettingsButton(prefix: "blurt") { showingSettings = true }

                if let code = model.sharedGameID, !model.hasStarted {
                    ShareLink(item: shareText(code)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(VibeIconButtonStyle())
                    .accessibilityLabel("Share game code")
                }

                // Once the game is under way the code moves behind one icon.
                // It used to vanish entirely: the big card only lives in the
                // lobby and the share button was drawn only before the start.
                // That is exactly when somebody new turns up — Blurt takes a
                // late arrival and puts them on a team — so the code has to be
                // reachable from the board, not only from the lobby.
                if model.sharedGameID != nil, model.hasStarted {
                    Button {
                        showingCode = true
                    } label: {
                        // A person with a plus, not `slider.horizontal.3`: that
                        // glyph means "Game settings" in Vibe Five, and the same
                        // icon for two different buttons in two games is what
                        // made them unreadable. This reads as "somebody else can
                        // join", which is what the button is for.
                        Image(systemName: "person.badge.plus")
                    }
                    .buttonStyle(VibeIconButtonStyle())
                    .accessibilityLabel("Game code")
                    .accessibilityIdentifier("blurt.showCode")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func shareText(_ code: String) -> String {
        GameInvite.text(game: .blurt, code: code)
    }

    /// Runs a shared-game action, collecting a name first if there is not one.
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
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.vibeBlurt)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    }
}
