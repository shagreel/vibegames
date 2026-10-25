import XCTest
@testable import VibeGames

/// The rules of Vibe Ten, without a screen.
final class VibeTenBoardTests: XCTestCase {

    /// A board with exactly the columns given, top-first.
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
        // Column 1 is empty, so the row the other two digits are on has a gap
        // between them.
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

    /// The board hangs from the top, so a gap closes upward: the digits below
    /// the pair rise into it.
    func testTakingAPairLiftsTheDigitsBelow() {
        var board = self.board([
            [3, 1, 2],
            [7, 4],
            [2]
        ])
        XCTAssertNotNil(board.take(.init(column: 0, row: 0), .init(column: 1, row: 0), mode: .remove))
        XCTAssertEqual(board.value(at: .init(column: 0, row: 0)), 1,
                       "the 1 below the 3 rose into its place")
        XCTAssertEqual(board.value(at: .init(column: 0, row: 1)), 2)
        XCTAssertEqual(board.height(ofColumn: 0), 2)
        XCTAssertEqual(board.height(ofColumn: 1), 1, "the 4 rose too")
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
            [2, 2, 2, 8, 4, 6, 1, 9, 2, 8, 4, 6, 7, 3, 5, 5, 5, 5],
            [6, 4, 4, 6, 2, 8, 7, 3, 3, 3, 1, 9, 9, 1, 2, 8, 3, 7],
            [6, 4, 4, 6, 4, 6, 3, 7, 8, 2, 2, 8, 2, 8, 3, 7, 1, 9],
            [4, 6, 6, 4, 3, 3, 5, 5, 6, 4, 9, 1, 2, 8, 8, 2, 9, 1],
            [1, 9, 3, 7, 1, 9, 9, 1, 1, 9, 1, 9, 1, 9, 8, 8, 3, 7],
            [1, 9, 9, 1, 4, 6, 7, 3, 2, 8, 7, 3, 7, 3, 2, 8, 9, 1],
            [2, 8, 4, 4, 9, 1, 6, 6, 7, 3, 7, 7, 5, 5, 1, 9, 5, 5],
            [6, 4, 2, 8, 5, 5, 7, 7, 4, 6, 8, 8, 3, 7, 2, 2, 6, 4],
            [7, 3, 1, 9, 6, 4, 4, 6, 7, 3, 2, 8, 5, 5, 5, 5, 5, 5]
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

    func testARowHangsUnderTheDigitsWithoutMovingThem() {
        var board = VibeTenBoard(stacks: [[1], [2], [3], [4], [5], [6], [7], [8], [9]])
        XCTAssertTrue(board.canAddRow)
        XCTAssertTrue(board.addRow([9, 8, 7, 6, 5, 4, 3, 2, 1]))
        XCTAssertEqual(board.value(at: .init(column: 0, row: 0)), 1,
                       "the digits stay where they were: the board hangs from the top")
        XCTAssertEqual(board.value(at: .init(column: 0, row: 1)), 9,
                       "the new row is underneath them")
        XCTAssertEqual(board.height(ofColumn: 0), 2)
    }

    func testAFullGridHasNowhereToPutOne() {
        var board = VibeTenBoard(seed: 7)
        XCTAssertFalse(board.canAddRow, "eighteen rows is the top of the grid")
        XCTAssertFalse(board.addRow(Array(repeating: 1, count: 9)))
    }

    func testARowIsAvailableOnlyWhenTheBottomOfTheGridIsFree() {
        // Every column one short of the last row: there is room underneath.
        var board = VibeTenBoard(stacks: Array(repeating: Array(repeating: 1, count: 17), count: 9))
        XCTAssertTrue(board.canAddRow)
        XCTAssertTrue(board.addRow(Array(repeating: 2, count: 9)))
        XCTAssertFalse(board.canAddRow, "the grid is full again")

        // One column still reaching the last row holds the new row back.
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

    func testABoardCanStartPartFilled() {
        let full = VibeTenBoard(seed: 4321)
        let third = VibeTenBoard(seed: 4321, startRows: 6)

        XCTAssertEqual(third.height(ofColumn: 0), 6, "a third of eighteen rows")
        for column in 0..<9 {
            XCTAssertEqual(third.values[column], Array(full.values[column].prefix(6)),
                           "the top slice of the same deal, hanging from the top")
        }
        XCTAssertEqual(third.remaining, 54)
        XCTAssertTrue(third.canAddRow, "and there is room below it")
        XCTAssertEqual(third.roomForRows, 12)
    }

    func testRowsAreAddedUnderTheDigitsAndGrowTheBoard() {
        var board = VibeTenBoard(seed: 77, startRows: 6)
        let before = board.values
        XCTAssertTrue(board.addRow([1, 2, 3, 4, 5, 6, 7, 8, 9]))
        XCTAssertEqual(board.height(ofColumn: 0), 7)
        for column in 0..<9 {
            XCTAssertEqual(Array(board.values[column].prefix(6)), before[column],
                           "nothing already on the board moved")
        }
        XCTAssertEqual(board.values[0].last, 1, "the new digits are the bottom row")
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
            [2, 2, 8, 2, 4, 6, 9, 1, 9, 1, 9, 1],
            [3, 7, 5, 5, 5, 5, 1, 9, 5, 5, 8, 2],
            [4, 4, 3, 7, 3, 7, 8, 8, 7, 7, 6, 6],
            [4, 6, 2, 2, 4, 6, 4, 6, 1, 9, 3, 3],
            [3, 7, 9, 1, 9, 1, 8, 8, 2, 8, 8, 2],
            [5, 5, 9, 1, 4, 6, 7, 7, 4, 6, 3, 3]
        ]
        XCTAssertEqual(VibeTenBoard(seed: 1234, columns: 6, rows: 12).values, expected)
    }
}


/// The rows joining end to end: the last square of a row is next to the first
/// square of the row below it.
final class VibeTenWrapTests: XCTestCase {

