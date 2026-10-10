import XCTest
@testable import VibeGames

/// Solo play exercises the same board, the same judge and the same end state as
/// a race, without needing a network. A shared game's only extra is the server
/// agreeing who was first.
@MainActor
final class VibeTrioModelTests: XCTestCase {

    func testSoloGameStartsWithAFullTableAndTheClockRunning() {
        let model = VibeTrioModel()
        model.playSolo()

        XCTAssertEqual(model.session, .solo)

        // Twelve, *or more*. The opening deal is twelve cards, but the table
        // deals another row whenever those twelve hold no trio, so a full table
        // is 12 + 3n and is not always 12. About one seed in thirty opens
        // larger — a flat `== 12` here fails on roughly that many runs, which
        // is exactly often enough to be dismissed as flake.
        let extra = model.table?.extraDeals ?? 0
        XCTAssertGreaterThanOrEqual(model.cardCount, 12, "a game opens with at least twelve cards")
        XCTAssertEqual(model.cardCount, 12 + extra * 3, "grown a row at a time")
        XCTAssertEqual(model.table?.hasTrio, true, "and always with something to take")

        XCTAssertEqual(model.myScore, 0)
        XCTAssertFalse(model.isShared)
        XCTAssertEqual(model.standings, [], "nobody has scored yet")
    }

    /// The three extra rows are not a quirk of one seed, so the deal is checked
    /// across a spread of them rather than once. Seeds 5, 66 and 88 open on
    /// fifteen and 8075 on eighteen.
    func testAnOpeningTableIsAlwaysPlayableHoweverItIsSeeded() {
        for seed in UInt32(0)..<400 {
            let table = TrioTable(seed: seed)
            XCTAssertGreaterThanOrEqual(table.visible.count, 12, "seed \(seed)")
            XCTAssertEqual(table.visible.count, 12 + table.extraDeals * 3, "seed \(seed)")
            if !table.remaining.isEmpty {
                XCTAssertTrue(table.hasTrio, "seed \(seed) left nothing to take")
            }
        }
    }

    func testAnInvalidSelectionIsRefusedAndLeavesTheBoardAlone() {
        let model = VibeTrioModel()
        model.playSolo()

        guard let table = model.table, let pick = firstNonTrio(in: table) else {
            return XCTFail("no table")
        }

        for index in pick { model.tap(index) }

        XCTAssertEqual(model.myScore, 0, "a near miss must not score")
        XCTAssertEqual(model.rejected, Set(pick), "the three are shown in red")
        XCTAssertEqual(model.selected, pick, "and stay selected until the flash ends")
    }

    func testTappingTheSameCardTwiceDeselectsIt() {
        let model = VibeTrioModel()
        model.playSolo()

        model.tap(0)
        XCTAssertEqual(model.selected, [0])
        model.tap(0)
        XCTAssertEqual(model.selected, [], "a second tap takes the card back")
    }

    /// Plays a whole solo game the way a good player would — always taking a trio
    /// that is really there — and checks the end state the leaderboard reads.
    func testPlayingOutTheDeckFinishesAndScoringHolds() {
        let model = VibeTrioModel()
        model.playSolo()

        playOut(model)

        XCTAssertTrue(model.isFinished, "the deck should be cleared")
        XCTAssertFalse(model.canPlay, "and the board should close")
        XCTAssertGreaterThan(model.myScore, 0, "clearing the deck takes at least one trio")
        XCTAssertEqual(model.remainingInDeck, 0)

        XCTAssertEqual(model.standings.count, 1, "solo is a leaderboard of one")
        XCTAssertEqual(model.standings.first?.score, model.myScore)
        XCTAssertEqual(model.standings.first?.isMe, true)
        XCTAssertEqual(model.leaders.map(\.score), [model.myScore])
    }

    /// A hint narrows the search to one card and never scores by itself.
    func testAHintLightsOneCardAndScoresNothing() {
        let model = VibeTrioModel()
        model.playSolo()

        guard let lit = model.revealHint() else { return XCTFail("a fresh table has a trio") }

        XCTAssertEqual(model.selected, [lit], "exactly one card is lit")
        XCTAssertEqual(model.myScore, 0)
    }

    func testPlayAgainDealsAFreshGame() {
        let model = VibeTrioModel()
        model.playSolo()
        playOut(model)
        XCTAssertTrue(model.isFinished)

        let dealt = expectation(description: "a new game is dealt")
        Task {
            await model.playAgain()
            dealt.fulfill()
        }
        wait(for: [dealt], timeout: 5)

        XCTAssertFalse(model.isFinished, "a fresh deal should be playable")
        XCTAssertEqual(model.myScore, 0, "and the score starts over")
        XCTAssertGreaterThanOrEqual(model.cardCount, 12)
        XCTAssertTrue(model.selected.isEmpty)
    }

    // MARK: - Helpers

    private func playOut(_ model: VibeTrioModel) {
        var guardRail = 0
        while let table = model.table, let trio = table.availableTrios.first {
            guardRail += 1
            if guardRail > 100 { return XCTFail("the game would not finish") }
            for index in trio { model.tap(index) }
        }
    }

    private func firstNonTrio(in table: TrioTable) -> [Int]? {
        let count = table.visible.count
        for i in 0..<count {
            for j in (i + 1)..<count {
                for k in (j + 1)..<count {
                    if !TrioDeck.isTrio(table.visible[i], table.visible[j], table.visible[k]) {
                        return [i, j, k]
                    }
                }
            }
        }
        return nil
    }
}
