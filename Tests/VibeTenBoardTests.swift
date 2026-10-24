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
        XCTAssertNotNil(board.take(.init(column: 0, row: 0), .init(column: 1, row: 0), mode: .remove))
        XCTAssertEqual(board.value(at: .init(column: 0, row: 0)), 1,
                       "the 1 above the 3 fell into its place")
        XCTAssertEqual(board.value(at: .init(column: 0, row: 1)), 2)
        XCTAssertEqual(board.height(ofColumn: 0), 2)
        XCTAssertEqual(board.height(ofColumn: 1), 1, "the 4 fell too")
    }

    func testTakingTwoFromOneColumnLeavesTheRestInOrder() {
        var board = self.board([[2, 8, 5]])
        XCTAssertNotNil(board.take(.init(column: 0, row: 0), .init(column: 0, row: 1), mode: .remove))
        XCTAssertEqual(board.values[0], [5])
    }

    func testAnIllegalPairIsRefusedAndChangesNothing() {
        var board = self.board([[2, 5], [6]])
        let before = board
        XCTAssertNil(board.take(.init(column: 0, row: 0), .init(column: 1, row: 0), mode: .remove))
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
        XCTAssertNotNil(board.take(.init(column: 0, row: 0), .init(column: 1, row: 0), mode: .remove))
        XCTAssertTrue(board.isCleared)
        XCTAssertEqual(board.remaining, 0)
    }

    // MARK: - Dealing

    func testANewBoardIsNineByEighteen() {
        let board = VibeTenBoard(seed: 42)
        XCTAssertEqual(board.stacks.count, 9)
        for column in board.stacks {
            XCTAssertEqual(column.count, 18, "every column starts full")
            XCTAssertTrue(column.allSatisfy { (1...9).contains($0.value) }, "digits 1 to 9 only")
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
        XCTAssertEqual(VibeTenBoard(seed: 1234).values, expected)
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

/// The other way a pair can leave the board: dimmed, not gone.
final class VibeTenDimTests: XCTestCase {

    private func board(_ columns: [[Int]]) -> VibeTenBoard {
        VibeTenBoard(stacks: columns)
    }

    func testAPairIsDimmedRatherThanRemoved() {
        var board = self.board([[3, 1], [7, 4]])
        let result = board.take(.init(column: 0, row: 0), .init(column: 1, row: 0), mode: .dim)
        XCTAssertEqual(result?.rowsCleared, [])
        XCTAssertEqual(board.value(at: .init(column: 0, row: 0)), 3, "the digit is still there")
        XCTAssertTrue(board.isDimmed(at: .init(column: 0, row: 0)))
        XCTAssertTrue(board.isDimmed(at: .init(column: 1, row: 0)))
        XCTAssertEqual(board.remaining, 2, "but it no longer counts")
    }

    func testADimmedDigitIsMissingForTheRules() {
        var board = self.board([[3, 9], [9, 7], [7, 1]])
        // 3 and 7 pair, but the 9 in column 1 row 0 is in the way.
        XCTAssertFalse(board.canMatch(.init(column: 0, row: 0), .init(column: 2, row: 0)))
        // Take the blocking 9 with the 1 above it? They do not pair. Take the
        // row's 9 and 1 instead: no. Dim a pair that clears the way: 9 (col 1
        // row 0) with 1 (col 2 row 1) — a diagonal neighbour.
        XCTAssertNotNil(board.take(.init(column: 1, row: 0), .init(column: 2, row: 1), mode: .dim))
        XCTAssertTrue(board.canMatch(.init(column: 0, row: 0), .init(column: 2, row: 0)),
                      "the dimmed 9 no longer blocks the line")
    }

    func testAWholeDimmedRowClearsAndEverythingDropsOne() {
        // The bottom row, column by column: 1 9 2 8 3 7 4 6 5. Eight of them go
        // in four pairs along the row; the 5 in the last column pairs with the
        // 5 that sits above the 6. The row above is never finished, so it just
        // drops one row.
        var board = self.board([
            [1, 9], [9, 8], [2, 7], [8, 6], [3, 5], [7, 4], [4, 3], [6, 5], [5, 1]
        ])
        let pairs: [(VibeTenBoard.Position, VibeTenBoard.Position)] = [
            (.init(column: 0, row: 0), .init(column: 1, row: 0)),
            (.init(column: 2, row: 0), .init(column: 3, row: 0)),
            (.init(column: 4, row: 0), .init(column: 5, row: 0)),
            (.init(column: 6, row: 0), .init(column: 7, row: 0))
        ]
        for (left, right) in pairs {
            XCTAssertNotNil(board.take(left, right, mode: .dim))
        }
        XCTAssertEqual(board.height(ofColumn: 0), 2, "not cleared until the last digit of the row")

        // The 5 in column 8 takes the 5 diagonally above it, finishing the row.
        let result = board.take(.init(column: 8, row: 0), .init(column: 7, row: 1), mode: .dim)
        XCTAssertEqual(result?.rowsCleared, [0], "the completed row clears")
        XCTAssertEqual(board.height(ofColumn: 0), 1, "and everything above drops one")
        XCTAssertEqual(board.value(at: .init(column: 0, row: 0)), 9, "the row above is the bottom now")
    }

    func testTakenDigitsCannotBeTakenAgain() {
        var board = self.board([[2], [8], [2]])
        XCTAssertNotNil(board.take(.init(column: 0, row: 0), .init(column: 1, row: 0), mode: .dim))
        XCTAssertFalse(board.canMatch(.init(column: 0, row: 0), .init(column: 1, row: 0)))
    }

    func testClearingTheBoardMeansEveryRowWent() {
        // Two rows, every digit paired with the one above it: when the last pair
        // dims, both rows are finished and the board is empty.
        var board = self.board([
            [1, 9], [2, 8], [3, 7], [4, 6], [5, 5], [6, 4], [7, 3], [8, 2], [9, 1]
        ])
        for column in 0..<board.columns {
            XCTAssertNotNil(board.take(.init(column: column, row: 0),
                                       .init(column: column, row: 1), mode: .dim))
        }
        XCTAssertTrue(board.isCleared, "every row is gone")
        XCTAssertEqual(board.remaining, 0, "and nothing is left to take")
    }
}

/// Adding a row at the bottom.
final class VibeTenAddRowTests: XCTestCase {

    func testARowGoesOnTheBottomAndPushesEverythingUp() {
        var board = VibeTenBoard(stacks: [[1], [2], [3], [4], [5], [6], [7], [8], [9]])
        XCTAssertTrue(board.canAddRow)
        XCTAssertTrue(board.addRow([9, 8, 7, 6, 5, 4, 3, 2, 1]))
        XCTAssertEqual(board.value(at: .init(column: 0, row: 0)), 9, "the new row is at the bottom")
        XCTAssertEqual(board.value(at: .init(column: 0, row: 1)), 1, "the old row moved up")
        XCTAssertEqual(board.height(ofColumn: 0), 2)
    }

    func testAFullGridHasNowhereToPutOne() {
        var board = VibeTenBoard(seed: 7)
        XCTAssertFalse(board.canAddRow, "eighteen rows is the top of the grid")
        XCTAssertFalse(board.addRow(Array(repeating: 1, count: 9)))
    }

    func testARowIsAvailableOnlyWhenNoColumnReachesTheTop() {
        // Every column one short of the top row: there is room to push up.
        var board = VibeTenBoard(stacks: Array(repeating: Array(repeating: 1, count: 17), count: 9))
        XCTAssertTrue(board.canAddRow)
        XCTAssertTrue(board.addRow(Array(repeating: 2, count: 9)))
        XCTAssertFalse(board.canAddRow, "the grid is full again")

        // One column still touching the top row holds the new row back.
        let tall = VibeTenBoard(stacks: (0..<9).map {
            Array(repeating: 3, count: $0 == 4 ? 18 : 17)
        })
        XCTAssertFalse(tall.canAddRow, "a single digit on the top row is in the way")
    }
}

/// The board's shape: how many columns and rows a game is dealt with.
final class VibeTenShapeTests: XCTestCase {

    func testEveryShapeDealsAFullGrid() {
        for columns in VibeTenBoard.columnOptions {
            for rows in VibeTenBoard.rowOptions {
                let board = VibeTenBoard(seed: 12_345, columns: columns, rows: rows)
                XCTAssertEqual(board.columns, columns)
                XCTAssertEqual(board.rows, rows)
                XCTAssertEqual(board.values.count, columns, "\(columns)x\(rows): columns")
                for column in board.values {
                    XCTAssertEqual(column.count, rows, "\(columns)x\(rows): rows")
                    XCTAssertTrue(column.allSatisfy { (1...9).contains($0) },
                                  "\(columns)x\(rows): digits one to nine")
                }
                XCTAssertEqual(board.remaining, columns * rows)
            }
        }
    }

    /// Nine values into a grid that is not a multiple of nine: as even as the
    /// shape allows, so a smaller board is still the same game.
    func testTheDigitsAreSpreadAsEvenlyAsTheShapeAllows() {
        for columns in VibeTenBoard.columnOptions {
            for rows in VibeTenBoard.rowOptions {
                let total = columns * rows
                let counts = VibeTenBoard(seed: 99, columns: columns, rows: rows)
                    .values.flatMap { $0 }
                    .reduce(into: [Int: Int]()) { $0[$1, default: 0] += 1 }

                XCTAssertEqual(counts.count, 9, "\(columns)x\(rows): every digit is there")
                let smallest = counts.values.min() ?? 0
                let largest = counts.values.max() ?? 0
                XCTAssertLessThanOrEqual(largest - smallest, 1,
                                         "\(columns)x\(rows): counts should differ by at most one")
                XCTAssertEqual(counts.values.reduce(0, +), total)
            }
        }
    }

    func testTheShapeIsPartOfTheDeal() {
        XCTAssertEqual(VibeTenBoard(seed: 7, columns: 6, rows: 12).values,
                       VibeTenBoard(seed: 7, columns: 6, rows: 12).values)
        XCTAssertNotEqual(VibeTenBoard(seed: 7, columns: 6, rows: 12).values,
                          VibeTenBoard(seed: 7, columns: 6, rows: 14).values,
                          "two rows more is a different board")
        XCTAssertNotEqual(VibeTenBoard(seed: 7, columns: 6, rows: 12).values,
                          VibeTenBoard(seed: 8, columns: 6, rows: 12).values,
                          "and so is another seed")
        // The default is the board the game shipped with: nine by eighteen.
        XCTAssertEqual(VibeTenBoard(seed: 7).values,
                       VibeTenBoard(seed: 7, columns: 9, rows: 18).values)
    }

    func testASmallerBoardIsFullUntilItIsNot() {
        var board = VibeTenBoard(seed: 31, columns: 6, rows: 12)
        XCTAssertFalse(board.canAddRow, "twelve rows of six is full")

        for _ in 0..<6 {
            guard let pair = board.availableMatches().first else { break }
            board.take(pair.0, pair.1, mode: .remove)
        }
        XCTAssertLessThan(board.height(ofColumn: 0), 12)
    }

    /// A row is complete when every column of *this* board has been dimmed in
    /// it — six columns is a whole row on a six-column board.
    func testARowClearsAcrossTheBoardsOwnColumns() {
        // Six columns, so six dimmed digits in the bottom row is a whole row:
        // 1+9, 2+8, 3+7.
        var board = VibeTenBoard(stacks: [[1, 9], [9, 8], [2, 7], [8, 6], [3, 5], [7, 4]],
                                 columns: 6, rows: 2)
        for (left, right) in [(0, 1), (2, 3)] {
            XCTAssertNotNil(board.take(.init(column: left, row: 0),
                                       .init(column: right, row: 0), mode: .dim))
        }
        XCTAssertEqual(board.height(ofColumn: 0), 2, "four of six is not a row")

        let result = board.take(.init(column: 4, row: 0), .init(column: 5, row: 0), mode: .dim)
        XCTAssertEqual(result?.rowsCleared, [0], "the sixth column completes the row")
        XCTAssertEqual(board.height(ofColumn: 0), 1)
    }

    /// The app and the browser have to deal the same small board from the same
    /// number, or a room of six-column games is two different games.
    func testASmallerBoardMatchesTheFixtureTheWebUses() {
        let expected: [[Int]] = [
            [7, 6, 3, 4, 7, 7, 5, 3, 4, 8, 1, 4],
            [2, 7, 9, 9, 8, 9, 4, 6, 5, 1, 3, 3],
            [6, 1, 7, 2, 1, 5, 3, 5, 1, 8, 3, 8],
            [6, 2, 8, 4, 8, 6, 2, 2, 5, 9, 6, 1],
            [4, 5, 4, 2, 1, 9, 9, 8, 8, 5, 7, 1],
            [7, 7, 5, 6, 6, 3, 4, 9, 3, 9, 2, 2]
        ]
        XCTAssertEqual(VibeTenBoard(seed: 1234, columns: 6, rows: 12).values, expected)
    }
}
