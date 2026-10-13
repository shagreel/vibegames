import XCTest
@testable import VibeGames

/// Similar Vibe's rules.
///
/// The rules are the part worth pinning: the words come from a seed, and the
/// scoring is the whole game — the team *not* holding the word takes the point.
/// If that were backwards the game would still "work" and be completely wrong,
/// which is exactly the sort of thing a test is for.
final class VibeBlurtTests: XCTestCase {

    // MARK: - The content

    func testTheDeckIsThousandsOfDistinctThingsToDescribe() {
        let words = BlurtWords.all

        // A table playing all evening should not come round again, and the
        // fixtures were dumped against this library.
        XCTAssertGreaterThanOrEqual(words.count, 2000, "the deck size the fixtures were dumped for")
        XCTAssertEqual(Set(words).count, words.count, "a repeated word is a wasted turn")
        XCTAssertFalse(words.contains(""), "an empty entry would draw a blank screen")

        for word in words {
            // Safe inside a Swift string literal. Not strictly ASCII: "Piñata" is
            // the American spelling and belongs as it is.
            XCTAssertFalse(word.contains("\""), "\(word) would break the Swift literal")
            XCTAssertFalse(word.contains("\\"), "\(word) would break the Swift literal")
            XCTAssertFalse(word.contains("\n"), "\(word) would break the Swift literal")
            let pieces = word.split(separator: " ")
            XCTAssertTrue((1...4).contains(pieces.count), "\(word) is not 1-4 words")
        }
    }

    // MARK: - The deck

    func testTheSameSeedDealsTheSameWordsEverywhere() {
        let all = Set(BlurtPack.allCases)
        let first = BlurtDeck.shuffled(seed: 42, packs: all)
        let second = BlurtDeck.shuffled(seed: 42, packs: all)

        XCTAssertEqual(first, second, "a shared game depends on this being stable")
        XCTAssertEqual(Set(first).count, BlurtWords.all.count, "a shuffle, not a filter")
    }

    func testDifferentSeedsDealDifferentHands() {
        let all = Set(BlurtPack.allCases)
        XCTAssertNotEqual(BlurtDeck.shuffled(seed: 1, packs: all),
                          BlurtDeck.shuffled(seed: 2, packs: all))
    }

    func testARoomHasOneDeckAndItNeverChanges() {
        // One deck per room, walked across as many games as the table plays.
        // Shuffling afresh for each game is what used to hand back nearly the
        // same words: ten out of a few hundred twice shares one or two.
        let all = Set(BlurtPack.allCases)
        XCTAssertEqual(BlurtDeck.shuffled(seed: 7, packs: all),
                       BlurtDeck.shuffled(seed: 7, packs: all))
        XCTAssertEqual(BlurtDeck.shuffled(seed: 7, packs: all).count, BlurtWords.all.count)
    }

    func testConsecutiveSeedsDoNotDealNearlyTheSameDeck() {
        // The bug that started this: the generator's seeding made seed `n + 1`
        // replay seed `n`'s stream one draw late, so a deck derived from
        // `seed + 1` came back almost identical. Two unrelated shuffles should
        // share almost nothing over their first twenty — with thousands of words
        // to draw from, the expected overlap is a fifth of one word.
        let all = Set(BlurtPack.allCases)
        var shared = 0
        let trials = 60
        for seed in UInt32(1000)..<UInt32(1000 + trials) {
            let first = Set(BlurtDeck.shuffled(seed: seed, packs: all).prefix(20))
            let second = BlurtDeck.shuffled(seed: seed + 1, packs: all).prefix(20)
            shared += second.filter { first.contains($0) }.count
        }
        let average = Double(shared) / Double(trials)
        XCTAssertLessThan(average, 2, "consecutive seeds are dealing nearly the same deck (\(average) of 20)")
    }

    func testTheDeckWrapsRatherThanRunningOut() {
        let deck = BlurtDeck.shuffled(seed: 3, packs: Set(BlurtPack.allCases))

        XCTAssertEqual(BlurtDeck.word(at: 0, in: deck), deck[0])
        XCTAssertEqual(BlurtDeck.word(at: deck.count, in: deck), deck[0], "wrapped round")
        XCTAssertEqual(BlurtDeck.word(at: deck.count + 5, in: deck), deck[5])
        XCTAssertEqual(BlurtDeck.word(at: -1, in: deck), deck[deck.count - 1],
                       "a negative index must not crash a live game")
        XCTAssertEqual(BlurtDeck.word(at: 0, in: []), "")
    }

    // MARK: - Packs

    func testEveryPackHasWordsAndTheyAddUpToTheWholeDeck() {
        var total = 0
        for pack in BlurtPack.allCases {
            XCTAssertFalse(pack.words.isEmpty, "\(pack.rawValue) has no words")
            XCTAssertFalse(pack.title.isEmpty)
            XCTAssertFalse(pack.blurb.isEmpty)
            total += pack.words.count
        }
        XCTAssertEqual(total, BlurtWords.all.count)
        XCTAssertGreaterThanOrEqual(BlurtWords.all.count, 2000)
    }

    func testTheWordsAreGroupedInPackOrderNotSelectionOrder() {
        // Two people ticking the same boxes in a different order must get the
        // same deck, or they would be describing different things at each other.
        let one: Set<BlurtPack> = [.food, .play]
        let two: Set<BlurtPack> = [.play, .food]

        XCTAssertEqual(BlurtDeck.words(in: one), BlurtDeck.words(in: two))
        XCTAssertEqual(BlurtDeck.words(in: one), FoodWords.all + PlayWords.all)
    }

