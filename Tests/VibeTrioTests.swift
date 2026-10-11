import XCTest
@testable import VibeGames

/// Vibe Trio is pure combinatorics, so the rules can be checked exhaustively
/// rather than by sampling. The card deck is small enough that every triple of
/// cards can be tested, which is the strongest guarantee available here.
final class TrioCardTests: XCTestCase {

    private let deck = TrioDeck.all

    func testDeckIsCompleteAndUnique() {
        XCTAssertEqual(deck.count, 81, "3 platters x 3 cheeses x 3 meats x 3 garnishes")
        XCTAssertEqual(Set(deck.map(\.id)).count, 81, "ids must be unique")
        XCTAssertEqual(Set(deck).count, 81, "no duplicate cards")
    }

    func testEveryCombinationAppearsExactlyOnce() {
        for base in PlatterBase.allCases {
            for cheese in Cheese.allCases {
                for meat in Meat.allCases {
                    for garnish in Garnish.allCases {
                        let card = TrioCard(base: base, cheese: cheese,
                                            meat: meat, garnish: garnish)
                        XCTAssertTrue(deck.contains(card), "missing \(card.spokenDescription)")
                    }
                }
            }
        }
    }

    // MARK: - The rule

    /// The independent formulation: a triple fails if any single feature has
    /// exactly two cards agreeing and the third not.
    private func matchesMagicRule(_ a: TrioCard, _ b: TrioCard, _ c: TrioCard) -> Bool {
        let features: [(Int, Int, Int)] = [
            (a.base.rawValue, b.base.rawValue, c.base.rawValue),
            (a.cheese.rawValue, b.cheese.rawValue, c.cheese.rawValue),
            (a.meat.rawValue, b.meat.rawValue, c.meat.rawValue),
            (a.garnish.rawValue, b.garnish.rawValue, c.garnish.rawValue),
        ]
        return features.allSatisfy { x, y, z in
            let allSame = (x == y && y == z)
            let allDifferent = (x != y && y != z && x != z)
            return allSame || allDifferent
        }
    }

    /// Both definitions, over every triple in the deck.
    func testBothDefinitionsAgreeOnEveryTriple() {
        var checked = 0
        for i in 0..<(deck.count - 2) {
            for j in (i + 1)..<(deck.count - 1) {
                for k in (j + 1)..<deck.count {
                    XCTAssertEqual(
                        TrioDeck.isTrio(deck[i], deck[j], deck[k]),
                        matchesMagicRule(deck[i], deck[j], deck[k]),
                        "disagreement on \(deck[i].spokenDescription) / "
                        + "\(deck[j].spokenDescription) / \(deck[k].spokenDescription)"
                    )
                    checked += 1
                }
            }
        }
        XCTAssertEqual(checked, 85_320, "C(81,3)")
    }

    /// A full deck contains 1,080 trios. This is a known constant, and it also
    /// falls out of the pair count below, so it is a strong check on the rule.
    func testFullDeckContains1080Trios() {
        var trios = 0
        for i in 0..<(deck.count - 2) {
            for j in (i + 1)..<(deck.count - 1) {
                for k in (j + 1)..<deck.count where TrioDeck.isTrio(deck[i], deck[j], deck[k]) {
                    trios += 1
                }
            }
        }
        XCTAssertEqual(trios, 1_080)
    }

    /// Every pair of cards is completed by exactly one third card. This is what
    /// makes a trio never ambiguous — and it cross-checks the 1,080 above:
    /// 1080 trios x 3 pairs each must equal C(81,2) = 3240.
    func testEveryPairHasExactlyOneCompletion() {
        var pairs = 0
        for i in 0..<(deck.count - 1) {
            for j in (i + 1)..<deck.count {
                let third = TrioDeck.completingCard(deck[i], deck[j])
                XCTAssertTrue(deck.contains(third), "completion outside the deck")
                XCTAssertTrue(TrioDeck.isTrio(deck[i], deck[j], third),
                              "\(deck[i].spokenDescription) + \(deck[j].spokenDescription) "
                              + "completed to \(third.spokenDescription), which is not a trio")
                pairs += 1
            }
        }
        XCTAssertEqual(pairs, 3_240)
        XCTAssertEqual(pairs, 1_080 * 3, "each trio contributes three pairs")
    }