    /// Nine columns of two rows, top-first. A column can only hold its second
    /// digit if it holds its first, so the fixtures say what is above.
    private func board(_ columns: [[Int]], wrap: Bool = true) -> VibeTenBoard {
        var stacks = columns
        while stacks.count < 9 { stacks.append([]) }
        return VibeTenBoard(stacks: stacks, columns: 9, rows: 2, wrapRows: wrap)
    }

    /// Column 8 row 0 is a 5; column 0 row 1 is a 5, with a 7 above it.
    private func endsOfTheJoin() -> [[Int]] {
        var columns = [[Int]](repeating: [], count: 9)
        columns[0] = [7, 5]
        columns[8] = [5]
        return columns
    }

    func testTheTwoEndsOfARowJoinUp() {
        XCTAssertTrue(board(endsOfTheJoin())
                        .canMatch(.init(column: 8, row: 0), .init(column: 0, row: 1)),
                      "the last square of one row and the first of the next")
        XCTAssertFalse(board(endsOfTheJoin(), wrap: false)
                        .canMatch(.init(column: 8, row: 0), .init(column: 0, row: 1)),
                       "without the setting the rows do not join")
    }

    /// The owner's second example: the first square of the lower row is already
    /// taken, so the 5 at the end of the row above reaches the second square.
    func testATakenSquareInTheWayDoesNotBlockTheJoin() {
        var columns = [[Int]](repeating: [], count: 9)
        columns[0] = [1, 9]
        columns[1] = [2, 5]
        columns[8] = [5]

        let taken = VibeTenBoard(stacks: columns, columns: 9, rows: 2, wrapRows: true)
        XCTAssertFalse(taken.canMatch(.init(column: 8, row: 0), .init(column: 1, row: 1)),
                       "the 9 at the start of the lower row is in the way")

        var dimmed = columns.map { column -> [VibeTenCell] in
            column.enumerated().map { row, value in
                VibeTenCell(value: value, dimmed: column == columns[0] && row == 1)
            }
        }
        dimmed[8] = [VibeTenCell(value: 5)]
        let board = VibeTenBoard(cells: dimmed, columns: 9, rows: 2, wrapRows: true)
        XCTAssertTrue(board.canMatch(.init(column: 8, row: 0), .init(column: 1, row: 1)),
                      "the taken 9 no longer blocks the join")
    }

