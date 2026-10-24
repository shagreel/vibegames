import XCTest
@testable import VibeGames

/// The rules of Vibe Ten, without a screen.
final class VibeTenBoardTests: XCTestCase {

    /// A board with exactly the columns given, bottom-first.
    private func board(_ columns: [[Int]]) -> VibeTenBoard {
        VibeTenBoard(stacks: columns)
    }

    // MARK: - What pairs

    func testTheDigitsPairWhenEqualOrAddToTen() {
        let board = self.board([
            [3, 7, 2, 2, 5, 9, 1, 4, 6],
            [3, 7, 2, 2, 5, 9, 1, 4, 6]
        ])
        // Same row: 3 and 7 add to ten, 2 and 2 are equal.
        XCTAssertTrue(board.canMatch(.init(column: 0, row: 0), .init(column: 1, row: 1)))
        XCTAssertTrue(board.canMatch(.init(column: 0, row: 2), .init(column: 1, row: 3)))
        // 4 and 1 sit next to each other, but do not pair.
        XCTAssertFalse(board.canMatch(.init(column: 0, row: 7), .init(column: 1, row: 6)))
    }

    func testTwoInTheSameColumnHaveToBeNeighbours() {
        let board = self.board([[2, 8, 2]])
        XCTAssertTrue(board.canMatch(.init(column: 0, row: 0), .init(column: 0, row: 1)),
                      "2 and 8 are neighbours in the column")
        XCTAssertFalse(board.canMatch(.init(column: 0, row: 0), .init(column: 0, row: 2)),
                       "there is a digit between them")
    }

    func testAGapCanBeJumpedIfItIsEmpty() {
        // Column 1 is shorter, so the bottom row of the board has a gap at
        // column 1 and two digits on either side of it on the same row.
        let board = self.board([[3], [], [7]])
        XCTAssertTrue(board.canMatch(.init(column: 0, row: 0), .init(column: 2, row: 0)),
                      "3 and 7 either side of an empty column, on the same row")
    }

    func testAFilledCellBlocksTheLine() {
        let board = self.board([[3, 1], [9], [7]])
        XCTAssertFalse(board.canMatch(.init(column: 0, row: 0), .init(column: 2, row: 0)),
                       "the 9 in the middle is in the way")
    }

    func testDiagonalsCount() {
        let board = self.board([[4], [6], [1]])
        XCTAssertFalse(board.canMatch(.init(column: 0, row: 0), .init(column: 1, row: 1)),
                       "there is no cell at 1,1")
        // A diagonal of two neighbours: 4 at (0,0) and 6 at (1,1).
        let diagonal = self.board([[4], [0, 6]])
        XCTAssertTrue(diagonal.canMatch(.init(column: 0, row: 0), .init(column: 1, row: 1)),
                      "4 and 6 touch on the diagonal")
    }

    // MARK: - Gravity

    func testTakingAPairDropsWhatWasAbove() {
        var board = self.board([
            [3, 1, 2],
            [7, 4],
            [2]
        ])
        XCTAssertTrue(board.remove(.init(column: 0, row: 0), .init(column: 1, row: 0)))
        XCTAssertEqual(board.value(at: .init(column: 0, row: 0)), 1,
                       "the 1 above the 3 fell into its place")
        XCTAssertEqual(board.value(at: .init(column: 0, row: 1)), 2)
        XCTAssertEqual(board.height(ofColumn: 0), 2)
        XCTAssertEqual(board.height(ofColumn: 1), 1, "the 4 fell too")
    }

    func testTakingTwoFromOneColumnLeavesTheRestInOrder() {
        var board = self.board([[2, 8, 5]])
        XCTAssertTrue(board.remove(.init(column: 0, row: 0), .init(column: 0, row: 1)))
        XCTAssertEqual(board.stacks[0], [5])
    }

    func testAnIllegalPairIsRefusedAndChangesNothing() {
        var board = self.board([[2, 5], [6]])
        let before = board
        XCTAssertFalse(board.remove(.init(column: 0, row: 0), .init(column: 1, row: 0)))
        XCTAssertEqual(board, before)
    }