    func testCompletionIsSymmetric() {
        for _ in 0..<200 {
            let a = deck.randomElement()!
            let b = deck.randomElement()!
            XCTAssertEqual(TrioDeck.completingCard(a, b), TrioDeck.completingCard(b, a))
        }
    }

    /// Three copies of one card satisfy the rule on paper — every feature is
    /// "all same" — so the game has to prevent it another way, by requiring
    /// three *distinct* cards. This test exists because an earlier version of
    /// the engine accepted `takeTrio(at: [0, 0, 0])`.
    func testIdenticalCardsSatisfyTheRuleButAreRefusedByTheTable() {
        let card = deck[0]
        XCTAssertTrue(TrioDeck.isTrio(card, card, card),
                      "The rule alone cannot reject this; the table must")

        var table = TrioTable(seed: 5)
        XCTAssertFalse(table.wouldFormTrio([0, 0, 0]))
        XCTAssertFalse(table.takeTrio(at: [0, 0, 0]), "three copies of one card is not a trio")
        XCTAssertEqual(table.triosTaken, 0)

        // The real guarantee: the cards on the table are always distinct.
        XCTAssertEqual(Set(table.visible.map(\.id)).count, table.visible.count)
    }

    func testAllSameFeatureTrioIsAccepted() {
        // Three cards identical except for the meat.
        let trio = Meat.allCases.map {
            TrioCard(base: .circle, cheese: .swiss, meat: $0, garnish: .grapes)
        }
        XCTAssertTrue(TrioDeck.isTrio(trio[0], trio[1], trio[2]))
    }

    func testAllDifferentFeatureTrioIsAccepted() {
        let trio = PlatterBase.allCases.enumerated().map { index, base in
            TrioCard(base: base,
                     cheese: Cheese.allCases[index],
                     meat: Meat.allCases[index],
                     garnish: Garnish.allCases[index])
        }
        XCTAssertTrue(TrioDeck.isTrio(trio[0], trio[1], trio[2]))
    }

    func testTwoMatchingOneDifferentIsRejected() {
        let a = TrioCard(base: .circle, cheese: .swiss, meat: .prosciutto, garnish: .grapes)
        let b = a
        let c = TrioCard(base: .circle, cheese: .swiss, meat: .salami, garnish: .grapes)
        XCTAssertFalse(TrioDeck.isTrio(a, b, c), "Only the meat differs, on one card")
    }
}

final class TrioTableTests: XCTestCase {

    func testOpeningDealIsTwelveCards() {
        for seed in UInt32(0)..<25 {
            let table = TrioTable(seed: seed)
            XCTAssertGreaterThanOrEqual(table.visible.count, 12)
            XCTAssertEqual(table.visible.count + table.remaining.count, 81,
                           "every card is either on the table or in the deck")
        }
    }

    /// The table must never sit there with no trio available and cards left.
    func testTableIsAlwaysPlayable() {
        for seed in UInt32(0)..<50 {
            let table = TrioTable(seed: seed)
            if table.remaining.isEmpty {
                continue
            }
            XCTAssertTrue(table.hasTrio,
                          "seed \(seed) dealt \(table.visible.count) cards with no trio")
        }
    }

    func testSameSeedProducesTheSameTable() {
        for seed in UInt32(0)..<20 {
            let first = TrioTable(seed: seed)
            let second = TrioTable(seed: seed)
            XCTAssertEqual(first.visible, second.visible)
            XCTAssertEqual(first.remaining, second.remaining)
        }
    }