    func testTheJoinIsOnlyBetweenNeighbouringRows() {
        var columns = [[Int]](repeating: [], count: 9)
        columns[0] = [1, 2, 5]
        columns[8] = [5]
        let board = VibeTenBoard(stacks: columns, columns: 9, rows: 3, wrapRows: true)
        XCTAssertFalse(board.canMatch(.init(column: 8, row: 0), .init(column: 0, row: 2)),
                       "two rows apart is not a join")
    }

    func testAWrappedPairCanBeTaken() {
        var board = board(endsOfTheJoin())
        XCTAssertNotNil(board.take(.init(column: 8, row: 0), .init(column: 0, row: 1),
                                   mode: .remove))
        XCTAssertEqual(board.remaining, 1, "both 5s went, and the 7 stayed")
        XCTAssertEqual(board.value(at: .init(column: 0, row: 0)), 7)
    }

    func testTheSettingIsOffByDefault() {
        XCTAssertFalse(VibeTenBoard(seed: 1).wrapRows)
        let columns = endsOfTheJoin()
        let stacks = columns.map { $0.map { VibeTenCell(value: $0) } }
        XCTAssertFalse(VibeTenBoard(cells: stacks, columns: 9, rows: 2)
                        .canMatch(.init(column: 8, row: 0), .init(column: 0, row: 1)))
    }
}


/// Every board can be cleared.
///
/// The deal is built out of pairs, so it is not a board with a chance of being
/// finishable — it has a solution by construction. These tests play that
/// solution: the bottom pair of a column, again and again, until the board is
/// empty.
final class VibeTenSolutionTests: XCTestCase {

    private func bottomPair(_ board: VibeTenBoard) -> (VibeTenBoard.Position, VibeTenBoard.Position)? {
        for column in 0..<board.columns {
            let height = board.height(ofColumn: column)
            guard height >= 2 else { continue }
            let lower = VibeTenBoard.Position(column: column, row: height - 2)
            let upper = VibeTenBoard.Position(column: column, row: height - 1)
            if board.canMatch(lower, upper) { return (lower, upper) }
        }
        return nil
    }

    func testEveryBoardCanBeClearedFromTheBottomOfItsColumns() {
        for seed in [UInt32(1), 7, 1234, 999, 424242] {
            for columns in VibeTenBoard.columnOptions {
                for rows in VibeTenBoard.rowOptions {
                    var board = VibeTenBoard(seed: seed, columns: columns, rows: rows)
                    var takes = 0
                    while !board.isCleared, takes < columns * rows / 2 {
                        guard let pair = bottomPair(board) else { break }
                        XCTAssertNotNil(board.take(pair.0, pair.1, mode: .remove))
                        takes += 1
                    }
                    XCTAssertTrue(board.isCleared,
                                  "seed \(seed) on \(columns)x\(rows) should be clearable")
                }
            }
        }
    }

    func testEveryColumnIsMadeOfNeighbouringPairs() {
        for columns in VibeTenBoard.columnOptions {
            for rows in VibeTenBoard.rowOptions {
                let board = VibeTenBoard(seed: 31, columns: columns, rows: rows)
                for column in 0..<columns {
                    let values = board.values[column]
                    XCTAssertEqual(values.count, rows)
                    for index in stride(from: 0, to: values.count, by: 2) {
                        XCTAssertTrue(VibeTenBoard.valuesPair(values[index], values[index + 1]),
                                      "\(columns)x\(rows) column \(column) rows \(index), \(index + 1)")
                    }
                }
            }
        }
    }

    func testAPartFilledBoardCanStillBeCleared() {
        for rows in VibeTenBoard.rowOptions {
            var board = VibeTenBoard(seed: 1234, columns: 9, rows: rows, startRows: rows / 3)
            var takes = 0
            while !board.isCleared, takes < 9 * rows {
                guard let pair = bottomPair(board) else { break }
                XCTAssertNotNil(board.take(pair.0, pair.1, mode: .remove))
                takes += 1
            }
            XCTAssertTrue(board.isCleared, "a third-filled board on \(rows) rows should clear")
        }
    }
}
