import XCTest
@testable import VibeGames

/// Vibe Blurt's rules.
///
/// The rules are the part worth pinning: the words come from a seed, and the
/// scoring is the whole game — the team *not* holding the word takes the point.
/// If that were backwards the game would still "work" and be completely wrong,
/// which is exactly the sort of thing a test is for.
final class VibeBlurtTests: XCTestCase {

    // MARK: - The content

    func testTheDeckIsThreeHundredDistinctThingsToDescribe() {
        let words = BlurtWords.all

        XCTAssertEqual(words.count, 300, "the deck size the fixtures were dumped for")
        XCTAssertEqual(Set(words).count, words.count, "a repeated word is a wasted turn")
        XCTAssertFalse(words.contains(""), "an empty entry would draw a blank screen")

        for word in words {
            XCTAssertTrue(word.allSatisfy(\.isASCII), "\(word) is not plain ASCII")
            XCTAssertFalse(word.contains("\""), "\(word) would break the Swift literal")
            let pieces = word.split(separator: " ")
            XCTAssertTrue((1...3).contains(pieces.count), "\(word) is not 1-3 words")
        }
    }

    // MARK: - The deck

    func testTheSameSeedDealsTheSameWordsEverywhere() {
        let all = Set(BlurtPack.allCases)
        let first = BlurtDeck.shuffled(seed: 42, round: 0, packs: all)
        let second = BlurtDeck.shuffled(seed: 42, round: 0, packs: all)

        XCTAssertEqual(first, second, "a shared game depends on this being stable")
        XCTAssertEqual(Set(first).count, BlurtWords.all.count, "a shuffle, not a filter")
    }

    func testDifferentSeedsDealDifferentHands() {
        let all = Set(BlurtPack.allCases)
        XCTAssertNotEqual(BlurtDeck.shuffled(seed: 1, round: 0, packs: all),
                          BlurtDeck.shuffled(seed: 2, round: 0, packs: all))
    }

    func testPlayAgainDealsFromADifferentPlaceWithoutANewSeed() {
        // The round, not a new seed, is what makes the second game different.
        let all = Set(BlurtPack.allCases)
        XCTAssertNotEqual(BlurtDeck.shuffled(seed: 7, round: 0, packs: all),
                          BlurtDeck.shuffled(seed: 7, round: 1, packs: all))
        XCTAssertEqual(BlurtDeck.shuffled(seed: 7, round: 1, packs: all),
                       BlurtDeck.shuffled(seed: 7, round: 1, packs: all))
    }

    func testTheDeckWrapsRatherThanRunningOut() {
        let deck = BlurtDeck.shuffled(seed: 3, round: 0, packs: Set(BlurtPack.allCases))

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
        XCTAssertEqual(BlurtWords.all.count, 300)
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
        let deck = BlurtDeck.shuffled(seed: 11, round: 0, packs: [.food])
        XCTAssertEqual(Set(deck), Set(FoodWords.all))
    }

    func testTheDeckDependsOnThePacksAsWellAsTheSeed() {
        let all = BlurtDeck.shuffled(seed: 5, round: 0, packs: Set(BlurtPack.allCases))
        let some = BlurtDeck.shuffled(seed: 5, round: 0, packs: [.food])
        XCTAssertNotEqual(all, some)
    }

    // MARK: - Turn length

    func testTheOfferedTurnLengthsAreSensible() {
        XCTAssertFalse(BlurtDuration.allCases.isEmpty)
        for option in BlurtDuration.allCases {
            XCTAssertGreaterThanOrEqual(option.rawValue, 10, "a turn nobody could play")
            XCTAssertLessThanOrEqual(option.rawValue, 600, "a turn nobody would wait for")
            XCTAssertFalse(option.title.isEmpty)
            XCTAssertFalse(option.blurb.isEmpty)
        }
        XCTAssertEqual(BlurtDuration.default, .standard)
    }

    func testAnUnexpectedDurationBecomesTheNearestOneOffered() {
        XCTAssertEqual(BlurtDuration.nearest(to: 0), .brisk)
        XCTAssertEqual(BlurtDuration.nearest(to: 30), .brisk)
        XCTAssertEqual(BlurtDuration.nearest(to: 45), .brisk, "equidistant, and the shorter wins")
        XCTAssertEqual(BlurtDuration.nearest(to: 61), .standard)
        XCTAssertEqual(BlurtDuration.nearest(to: 600), .long)
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
                                     packs: Set(BlurtPack.allCases),
                                     turnSeconds: 60)
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
                                     packs: [.food, .play],
                                     turnSeconds: 30)
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
        XCTAssertEqual(room.turnSeconds, 30, "the room kept its own turn length")
        XCTAssertEqual(room.packs, Set([.food, .play]), "and its own packs")
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
                                     packs: Set(BlurtPack.allCases),
                                     turnSeconds: 60)
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
        try await service.beginTurn(gameID: gameID, seconds: 60)

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
        try await service.beginTurn(gameID: gameID, seconds: 60)

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

    func testNonsenseFromTheDatabaseIsRefusedRatherThanCrashing() {
        XCTAssertNil(BlurtPlay(value: nil))
        XCTAssertNil(BlurtPlay(value: "not a dictionary"))
        XCTAssertNil(BlurtPlay(value: ["turn": 1]))
        XCTAssertNil(BlurtPlay(value: ["turn": 1, "team": 9, "describer": "x",
                                        "word": 0, "state": "running"]),
                     "a team of 9 is not a team")
    }
}