    func testDifferentSeedsDiffer() {
        let tables = Set((UInt32(0)..<20).map { TrioTable(seed: $0).visible.map(\.id).description })
        XCTAssertGreaterThan(tables.count, 15, "seeds should not collapse to the same deal")
    }

    func testRejectsThreeCardsThatAreNotATrio() {
        var table = TrioTable(seed: 1)
        let notATrio = [0, 1, 2]
        if !table.wouldFormTrio(notATrio) {
            XCTAssertFalse(table.takeTrio(at: notATrio), "must refuse an invalid trio")
            XCTAssertEqual(table.triosTaken, 0)
        }
    }

    /// Plays every game to the end, always taking the first available trio, and
    /// checks the deck is consumed without ever dead-ending.
    func testAFullGameConsumesTheDeckWithoutDeadEnding() {
        for seed in UInt32(0)..<40 {
            var table = TrioTable(seed: seed)
            var steps = 0

            while !table.isFinished {
                guard let trio = table.availableTrios.first else {
                    XCTFail("seed \(seed): no trio with \(table.remaining.count) cards left")
                    break
                }
                XCTAssertTrue(table.takeTrio(at: trio), "seed \(seed): valid trio refused")
                steps += 1
                XCTAssertLessThan(steps, 40, "seed \(seed): game is not terminating")
            }

            XCTAssertEqual(table.triosTaken, steps)
            XCTAssertEqual(table.remaining.count, 0)
            XCTAssertFalse(table.hasTrio, "a finished table should have nothing left to find")
        }
    }

    func testTakingATrioReplacesTheCards() {
        var table = TrioTable(seed: 7)
        guard let trio = table.availableTrios.first else {
            return XCTFail("no trio to take")
        }
        let before = table.visible.count
        let deckBefore = table.remaining.count

        XCTAssertTrue(table.takeTrio(at: trio))

        XCTAssertEqual(table.triosTaken, 1)
        XCTAssertEqual(table.remaining.count, deckBefore - 3, "three cards come off the deck")
        XCTAssertGreaterThanOrEqual(table.visible.count, min(before, 12))
    }

    func testVisibleCardsAreAlwaysDistinct() {
        var table = TrioTable(seed: 3)
        while !table.isFinished {
            XCTAssertEqual(Set(table.visible.map(\.id)).count, table.visible.count,
                           "the same card appeared twice")
            guard let trio = table.availableTrios.first else { break }
            table.takeTrio(at: trio)
        }
    }
}

/// A shared game sends card ids, never positions and never a board. Every device
/// rebuilds the table from the seed and the takes the server accepted, so if
/// taking by id could disagree with taking by position — or if replay could
/// drift from playing straight through — two phones would show different cards.
/// These check that it cannot.
final class TrioSharedTableTests: XCTestCase {

    func testTakingByIDRemovesExactlyTheNamedCards() {
        var table = TrioTable(seed: 11)
        guard let trio = table.availableTrios.first else { return XCTFail("no trio") }
        let ids = trio.map { table.visible[$0].id }

        XCTAssertTrue(table.takeTrio(ids: ids))

        XCTAssertEqual(table.triosTaken, 1)
        for id in ids {
            XCTAssertFalse(table.visible.contains { $0.id == id },
                           "card \(id) was taken but is still face up")
        }
    }

    func testTakingByIDRefusesACardThatHasAlreadyGone() {
        var table = TrioTable(seed: 11)
        guard let trio = table.availableTrios.first else { return XCTFail("no trio") }
        let ids = trio.map { table.visible[$0].id }

        XCTAssertTrue(table.takeTrio(ids: ids))
        XCTAssertFalse(table.takeTrio(ids: ids), "the same three cards cannot be taken twice")
    }

    func testTakingByIDRefusesCardsThatAreNotATrio() {
        var table = TrioTable(seed: 5)
        let ids = [table.visible[0].id, table.visible[1].id, table.visible[2].id]
        if TrioDeck.isTrio(table.visible[0], table.visible[1], table.visible[2]) {
            return
        }
        XCTAssertFalse(table.takeTrio(ids: ids))
    }