    func testChoosingNoPacksPlaysWithAllOfThem() {
        // An empty set is what a corrupt read looks like, not a choice.
        XCTAssertEqual(BlurtDeck.words(in: []), BlurtWords.all)
    }

    func testANarrowDeckOnlyContainsTheChosenPacks() {
        let deck = BlurtDeck.shuffled(seed: 11, packs: [.food])
        XCTAssertEqual(Set(deck), Set(FoodWords.all))
    }

    func testTheDeckDependsOnThePacksAsWellAsTheSeed() {
        let all = BlurtDeck.shuffled(seed: 5, packs: Set(BlurtPack.allCases))
        let some = BlurtDeck.shuffled(seed: 5, packs: [.food])
        XCTAssertNotEqual(all, some)
    }

    // MARK: - How long a round lasts

    func testARoundIsARandomLengthNobodyCanCount() {
        var seen = Set<Int>()
        for _ in 0..<400 {
            let seconds = BlurtTiming.randomTurnSeconds()
            XCTAssertGreaterThanOrEqual(seconds, BlurtTiming.shortest)
            XCTAssertLessThanOrEqual(seconds, BlurtTiming.longest)
            seen.insert(seconds)
        }
        // Not a coin toss between two values. A length a table can learn is a
        // length a table counts down out loud, which is what this replaced.
        XCTAssertGreaterThan(seen.count, 10, "the round length is barely varying")
    }