    // MARK: - The end

    func testABoardWithNoPairsHasNoMoves() {
        let board = self.board([[2], [5], [6]])
        XCTAssertFalse(board.hasMoves)
    }

    func testAClearedBoardIsEmpty() {
        var board = self.board([[3], [7]])
        XCTAssertFalse(board.isCleared)
        XCTAssertTrue(board.remove(.init(column: 0, row: 0), .init(column: 1, row: 0)))
        XCTAssertTrue(board.isCleared)
        XCTAssertEqual(board.remaining, 0)
    }

    // MARK: - Dealing

    func testANewBoardIsNineByEighteen() {
        let board = VibeTenBoard(seed: 42)
        XCTAssertEqual(board.stacks.count, 9)
        for column in board.stacks {
            XCTAssertEqual(column.count, 18, "every column starts full")
            XCTAssertTrue(column.allSatisfy { (1...9).contains($0) }, "digits 1 to 9 only")
        }
        XCTAssertEqual(board.remaining, 162)
    }

    func testTheSameSeedDealsTheSameBoard() {
        XCTAssertEqual(VibeTenBoard(seed: 99), VibeTenBoard(seed: 99))
        XCTAssertNotEqual(VibeTenBoard(seed: 99), VibeTenBoard(seed: 100),
                          "a different seed, a different board")
    }

    /// The browser deals from the same seed, so one board is pinned against a
    /// fixture both engines share.
    func testTheDealMatchesTheFixtureTheWebUses() {
        let expected: [[Int]] = [
            [7, 6, 2, 3, 1, 7, 5, 3, 4, 8, 2, 4, 8, 6, 9, 9, 7, 8],
            [3, 6, 4, 2, 2, 3, 5, 7, 1, 7, 5, 3, 1, 3, 6, 7, 7, 8],
            [4, 9, 1, 6, 8, 2, 4, 9, 5, 9, 1, 7, 5, 5, 6, 4, 9, 1],
            [2, 3, 3, 4, 4, 8, 4, 6, 4, 5, 2, 5, 6, 9, 9, 2, 5, 2],
            [9, 7, 1, 1, 7, 8, 4, 7, 9, 3, 2, 6, 3, 2, 7, 7, 6, 6],
            [1, 2, 7, 9, 1, 5, 5, 5, 4, 8, 8, 1, 3, 5, 6, 6, 7, 2],
            [3, 1, 2, 6, 4, 8, 3, 9, 8, 8, 9, 2, 3, 9, 5, 8, 3, 6],
            [1, 8, 2, 8, 5, 4, 6, 5, 4, 9, 8, 9, 1, 3, 4, 4, 7, 7],
            [3, 9, 8, 2, 1, 1, 4, 8, 5, 1, 5, 3, 2, 7, 6, 6, 1, 9]
        ]
        XCTAssertEqual(VibeTenBoard(seed: 1234).stacks, expected)
    }
}

/// The scoreboard rule: most pairs wins, and a tie goes to whoever ran out of
/// moves first.
final class VibeTenStandingTests: XCTestCase {

    private func standing(_ name: String, _ score: Int, finished: Int64?) -> VibeTenStanding {
        VibeTenStanding(id: name, name: name, score: score, finishedAt: finished)
    }

    func testMorePairsWins() {
        let ranked = [standing("Alex", 12, finished: 100),
                      standing("Sam", 18, finished: 200)].sorted(by: vibeTenRank)
        XCTAssertEqual(ranked.map(\.name), ["Sam", "Alex"])
    }

    func testATieGoesToWhoeverFinishedFirst() {
        let ranked = [standing("Alex", 12, finished: nil),
                      standing("Sam", 12, finished: 500),
                      standing("Kit", 12, finished: 200)].sorted(by: vibeTenRank)
        XCTAssertEqual(ranked.map(\.name), ["Kit", "Sam", "Alex"],
                       "finished first wins the tie; somebody still playing is last")
    }
}