    /// Card ids run 0…80; positions run 0…11. Asking "is this a trio?" with ids
    /// against positions is a mistake that refuses every claim, and it is
    /// invisible when the three ids happen to be small — so this pins the two
    /// apart by requiring trios whose cards are not even valid positions.
    func testATrioIsReadFromCardIDsAndNotFromPositions() {
        var sawIDsBeyondTheTable = false

        for seed in UInt32(1)...40 {
            let table = TrioTable(seed: seed)
            guard let trio = table.availableTrios.first else { continue }
            let ids = trio.map { table.visible[$0].id }

            XCTAssertTrue(table.wouldFormTrio(ids: ids), "seed \(seed): refused a real trio")

            if ids.contains(where: { $0 >= table.visible.count }) {
                sawIDsBeyondTheTable = true
                XCTAssertFalse(table.wouldFormTrio(ids),
                               "seed \(seed): ids were read as positions")
            }
        }

        XCTAssertTrue(sawIDsBeyondTheTable, "no seed named a card outside the twelve on show")
    }

    /// The load-bearing property: replaying the recorded takes lands on exactly
    /// the table the players were looking at, for every seed.
    func testReplayReproducesTheWholeGameCardForCard() {
        for seed in UInt32(1)...40 {
            var played = TrioTable(seed: seed)
            var takes: [[Int]] = []

            while let trio = played.availableTrios.first {
                takes.append(trio.map { played.visible[$0].id }.sorted())
                XCTAssertTrue(played.takeTrio(at: trio), "seed \(seed): the game refused its own trio")
            }

            let replayed = TrioTable.replay(seed: seed, takes: takes)
            XCTAssertEqual(replayed.visible.map(\.id), played.visible.map(\.id),
                           "seed \(seed): replay drifted from play")
            XCTAssertEqual(replayed.remaining.count, played.remaining.count, "seed \(seed)")
            XCTAssertEqual(replayed.triosTaken, played.triosTaken, "seed \(seed)")
            XCTAssertTrue(replayed.isFinished, "seed \(seed): clearing every trio should finish the deck")
            XCTAssertFalse(takes.isEmpty, "seed \(seed): a game with no trios at all")
        }
    }

    /// A take that names a card someone else already cleared must fail rather
    /// than remove a card that is not there — this is what a lost race looks
    /// like when the server hands the block a newer board.
    func testReplayIgnoresATakeThatLosesItsCards() {
        guard let board = Self.twoDisjointTrios() else {
            return XCTFail("no board with two disjoint trios to test with")
        }

        // The loser's take is replayed second, after the cards it wanted are gone.
        let replayed = TrioTable.replay(seed: board.seed, takes: [board.first, board.first])
        XCTAssertEqual(replayed.triosTaken, 1, "the same cards must not score twice")

        let sane = TrioTable.replay(seed: board.seed, takes: [board.first, board.second])
        XCTAssertEqual(sane.triosTaken, 2)
    }

    /// A board with two trios sharing no cards.
    ///
    /// Not every deal has one, and which seeds do is a property of the shuffle
    /// rather than of the rule under test — so this looks for one instead of
    /// naming a seed. Pinning seed 1 meant the test broke when the seeded
    /// generator was fixed, for a reason that had nothing to do with replays.
    private static func twoDisjointTrios() -> (seed: UInt32, first: [Int], second: [Int])? {
        for seed in UInt32(1)...200 {
            let table = TrioTable(seed: seed)
            let trios = table.availableTrios
            guard let first = trios.first else { continue }
            let firstIDs = first.map { table.visible[$0].id }.sorted()

            let second = trios.dropFirst().first { candidate in
                Set(candidate.map { table.visible[$0].id }).isDisjoint(with: firstIDs)
            }
            if let second {
                return (seed, firstIDs, second.map { table.visible[$0].id }.sorted())
            }
        }
        return nil
    }
}