    func testNothingIsUrgentUntilTheLastOfTheRound() {
        let total: TimeInterval = 60
        XCTAssertEqual(BlurtTiming.urgency(remaining: total, total: total), 0)
        XCTAssertEqual(BlurtTiming.urgency(remaining: total * 0.5, total: total), 0)
        // The tail is where it starts, and from there it is a ramp rather than a
        // step — the sound and the bar both ride this one number.
        XCTAssertEqual(BlurtTiming.urgency(remaining: total * 0.15, total: total), 0, accuracy: 0.0001)
        XCTAssertEqual(BlurtTiming.urgency(remaining: total * 0.10, total: total), 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(BlurtTiming.urgency(remaining: total * 0.05, total: total), 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(BlurtTiming.urgency(remaining: 0, total: total), 1)
    }

    func testTheBarIsSpentBeforeTheRoundIs() {
        let total: TimeInterval = 60
        XCTAssertEqual(BlurtTiming.barFill(remaining: total, total: total), 0)
        // Full with a sixth of the round still to play, so the bar running out
        // cannot be read as the buzzer.
        XCTAssertEqual(BlurtTiming.barFill(remaining: total * 0.15, total: total), 1, accuracy: 0.0001)
        XCTAssertEqual(BlurtTiming.barFill(remaining: total * 0.01, total: total), 1)
        XCTAssertEqual(BlurtTiming.barFill(remaining: 0, total: total), 1)

        // And it only ever fills. A bar that went backwards would read as time
        // being added.
        var last = 0.0
        for remaining in stride(from: total, through: 0, by: -0.5) {
            let fill = BlurtTiming.barFill(remaining: remaining, total: total)
            XCTAssertGreaterThanOrEqual(fill, last - 0.0001)
            last = fill
        }
    }

    func testTheTickHurriesAndGetsLouder() {
        let steady = BlurtTiming.tickInterval(urgency: 0)
        let frantic = BlurtTiming.tickInterval(urgency: 1)

        XCTAssertEqual(steady, BlurtTiming.steadyInterval)
        XCTAssertLessThan(frantic, steady, "the tick has to hurry to warn anybody")
        XCTAssertGreaterThan(frantic, 0.05, "but not so fast it becomes a continuous tone")

        XCTAssertEqual(BlurtTiming.tickVolume(urgency: 0), BlurtTiming.steadyVolume)
        XCTAssertEqual(BlurtTiming.tickVolume(urgency: 1), BlurtTiming.urgentVolume)
        XCTAssertGreaterThan(BlurtTiming.urgentVolume, BlurtTiming.steadyVolume)
    }

    func testTheScheduleIsSteadyAndThenHurried() {
        let total: TimeInterval = 60
        let schedule = BlurtTiming.tickSchedule(total: total)
        XCTAssertFalse(schedule.isEmpty)

        // Every tick is inside the round, in order, and none lands after the
        // buzzer.
        var previous: TimeInterval = 0
        for tick in schedule {
            XCTAssertGreaterThan(tick.at, previous)
            XCTAssertLessThan(tick.at, total, "a tick after the buzzer")
            previous = tick.at
        }

        // The first part really is steady: gaps only start closing once the tail
        // has begun.
        let tailStart = total * (1 - BlurtTiming.tailFraction)
        let early = zip(schedule, schedule.dropFirst()).filter { $0.1.at < tailStart }
        XCTAssertFalse(early.isEmpty, "no steady ticks to check")
        for (a, b) in early {
            XCTAssertEqual(b.at - a.at, BlurtTiming.steadyInterval, accuracy: 0.0001)
        }

        // And by the end it is hurrying hard.
        let lastGap = schedule[schedule.count - 1].at - schedule[schedule.count - 2].at
        XCTAssertLessThan(lastGap, BlurtTiming.steadyInterval / 2)
    }

    func testEveryLengthHurriesBeforeItEnds() {
        // However long the round happens to be, the hurry has to actually
        // happen — a 70-second round must not tail off into silence.
        for total in [50.0, 55.0, 60.0, 65.0, 70.0] {
            let schedule = BlurtTiming.tickSchedule(total: total)
            let tailStart = total * (1 - BlurtTiming.tailFraction)
            let inTail = schedule.filter { $0.at >= tailStart }

            XCTAssertGreaterThanOrEqual(inTail.count, 5, "\(total)s barely hurried")
            XCTAssertEqual(schedule.last?.volume ?? 0, BlurtTiming.urgentVolume, accuracy: 0.2,
                           "\(total)s never got loud")
        }
    }

    func testTheBarPulsesRatherThanCountingDown() {
        // The pulse is a function of the moment, not a stored flag, so that a
        // round ending mid-blink cannot leave the next one stuck at whatever the
        // last one was doing.
        let period = 1 / BlurtTiming.pulseRate
        let samples = (0..<100).map { BlurtTiming.pulseOpacity(at: Double($0) / 100 * period) }

        for value in samples {
            XCTAssertGreaterThanOrEqual(value, 0.35)
            XCTAssertLessThanOrEqual(value, 1)
        }
        // Shallow enough to be decoration rather than a warning.
        XCTAssertGreaterThan(samples.max()! - samples.min()!, 0.5,
                             "the pulse is too shallow to notice")

        // And it comes back round.
        XCTAssertEqual(BlurtTiming.pulseOpacity(at: 0.3),
                       BlurtTiming.pulseOpacity(at: 0.3 + period), accuracy: 0.0001)
    }

    // MARK: - Teams

    func testTheSplitIsBalanced() {
        for count in 2...9 {
            let roster = (1...count).map { "p\($0)" }
            let teams = BlurtRules.split(players: roster, seed: 99)
            let one = BlurtRules.members(of: .one, in: teams).count
            let two = BlurtRules.members(of: .two, in: teams).count

            XCTAssertEqual(one + two, count)
            XCTAssertLessThanOrEqual(abs(one - two), 1, "\(count) players split \(one)/\(two)")
            XCTAssertGreaterThan(one, 0, "\(count) players left team one empty")
            XCTAssertGreaterThan(two, 0, "\(count) players left team two empty")
        }
    }

    func testTheSplitIgnoresTheOrderPeopleArrivedIn() {
        let inOrder = ["p1", "p2", "p3", "p4", "p5"]
        let shuffledArrival = ["p4", "p1", "p5", "p2", "p3"]

        XCTAssertEqual(BlurtRules.split(players: inOrder, seed: 12),
                       BlurtRules.split(players: shuffledArrival, seed: 12),
                       "the same room and seed must not depend on who joined first")
    }

    func testTheSplitIsRandomAcrossSeeds() {
        let roster = ["p1", "p2", "p3", "p4"]
        let shapes = Set((1...40).map { seed in
            BlurtRules.members(of: .one, in: BlurtRules.split(players: roster, seed: UInt32(seed)))
                .joined(separator: ",")
        })
        XCTAssertGreaterThan(shapes.count, 1, "every seed put the same people together")
    }

    // MARK: - Turns

    func testTheWordNeverStaysWithOneTeamForTwoWordsRunning() {
        // This is the mechanic, not a detail: pressing "got it" is what moves
        // the word to the other side, so nobody is ever caught twice in a row.
        for turn in 0..<12 {
            XCTAssertNotEqual(BlurtRules.describingTeam(turn: turn),
                              BlurtRules.describingTeam(turn: turn + 1),
                              "turns \(turn) and \(turn + 1) were the same team")
        }
    }

    func testTheRotationGoesRoundEverybodyInTheSameOrderEveryTime() {
        // Four players, two a side: the order is A's first, B's first, A's
        // second, B's second, and then it starts again.
        let roster = ["p1", "p2", "p3", "p4"]
        let teams = BlurtRules.split(players: roster, seed: 3)
        let one = BlurtRules.members(of: .one, in: teams)
        let two = BlurtRules.members(of: .two, in: teams)
        let offsets = BlurtRules.describerOffsets(oneMembers: one.count, twoMembers: two.count, seed: 3)

        let order = (0..<(BlurtRules.minimumPlayers * 2)).map { turn -> String in
            let team = BlurtRules.describingTeam(turn: turn)
            let members = team == .one ? one : two
            let offset = team == .one ? offsets.one : offsets.two
            return BlurtRules.describer(for: team, members: members, turn: turn, offset: offset) ?? ""
        }

        // The second half repeats the first: same people, same order.
        XCTAssertEqual(Array(order[0..<4]), Array(order[4..<8]))
        XCTAssertEqual(Set(order), Set(roster), "somebody never got the word")
    }

    func testARoomNeedsTwoPeopleOnEachSide() {
        XCTAssertEqual(BlurtRules.minimumPerTeam, 2)
        XCTAssertEqual(BlurtRules.minimumPlayers, 4)
        XCTAssertEqual(BlurtRules.minimumPlayers, BlurtRules.minimumPerTeam * 2)
    }

    func testTurnsAlternateAndTeamOneStarts() {
        XCTAssertEqual(BlurtRules.describingTeam(turn: 0), .one)
        XCTAssertEqual(BlurtRules.describingTeam(turn: 1), .two)
        XCTAssertEqual(BlurtRules.describingTeam(turn: 2), .one)
        XCTAssertEqual(BlurtRules.describingTeam(turn: 7), .two)
    }

    func testNobodyDescribesTwiceBeforeEverybodyHas() {
        let roster = ["p1", "p2", "p3", "p4", "p5"]
        let teams = BlurtRules.split(players: roster, seed: 5)
        let one = BlurtRules.members(of: .one, in: teams)
        let two = BlurtRules.members(of: .two, in: teams)
        let offsets = BlurtRules.describerOffsets(oneMembers: one.count, twoMembers: two.count, seed: 5)

        var seen: [BlurtTeam: [String]] = [.one: [], .two: []]
        for turn in 0..<12 {
            let team = BlurtRules.describingTeam(turn: turn)
            let members = team == .one ? one : two
            let offset = team == .one ? offsets.one : offsets.two
            let who = BlurtRules.describer(for: team, members: members, turn: turn, offset: offset)
            XCTAssertNotNil(who)
            seen[team]?.append(who ?? "")
        }

        // Six turns each, so a three-person team rotates twice and a two-person
        // team three times — and nobody sits out entirely.
        XCTAssertEqual(Set(seen[.one] ?? []), Set(one), "somebody on team one never described")
        XCTAssertEqual(Set(seen[.two] ?? []), Set(two), "somebody on team two never described")
    }

    func testTheDescriberIsAlwaysSomebodyOnTheDescribingTeam() {
        let roster = ["p1", "p2", "p3", "p4", "p5", "p6"]
        let teams = BlurtRules.split(players: roster, seed: 77)
        let one = BlurtRules.members(of: .one, in: teams)
        let two = BlurtRules.members(of: .two, in: teams)
        let offsets = BlurtRules.describerOffsets(oneMembers: one.count, twoMembers: two.count, seed: 77)

        for turn in 0..<20 {
            let team = BlurtRules.describingTeam(turn: turn)
            let members = team == .one ? one : two
            let offset = team == .one ? offsets.one : offsets.two
            let who = BlurtRules.describer(for: team, members: members, turn: turn, offset: offset)
            XCTAssertTrue(members.contains(who ?? ""), "turn \(turn) handed it to the wrong team")
        }
    }

    func testAnEmptyTeamHasNobodyToDescribe() {
        XCTAssertNil(BlurtRules.describer(for: .one, members: [], turn: 0, offset: 0))
    }

    func testTheOffsetsAreTheSameForEverybodyAndDifferBetweenSeeds() {
        let first = BlurtRules.describerOffsets(oneMembers: 3, twoMembers: 3, seed: 8)
        let again = BlurtRules.describerOffsets(oneMembers: 3, twoMembers: 3, seed: 8)
        XCTAssertEqual(first.one, again.one)
        XCTAssertEqual(first.two, again.two)

        let offsets = (1...30).map { BlurtRules.describerOffsets(oneMembers: 3, twoMembers: 3, seed: UInt32($0)).one }
        XCTAssertGreaterThan(Set(offsets).count, 1, "the first describer was never random")
    }

    // MARK: - Scoring

    func testThePointGoesToTheTeamNotHoldingTheWord() {
        XCTAssertEqual(BlurtRules.scoringTeam(describing: .one), .two)
        XCTAssertEqual(BlurtRules.scoringTeam(describing: .two), .one)
    }

    func testTheFirstTeamToTheTargetWins() {
        XCTAssertNil(BlurtRules.winner(one: 0, two: 0, target: 7))
        XCTAssertNil(BlurtRules.winner(one: 6, two: 6, target: 7))
        XCTAssertEqual(BlurtRules.winner(one: 7, two: 6, target: 7), .one)
        XCTAssertEqual(BlurtRules.winner(one: 6, two: 7, target: 7), .two)
        XCTAssertEqual(BlurtRules.winner(one: 9, two: 2, target: 7), .one)
    }

    func testTheTargetIsSeven() {
        XCTAssertEqual(BlurtRules.target, 7)
    }

    // MARK: - The play node

    func testThePlayNodeSurvivesARoundTripThroughTheDatabase() {
        var play = BlurtPlay()
        play.round = 2
        play.turn = 5
        play.team = .two
        play.describer = "abcd1234"
        play.word = 41
        play.state = .ended
        play.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        play.endsAt = Date(timeIntervalSince1970: 1_700_000_060)
        play.reason = .blurt
        play.scorer = .one
        play.one = 3
        play.two = 4
        play.finished = false

        let restored = BlurtPlay(value: play.value)

        XCTAssertEqual(restored, play, "what comes back must be what went in")
    }

    func testAnAbsentOptionalIsLeftOutRatherThanSentAsNull() {
        // The rules use `hasChildren`, which counts neither an absent key nor an
        // explicit null — but a null would still be a value on the wire.
        let value = BlurtPlay().value

        XCTAssertNil(value["startedAt"])
        XCTAssertNil(value["endsAt"])
        XCTAssertNil(value["reason"])
        XCTAssertNil(value["scorer"])
        XCTAssertNotNil(value["turn"], "the required fields are always present")
        XCTAssertNotNil(value["state"])
    }

    // MARK: - Starting a round

    private func play(state: BlurtState, describer: String = "me", finished: Bool = false) -> BlurtPlay {
        var play = BlurtPlay()
        play.state = state
        play.describer = describer
        play.finished = finished
        return play
    }

    func testTheStartButtonWorksInBothStatesTheHandoverScreenAppearsIn() {
        // The handover screen is what is shown whenever the round is not
        // running, and that is two different states: `.ready` for the first
        // round of a game, and `.ended` for every round after it, because ending
        // a round leaves the result and the next round's rotation behind in the
        // same state. This asked only for `.ready`, so the first round started
        // and no round after it did.
        XCTAssertTrue(VibeBlurtModel.canStartRound(play: play(state: .ready), me: "me"),
                      "the first round of a game")
        XCTAssertTrue(VibeBlurtModel.canStartRound(play: play(state: .ended), me: "me"),
                      "and every round after it")
    }

    func testNobodyElseCanStartTheRound() {
        XCTAssertFalse(VibeBlurtModel.canStartRound(play: play(state: .ended), me: "someone-else"),
                       "only the person whose phone is showing the word")
        XCTAssertFalse(VibeBlurtModel.canStartRound(play: play(state: .ended), me: nil))
    }

    func testARoundAlreadyRunningCannotBeStartedAgain() {
        XCTAssertFalse(VibeBlurtModel.canStartRound(play: play(state: .running), me: "me"))
    }

    func testAFinishedGameHasNothingLeftToStart() {
        XCTAssertFalse(VibeBlurtModel.canStartRound(play: play(state: .ended, finished: true), me: "me"))
    }

    func testThereIsNothingToStartWithoutARound() {
        XCTAssertFalse(VibeBlurtModel.canStartRound(play: nil, me: "me"))
    }

    func testATeamMateTakesOverARoundWhoseDescriberHasLeft() {
        // Nothing is running yet in this state, so no clock will ever end a
        // round that nobody can start: without this the whole table waits on a
        // phone that has gone home.
        var round = play(state: .ready, describer: "gone")
        round.team = .one

        XCTAssertTrue(VibeBlurtModel.canStartRound(play: round, me: "gone", present: [], myTeam: .one),
                      "the named describer can still start it — they are the one tapping")
        XCTAssertTrue(VibeBlurtModel.canStartRound(play: round, me: "mate", present: ["mate"], myTeam: .one),
                      "and a team-mate picks it up once they have gone")
        XCTAssertFalse(VibeBlurtModel.canStartRound(play: round, me: "other", present: ["other"], myTeam: .two),
                       "but not somebody on the other team")
    }

    func testNobodyStandsInWhileTheDescriberIsStillHere() {
        var round = play(state: .ready, describer: "here")
        round.team = .one
        XCTAssertFalse(VibeBlurtModel.canStartRound(play: round, me: "mate",
                                                    present: ["here", "mate"], myTeam: .one),
                       "the round is theirs, not the team's")
    }

    func testAStandInCannotRestartARoundThatIsAlreadyRunning() {
        var round = play(state: .running, describer: "gone")
        round.team = .one
        XCTAssertFalse(VibeBlurtModel.canStartRound(play: round, me: "mate",
                                                    present: ["mate"], myTeam: .one),
                       "the clock is already going")
    }

    // MARK: - Who is actually in the room

    func testTheWordSkipsSomebodyWhoHasLeft() {
        let members = ["ann", "bo", "cass", "dee"]

        // The rotation walks the whole team, so each of these has their own turn.
        XCTAssertEqual(BlurtRules.describer(for: .one, members: members, turn: 2, offset: 0), "bo")

        let withoutBo: Set<String> = ["ann", "cass", "dee"]
        XCTAssertEqual(BlurtRules.describer(for: .one, members: members, turn: 2, offset: 0, present: withoutBo),
                       "cass", "bo has gone, so the turn walks on to the next person who is here")
        XCTAssertNil(BlurtRules.describer(for: .one, members: members, turn: 2, offset: 0, present: []),
                     "better nobody than a phone that is not in the room")
    }

    func testSomebodyLeavingDoesNotShiftAnybodyElsesTurn() {
        // A departure takes that person out of the order rather than handing
        // their turn to the next person, who would then describe twice in a row.
        // Everyone left keeps a turn, and a returning player gets their own back.
        let members = ["ann", "bo", "cass", "dee"]
        let withoutBo: Set<String> = ["ann", "cass", "dee"]
        let turns = Array(stride(from: 0, to: 8, by: 2))

        let withEverybody = turns.map {
            BlurtRules.describer(for: .one, members: members, turn: $0, offset: 0, present: Set(members))
        }
        let withBoGone = turns.map {
            BlurtRules.describer(for: .one, members: members, turn: $0, offset: 0, present: withoutBo)
        }

        XCTAssertEqual(withEverybody, ["ann", "bo", "cass", "dee"])
        XCTAssertEqual(withBoGone, ["ann", "cass", "dee", "ann"],
                       "bo is skipped and nobody else describes twice")
        XCTAssertEqual(
            BlurtRules.describer(for: .one, members: members, turn: 2, offset: 0, present: Set(members)),
            "bo", "and it is theirs again the moment they are back")
    }

    func testTheWordMovesToSomebodyWhoIsStillHere() {
        let teams: [String: BlurtTeam] = ["ann": .one, "bo": .one, "cass": .two, "dee": .two]

        // While the named describer is in the room the word is theirs, whatever
        // the rotation would have said.
        XCTAssertEqual(BlurtRules.holder(named: "bo", team: .one, turn: 0, teams: teams,
                                         present: ["ann", "bo", "cass", "dee"], seed: 7),
                       "bo")

        // Once they have gone it moves to somebody on their own side who is here.
        // Never to the other team, and never to a phone that has left.
        XCTAssertEqual(BlurtRules.holder(named: "bo", team: .one, turn: 0, teams: teams,
                                         present: ["ann", "cass", "dee"], seed: 7),
                       "ann", "a round cannot be described by somebody who is not here")

        // And there is nobody to name once the whole of that side has gone.
        XCTAssertNil(BlurtRules.holder(named: "bo", team: .one, turn: 0, teams: teams,
                                       present: ["cass", "dee"], seed: 7),
                     "a room with one team in it is not a game")
    }

    func testTheWordComesBackWhenTheDescriberDoes() {
        // Somebody who steps out and returns is in the game again, so the word can
        // come back to them — the team list never lost their place.
        let teams: [String: BlurtTeam] = ["ann": .one, "bo": .one, "cass": .two, "dee": .two]
        let withoutBo: Set<String> = ["ann", "cass", "dee"]
        let everybody: Set<String> = ["ann", "bo", "cass", "dee"]

        XCTAssertEqual(BlurtRules.holder(named: "bo", team: .one, turn: 0, teams: teams,
                                         present: withoutBo, seed: 7),
                       "ann", "the word moves while they are away")
        XCTAssertEqual(BlurtRules.holder(named: "bo", team: .one, turn: 0, teams: teams,
                                         present: everybody, seed: 7),
                       "bo", "and it is theirs again the moment they are back")
    }

    // MARK: - The buzz you feel

    private func running(describer: String) -> BlurtPlay {
        var play = BlurtPlay()
        play.turn = 3
        play.team = .one
        play.describer = describer
        play.state = .running
        return play
    }

    /// The state a finished round really leaves behind.
    ///
    /// The service moves the rotation on *behind* the result, so the ended
    /// snapshot names the person who is up next — not the one who was just
    /// caught. That is the whole reason "am I the describer?" is the wrong
    /// question to ask of the new state, and leaving it out of this helper made
    /// the test pass against a check that asked exactly that.
    private func ended(_ play: BlurtPlay, reason: BlurtEnd) -> BlurtPlay {
        var next = play
        next.state = .ended
        next.reason = reason
        next.scorer = play.team.other
        next.turn += 1
        next.team = play.team.other
        next.word += 1
        next.describer = "next-person"
        return next
    }

    func testThePersonHoldingTheWordFeelsTheBuzz() {
        let holding = running(describer: "me")

        XCTAssertTrue(VibeBlurtModel.caughtMe(previous: holding,
                                              next: ended(holding, reason: .blurt),
                                              holder: "me",
                                              me: "me"))
    }

    func testNobodyElseFeelsIt() {
        let holding = running(describer: "me")
        let buzzed = ended(holding, reason: .blurt)

        // The team that pressed the button knows already, and so does everyone
        // else — it is the describer who needs telling.
        XCTAssertFalse(VibeBlurtModel.caughtMe(previous: holding, next: buzzed,
                                               holder: "me", me: "someone-else"))
        XCTAssertFalse(VibeBlurtModel.caughtMe(previous: holding, next: buzzed,
                                               holder: "me", me: nil))
    }

    func testRunningOutOfTimeDoesNotBuzzAnybody() {
        // The clock is on every screen, so the end of it is not news. Only a
        // buzz catches somebody mid-sentence.
        let holding = running(describer: "me")

        XCTAssertFalse(VibeBlurtModel.caughtMe(previous: holding,
                                               next: ended(holding, reason: .time),
                                               holder: "me",
                                               me: "me"))
    }

    func testTheBuzzOnlyLandsWhenTheRoundWasActuallyRunning() {
        let holding = running(describer: "me")
        var waiting = holding
        waiting.state = .ready

        XCTAssertFalse(VibeBlurtModel.caughtMe(previous: waiting,
                                               next: ended(holding, reason: .blurt),
                                               holder: "me",
                                               me: "me"),
                       "a round nobody had started cannot be caught")

        // And a snapshot that has not changed is not a buzz either, however many
        // times the observer hands it over.
        let alreadyOver = ended(holding, reason: .blurt)
        XCTAssertFalse(VibeBlurtModel.caughtMe(previous: alreadyOver, next: alreadyOver,
                                               holder: "me", me: "me"))
    }

    func testTheBuzzFollowsTheWordWhenItHasMoved() {
        // The named describer left and the rotation gave the word to somebody
        // else. The buzz belongs to whoever is actually holding it — otherwise the
        // one person who was mid-sentence is the one phone that never feels it.
        let holding = running(describer: "gone")
        let next = ended(holding, reason: .blurt)

        XCTAssertTrue(VibeBlurtModel.caughtMe(previous: holding, next: next,
                                              holder: "took-over", me: "took-over"))
        XCTAssertFalse(VibeBlurtModel.caughtMe(previous: holding, next: next,
                                               holder: "took-over", me: "gone"))
    }

    func testASnapshotResolvesTheHolderForTheCaughtBuzzLookBack() {
        // `holder(in:)` is what the caught-buzz comparison looks back with, so it
        // has to answer for a snapshot that is not the current one.
        var snapshot = BlurtSnapshot()
        snapshot.seed = 7
        snapshot.teams = ["ann": .one, "bo": .one, "cass": .two, "dee": .two]
        snapshot.players = ["ann": "Ann", "cass": "Cass", "dee": "Dee"]

        var play = BlurtPlay()
        play.turn = 0
        play.team = .one
        play.describer = "bo"
        play.state = .running
        snapshot.play = play

        XCTAssertEqual(VibeBlurtModel.holder(in: snapshot), "ann",
                       "bo has gone, so the word is somebody else's")

        snapshot.players = ["cass": "Cass", "dee": "Dee"]
        XCTAssertNil(VibeBlurtModel.holder(in: snapshot),
                     "and nobody holds it once that whole side has gone")
    }

    // MARK: - The room, against the real database

    /// The roster comes back with everybody's **name** in it.
    ///
    /// This is the one that was wrong: the observer stored a flag instead of the
    /// value, so `snapshot.players` was always empty — the room looked empty,
    /// and the Start button never became available on the phone while the
    /// browser was fine. It needs the real database, so it skips without a
    /// Firebase config, like the other back-end tests.
    func testTheRoomComesBackWithEverybodysNameInIt() async throws {
        try XCTSkipUnless(FirebaseBootstrapper.isConfigured, "No Firebase config bundled")

        let service = VibeBlurtService.shared
        let gameID = "zz" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
        let names = ["Alex", "Sam", "Jo", "Robin"]

        try await service.createGame(gameID: gameID,
                                     seed: 1,
                                     creatorName: names[0],
                                     playerID: "test-player-1",
                                     packs: Set(BlurtPack.allCases))
        for (index, name) in names.dropFirst().enumerated() {
            try await service.joinGame(gameID: gameID,
                                       playerID: "test-player-\(index + 2)",
                                       name: name)
        }

        let snapshot = await VibeBlurtTests.waitForRoom(service, gameID: gameID,
                                                        count: names.count)

        let room = try XCTUnwrap(snapshot, "the room never reported everybody who joined")
        XCTAssertEqual(room.players.count, names.count)
        XCTAssertEqual(room.players.values.sorted(), names.sorted(),
                       "the roster came back without names in it")
        XCTAssertFalse(room.started, "a room nobody has started")

        // And it is enough people to start, which is what enables the button.
        XCTAssertGreaterThanOrEqual(room.players.count, BlurtRules.minimumPlayers)
    }

    func testTheRoomHandsBackTheTeamsItWasDealt() async throws {
        try XCTSkipUnless(FirebaseBootstrapper.isConfigured, "No Firebase config bundled")

        let service = VibeBlurtService.shared
        let gameID = "zz" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
        let names = ["Alex", "Sam", "Jo", "Robin"]
        let short = { (index: Int) in
            VibeBlurtService.shortID(playerID: "test-player-\(index)", gameID: gameID)
        }

        try await service.createGame(gameID: gameID,
                                     seed: 7,
                                     creatorName: names[0],
                                     playerID: "test-player-1",
                                     packs: [.food, .play])
        for index in 2...4 {
            try await service.joinGame(gameID: gameID,
                                       playerID: "test-player-\(index)",
                                       name: names[index - 1])
        }

        try await service.startGame(gameID: gameID, seed: 7)
        let snapshot = await VibeBlurtTests.waitForRoom(service, gameID: gameID,
                                                        count: names.count,
                                                        needsTeams: true)

        let room = try XCTUnwrap(snapshot)
        XCTAssertTrue(room.started)
        XCTAssertEqual(room.packs, Set([.food, .play]), "the room kept its own packs")
        XCTAssertEqual(room.teams.count, 4, "everybody was put on a team")
        XCTAssertEqual(BlurtRules.members(of: .one, in: room.teams).count, 2)
        XCTAssertEqual(BlurtRules.members(of: .two, in: room.teams).count, 2)
        // Which side anybody lands on is the shuffle's business, so the test
        // asserts the split is *complete* rather than who is where.
        let everyTeamMember = BlurtRules.members(of: .one, in: room.teams)
            + BlurtRules.members(of: .two, in: room.teams)
        XCTAssertEqual(Set(everyTeamMember), Set((1...4).map(short)))

        let play = try XCTUnwrap(room.play, "the first word was dealt")
        XCTAssertEqual(play.state, .ready, "the round waits for the describer")
        XCTAssertTrue(room.teams.values.contains(play.team))
        XCTAssertNotNil(room.teams[play.describer], "the describer is on a team")
    }

    /// Waits for the observer to report a snapshot matching `matching`, giving
    /// up after ten seconds rather than hanging the suite.
    @MainActor
    private static func waitForSnapshot(_ service: VibeBlurtService,
                                        gameID: String,
                                        matching: @escaping (BlurtSnapshot) -> Bool) async -> BlurtSnapshot? {
        final class Box: @unchecked Sendable { var done = false }
        let box = Box()

        return await withCheckedContinuation { continuation in
            // Watching, not playing: no presence, so this does not turn up in
            // the roster the test is counting.
            let observation = service.observe(gameID: gameID) { snapshot in
                guard matching(snapshot), !box.done else { return }
                box.done = true
                continuation.resume(returning: snapshot)
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                guard !box.done else { return }
                box.done = true
                service.stopObserving(observation)
                continuation.resume(returning: nil)
            }
        }
    }

    /// A complete room: everybody present, and optionally the teams dealt.
    @MainActor
    private static func waitForRoom(_ service: VibeBlurtService,
                                    gameID: String,
                                    count: Int,
                                    needsTeams: Bool = false) async -> BlurtSnapshot? {
        await waitForSnapshot(service, gameID: gameID) { snapshot in
            snapshot.players.count >= count && (!needsTeams || snapshot.teams.count >= count)
        }
    }

    /// Sets up a started room of four and hands back the game id and the word.
    @MainActor
    private static func startedRoom(_ service: VibeBlurtService,
                                    seed: UInt32 = 7) async throws -> (gameID: String, play: BlurtPlay) {
        let gameID = "zz" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
        let names = ["Alex", "Sam", "Jo", "Robin"]
        try await service.createGame(gameID: gameID,
                                     seed: seed,
                                     creatorName: names[0],
                                     playerID: "test-player-1",
                                     packs: Set(BlurtPack.allCases))
        for index in 2...4 {
            try await service.joinGame(gameID: gameID, playerID: "test-player-\(index)", name: names[index - 1])
        }
        try await service.startGame(gameID: gameID, seed: seed)
        let room = await waitForRoom(service, gameID: gameID, count: 4, needsTeams: true)
        let snapshot = try XCTUnwrap(room, "the room was never dealt")
        return (gameID, try XCTUnwrap(snapshot.play))
    }

    /// "Got it — pass it on" moves the word to the other team.
    ///
    /// This is the one that was doing nothing on the phone while working in the
    /// browser, which made it worth reproducing against the real database rather
    /// than reasoning about.
    func testPassingTheWordMovesItToTheOtherTeam() async throws {
        try XCTSkipUnless(FirebaseBootstrapper.isConfigured, "No Firebase config bundled")

        let service = VibeBlurtService.shared
        let (gameID, before) = try await VibeBlurtTests.startedRoom(service)
        try await service.beginTurn(gameID: gameID, seconds: 60, describer: before.describer)

        let passed = await service.passWord(gameID: gameID)
        XCTAssertTrue(passed, "the pass was refused")

        let moved = await VibeBlurtTests.waitForSnapshot(service, gameID: gameID) {
            ($0.play?.turn ?? -1) > before.turn
        }
        let after = try XCTUnwrap(moved?.play, "the word never moved")

        XCTAssertEqual(after.turn, before.turn + 1)
        XCTAssertEqual(after.word, before.word + 1, "the next word")
        XCTAssertEqual(after.team, before.team.other, "it went to the other team")
        XCTAssertNotEqual(after.describer, before.describer, "and to a different person")
        XCTAssertEqual(after.state, .running, "and the clock kept running")
    }

    /// BUZZ ends the round and pays the team that pressed it.
    func testBuzzingEndsTheRoundAndPaysTheOtherTeam() async throws {
        try XCTSkipUnless(FirebaseBootstrapper.isConfigured, "No Firebase config bundled")

        let service = VibeBlurtService.shared
        let (gameID, before) = try await VibeBlurtTests.startedRoom(service)
        try await service.beginTurn(gameID: gameID, seconds: 60, describer: before.describer)

        let ended = await service.endTurn(gameID: gameID, reason: .blurt)
        XCTAssertTrue(ended, "the buzz was refused")

        let endedRoom = await VibeBlurtTests.waitForSnapshot(service, gameID: gameID) {
            $0.play?.state == .ended
        }
        let after = try XCTUnwrap(endedRoom?.play, "the round never ended")

        XCTAssertEqual(after.reason, .blurt)
        XCTAssertEqual(after.scorer, before.team.other, "the team that was not holding it")
        XCTAssertEqual(after.score(of: before.team), 0)
        XCTAssertEqual(after.score(of: before.team.other), 1)
    }

    /// The whole of what went wrong, against the real database.
    ///
    /// A room is played to the end of a round, and then the person who is up
    /// next tries to start the next one. That is the button that did nothing:
    /// the app refused before it ever reached the database, because a finished
    /// round leaves the state as `.ended` rather than `.ready` and the guard
    /// only allowed the latter.
    @MainActor
    func testTheNextRoundCanBeStartedAfterOneEnds() async throws {
        try XCTSkipUnless(FirebaseBootstrapper.isConfigured, "No Firebase config bundled")

        let service = VibeBlurtService.shared
        let gameID = "zz" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
        let me = VibeBlurtService.shortID(playerID: PlayerIdentity.id, gameID: gameID)

        try await service.createGame(gameID: gameID,
                                     seed: 52,
                                     creatorName: "Sam",
                                     playerID: PlayerIdentity.id,
                                     packs: Set(BlurtPack.allCases))
        for index in 1...3 {
            try await service.joinGame(gameID: gameID, playerID: "test-player-\(index)", name: "P\(index)")
        }
        try await service.startGame(gameID: gameID, seed: 52)

        // Exactly the state a finished round leaves behind: the result of the
        // last one, and the next one's rotation already set up behind it.
        let database = try XCTUnwrap(FirebaseBootstrapper.database)
        try await database.reference(withPath: "blurt/\(gameID)/play").setValue([
            "round": 0, "turn": 1, "team": 2, "describer": me, "word": 1,
            "state": "ended", "reason": "blurt", "scorer": 1,
            "one": 1, "two": 0, "finished": false,
        ])

        let model = VibeBlurtModel()
        model.submitName("Sam")
        await model.joinGame(code: gameID)

        let isUp = await VibeBlurtTests.waitUntil { model.play?.describer == me }
        XCTAssertTrue(isUp, "the device should have been told it is up next")
        XCTAssertEqual(model.play?.state, .ended, "and that the last round is over")

        await model.beginTurn()

        let started = await VibeBlurtTests.waitUntil { model.play?.state == .running }
        XCTAssertTrue(started, "the next round never started")
    }

    /// Waits for a condition, giving up rather than hanging the suite.
    @MainActor
    private static func waitUntil(timeout: TimeInterval = 12,
                                  _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(150))
        }
        return condition()
    }

    func testNonsenseFromTheDatabaseIsRefusedRatherThanCrashing() {
        XCTAssertNil(BlurtPlay(value: nil))
        XCTAssertNil(BlurtPlay(value: "not a dictionary"))
        XCTAssertNil(BlurtPlay(value: ["turn": 1]))
        XCTAssertNil(BlurtPlay(value: ["turn": 1, "team": 9, "describer": "x",
                                        "word": 0, "state": "running"]),
                     "a team of 9 is not a team")
    }
}
