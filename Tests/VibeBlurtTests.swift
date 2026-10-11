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

    func testNonsenseFromTheDatabaseIsRefusedRatherThanCrashing() {
        XCTAssertNil(BlurtPlay(value: nil))
        XCTAssertNil(BlurtPlay(value: "not a dictionary"))
        XCTAssertNil(BlurtPlay(value: ["turn": 1]))
        XCTAssertNil(BlurtPlay(value: ["turn": 1, "team": 9, "describer": "x",
                                        "word": 0, "state": "running"]),
                     "a team of 9 is not a team")
    }
}