/// The snapshot is the only thing the app reads from the database. It carries no
/// board and no score — both are derived, so the two can never disagree.
final class TrioSnapshotTests: XCTestCase {

    private let taken: [String: Any] = [
        "4": ["seq": 1, "by": "aaaa", "name": "Alex"],
        "9": ["seq": 1, "by": "aaaa", "name": "Alex"],
        "70": ["seq": 1, "by": "aaaa", "name": "Alex"],
        "5": ["seq": 2, "by": "bbbb", "name": "Sam"],
        "6": ["seq": 2, "by": "bbbb", "name": "Sam"],
        "7": ["seq": 2, "by": "bbbb", "name": "Sam"],
        "8": ["seq": 3, "by": "aaaa", "name": "Alex"],
        "12": ["seq": 3, "by": "aaaa", "name": "Alex"],
        "13": ["seq": 3, "by": "aaaa", "name": "Alex"],
    ]

    func testThreeCardsSharingASequenceAreOneTake() {
        let snapshot = TrioSnapshot(meta: ["seed": 123],
                                    players: ["aaaa": true, "bbbb": true],
                                    taken: taken)

        XCTAssertEqual(snapshot.takeIDs, [[4, 9, 70], [5, 6, 7], [8, 12, 13]],
                       "takes come back in the order the server accepted them")
        XCTAssertEqual(snapshot.takes.map(\.name), ["Alex", "Sam", "Alex"])
    }

    func testScoreIsHowManyTakesCarryYourID() {
        let snapshot = TrioSnapshot(meta: ["seed": 123], players: nil, taken: taken)

        XCTAssertEqual(snapshot.scores, ["aaaa": 2, "bbbb": 1])
    }

    func testNameComesFromTheTakeSoOnlyScorersHaveOne() {
        let snapshot = TrioSnapshot(meta: ["seed": 123],
                                    players: ["aaaa": true, "cccc": true],
                                    taken: taken)

        XCTAssertEqual(snapshot.playerCount, 2, "everyone present is counted")
        XCTAssertEqual(snapshot.name(of: "aaaa"), "Alex")
        XCTAssertNil(snapshot.name(of: "cccc"), "a player who has not scored has no name here")
    }

    func testSeedSurvivesTheRoundTrip() {
        let snapshot = TrioSnapshot(meta: ["seed": 4_000_000_000,
                                           "creator": "Alex",
                                           "started": true],
                                    players: nil,
                                    taken: nil)

        XCTAssertEqual(snapshot.seed, 4_000_000_000)
        XCTAssertEqual(snapshot.creator, "Alex")
        XCTAssertTrue(snapshot.started)
    }

    func testAnEmptyGameIsNotAFailure() {
        let snapshot = TrioSnapshot(meta: nil, players: nil, taken: nil)
        XCTAssertFalse(snapshot.exists)
        XCTAssertNil(snapshot.seed)
        XCTAssertEqual(snapshot.takeIDs, [])
        XCTAssertEqual(snapshot.scores, [:])
    }
}

final class TrioIdentityTests: XCTestCase {

    @MainActor
    func testShortIDIsStableAndScopedToTheGame() {
        let id = VibeTrioService.shortID(playerID: "player-1", gameID: "game-1")

        XCTAssertEqual(id.count, 8)
        XCTAssertEqual(id, VibeTrioService.shortID(playerID: "player-1", gameID: "game-1"))
        XCTAssertNotEqual(id, VibeTrioService.shortID(playerID: "player-1", gameID: "game-2"),
                          "the same person in another game is a different key")
        XCTAssertNotEqual(id, VibeTrioService.shortID(playerID: "player-2", gameID: "game-1"))
    }

    @MainActor
    func testShortIDsDoNotCollideAcrossManyPlayers() {
        let ids = (0..<500).map {
            VibeTrioService.shortID(playerID: "player-\($0)", gameID: "game-1")
        }
        XCTAssertEqual(Set(ids).count, 500, "a collision would merge two players' scores")
    }
}
