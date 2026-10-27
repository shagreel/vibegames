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

    /// The deal draws valid pairs — equal, or adding to ten — and then shuffles
    /// their digits onto the board.
    func testTheDealDrawsValidPairsAndLaysTheirDigitsOut() {
        for seed in [UInt32(1), 7, 1234, 999, 424242] {
            let count = VibeTenBoard.defaultColumns * VibeTenBoard.maximumRows / 2
            let pairs = VibeTenBoard.pairChoices(seed: seed, count: count)
            XCTAssertEqual(pairs.count, count)
            for pair in pairs {
                XCTAssertTrue(VibeTenBoard.valuesPair(pair.0, pair.1),
                              "\(seed): \(pair) is not a pair")
            }
            let full = VibeTenBoard.deal(seed: seed,
                                        columns: VibeTenBoard.defaultColumns,
                                        rows: VibeTenBoard.maximumRows)
            XCTAssertEqual(full.flatMap { $0 }.map(\.value).sorted(),
                           pairs.flatMap { [$0.0, $0.1] }.sorted(),
                           "the eighteen-row deal is those digits, laid out at random")

            // A starting board is the top of that one deal, not a shorter deal
            // of its own: the rows underneath are already drawn.
            for rows in VibeTenBoard.rowOptions {
                XCTAssertEqual(VibeTenBoard(seed: seed, startRows: rows).values,
                               full.map { $0.prefix(rows).map(\.value) },
                               "\(seed) \(rows): the starting rows are the deal's first rows")
            }
        }
    }

    /// The second step is a real shuffle: the digits are not laid down pair by
    /// pair in the order they were drawn.
    func testTheDigitsAreLaidOutAtRandom() {
        let pairs = VibeTenBoard.pairChoices(seed: 1234, count: 9 * 18 / 2)
        let board = VibeTenBoard(seed: 1234).values.flatMap { $0 }
        XCTAssertNotEqual(board, pairs.flatMap { [$0.0, $0.1] })
    }

    /// The pool the draw comes from has both kinds of pair in it.
    func testThePairPoolHasEqualPairsAndPairsThatAddToTen() {
        XCTAssertTrue(VibeTenBoard.pairOptions.contains { $0.0 == $0.1 },
                      "two of the same number")
        XCTAssertTrue(VibeTenBoard.pairOptions.contains { $0.0 + $0.1 == 10 },
                      "and two that add up to ten")
        for pair in VibeTenBoard.pairOptions {
            XCTAssertTrue(VibeTenBoard.valuesPair(pair.0, pair.1))
        }
    }

    /// The browser deals the same boards, so each shape is pinned against a
    /// fixture both engines read. The fixtures live in
    /// `web/src/games/ten/board.fixtures.json`, dumped from this engine.
    func testTheDealMatchesTheFixturesTheWebUses() {
        for (name, expected) in Self.fixtures {
            let parts = name.split(separator: "-").map(String.init)
            let shape = parts[1].split(separator: "x")
            let columns = Int(shape[0]) ?? 9
            let rows = Int(shape[1]) ?? 18
            XCTAssertEqual(VibeTenBoard(seed: 1234, columns: columns,
                                        startRows: rows).values,
                           expected, name)
        }
    }

    func testAResumedBoardKeepsTheStreamFrontierPastEighteen() {
        var board = VibeTenBoard(stacks: Array(repeating: Array(repeating: 1, count: 16),
                                               count: 9),
                                 seed: 1234,
                                 dealtRows: 20)
        XCTAssertEqual(board.dealtRows, 20, "the frontier is not clamped back to the grid")
        XCTAssertTrue(board.addRow())
        XCTAssertEqual(board.value(at: .init(column: 0, row: 16)),
                       VibeTenBoard.rowDigits(seed: 1234, columns: 9, row: 20)[0],
                       "a resumed board carries on from where the stream stopped")
    }

    func testTheStreamAfterTheFirstDealMatchesTheWebFixture() {
        let firstRow = VibeTenBoard.maximumRows
        for (offset, expected) in Self.streamRows.enumerated() {
            XCTAssertEqual(VibeTenBoard.rowDigits(seed: 1234, columns: 9,
                                                  row: firstRow + offset),
                           expected, "row \(firstRow + offset)")
        }
    }

    /// Every row count, from seed 1234. Dumped from this engine.
    static let fixtures: [String: [[Int]]] = [
        "1234-9x12": [
            [5, 3, 6, 4, 5, 1, 9, 7, 2, 9, 1, 7],
            [8, 7, 1, 9, 3, 3, 2, 2, 2, 4, 7, 5],
            [4, 5, 2, 2, 7, 3, 9, 9, 9, 5, 6, 4],
            [1, 2, 1, 3, 6, 5, 7, 1, 2, 1, 6, 4],
            [9, 1, 3, 7, 9, 8, 6, 9, 9, 9, 1, 1],
            [3, 7, 9, 9, 2, 5, 3, 4, 8, 9, 1, 4],
            [3, 2, 9, 2, 9, 9, 5, 4, 3, 3, 8, 1],
            [6, 4, 8, 3, 9, 9, 7, 7, 4, 8, 9, 3],
            [3, 5, 1, 8, 3, 3, 9, 3, 4, 1, 8, 4]
        ],
        "1234-9x14": [
            [5, 3, 6, 4, 5, 1, 9, 7, 2, 9, 1, 7, 8, 7],
            [8, 7, 1, 9, 3, 3, 2, 2, 2, 4, 7, 5, 3, 4],
            [4, 5, 2, 2, 7, 3, 9, 9, 9, 5, 6, 4, 2, 7],
            [1, 2, 1, 3, 6, 5, 7, 1, 2, 1, 6, 4, 1, 1],
            [9, 1, 3, 7, 9, 8, 6, 9, 9, 9, 1, 1, 8, 5],
            [3, 7, 9, 9, 2, 5, 3, 4, 8, 9, 1, 4, 5, 6],
            [3, 2, 9, 2, 9, 9, 5, 4, 3, 3, 8, 1, 4, 5],
            [6, 4, 8, 3, 9, 9, 7, 7, 4, 8, 9, 3, 6, 1],
            [3, 5, 1, 8, 3, 3, 9, 3, 4, 1, 8, 4, 5, 8]
        ],
        "1234-9x16": [
            [5, 3, 6, 4, 5, 1, 9, 7, 2, 9, 1, 7, 8, 7, 1, 4],
            [8, 7, 1, 9, 3, 3, 2, 2, 2, 4, 7, 5, 3, 4, 3, 7],
            [4, 5, 2, 2, 7, 3, 9, 9, 9, 5, 6, 4, 2, 7, 2, 7],
            [1, 2, 1, 3, 6, 5, 7, 1, 2, 1, 6, 4, 1, 1, 1, 3],
            [9, 1, 3, 7, 9, 8, 6, 9, 9, 9, 1, 1, 8, 5, 1, 9],
            [3, 7, 9, 9, 2, 5, 3, 4, 8, 9, 1, 4, 5, 6, 6, 1],
            [3, 2, 9, 2, 9, 9, 5, 4, 3, 3, 8, 1, 4, 5, 7, 8],
            [6, 4, 8, 3, 9, 9, 7, 7, 4, 8, 9, 3, 6, 1, 1, 8],
            [3, 5, 1, 8, 3, 3, 9, 3, 4, 1, 8, 4, 5, 8, 8, 4]
        ],
        "1234-9x18": [
            [5, 3, 6, 4, 5, 1, 9, 7, 2, 9, 1, 7, 8, 7, 1, 4, 3, 7],
            [8, 7, 1, 9, 3, 3, 2, 2, 2, 4, 7, 5, 3, 4, 3, 7, 2, 2],
            [4, 5, 2, 2, 7, 3, 9, 9, 9, 5, 6, 4, 2, 7, 2, 7, 5, 7],
            [1, 2, 1, 3, 6, 5, 7, 1, 2, 1, 6, 4, 1, 1, 1, 3, 3, 3],
            [9, 1, 3, 7, 9, 8, 6, 9, 9, 9, 1, 1, 8, 5, 1, 9, 6, 3],
            [3, 7, 9, 9, 2, 5, 3, 4, 8, 9, 1, 4, 5, 6, 6, 1, 8, 7],
            [3, 2, 9, 2, 9, 9, 5, 4, 3, 3, 8, 1, 4, 5, 7, 8, 1, 9],
            [6, 4, 8, 3, 9, 9, 7, 7, 4, 8, 9, 3, 6, 1, 1, 8, 4, 3],
            [3, 5, 1, 8, 3, 3, 9, 3, 4, 1, 8, 4, 5, 8, 8, 4, 7, 4]
        ]
    ]

    /// The rows after the first deal, from seed 1234. Dumped from this engine by
    /// `Tools/dump_ten_stream.swift` into
    /// `web/src/games/ten/stream.fixtures.json`.
    static let streamRows: [[Int]] = [
        [9, 6, 2, 6, 3, 4, 5, 8, 3],
        [9, 9, 4, 9, 1, 4, 4, 5, 1],
        [2, 5, 9, 1, 2, 5, 4, 2, 9],
        [9, 2, 8, 3, 1, 3, 1, 8, 4],
        [5, 4, 8, 3, 6, 4, 3, 9, 4],
        [4, 8, 9, 6, 7, 7, 5, 6, 4]
    ]
}

/// The scoreboard rule: the first player to clear the board wins, and the pairs
/// are the running total behind that.
final class VibeTenStandingTests: XCTestCase {

    private func standing(_ name: String, _ score: Int,
                          cleared: Int64? = nil,
                          finished: Int64? = nil) -> VibeTenStanding {
        VibeTenStanding(id: name, name: name, score: score,
                        finishedAt: finished, clearedAt: cleared)
    }

    func testTheFirstClearWinsWhateverThePairsSay() {
        let ranked = [standing("Alex", 40, cleared: 200, finished: 200),
                      standing("Sam", 5, cleared: 100, finished: 100),
                      standing("Kit", 60)].sorted(by: vibeTenRank)
        XCTAssertEqual(ranked.map(\.name), ["Sam", "Alex", "Kit"],
                       "the earliest clear is the winner; a big pile of pairs is not")
    }

    func testSomebodyStillPlayingSortsAfterSomebodyWhoHasCleared() {
        let ranked = [standing("Alex", 60),
                      standing("Sam", 4, cleared: 100)].sorted(by: vibeTenRank)
        XCTAssertEqual(ranked.map(\.name), ["Sam", "Alex"])
    }

    func testPairsDecideWhenNobodyHasCleared() {
        let ranked = [standing("Alex", 12, finished: nil),
                      standing("Sam", 18, finished: 500),
                      standing("Kit", 18, finished: 200)].sorted(by: vibeTenRank)
        XCTAssertEqual(ranked.map(\.name), ["Kit", "Sam", "Alex"],
                       "most pairs first, then whoever ran out first")
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

/// Revealing the next rows of the same deal.
final class VibeTenAddRowTests: XCTestCase {

    func testTheNextRowIsTheNextRowOfTheSameDeal() {
        var board = VibeTenBoard(seed: 1234, startRows: 12)
        let full = VibeTenBoard.deal(seed: 1234, columns: 9,
                                     rows: VibeTenBoard.maximumRows).map { $0.map(\.value) }
        let before = board.values
        XCTAssertEqual(board.dealtRows, 12)
        XCTAssertTrue(board.addRow())
        XCTAssertEqual(board.height(ofColumn: 0), 13)
        for column in 0..<9 {
            XCTAssertEqual(Array(board.values[column].prefix(12)), before[column],
                           "nothing already on the board moved")
            XCTAssertEqual(board.values[column].last, full[column][12],
                           "the new row was already in the deal")
        }
        XCTAssertEqual(board.dealtRows, 13, "the deal frontier moves on by a row")
    }

    func testTwoPlayersRevealingTheSameRowSeeTheSameDigits() {
        var first = VibeTenBoard(seed: 77, startRows: 12)
        var second = VibeTenBoard(seed: 77, startRows: 12)
        for _ in 0..<4 {
            XCTAssertTrue(first.addRow())
            XCTAssertTrue(second.addRow())
        }
        XCTAssertEqual(first.values, second.values)
    }

    func testRowsCanBeRevealedPastTheFirstDealOnceClearedRowsMakeRoom() {
        // Sixteen rows of digits with the first deal fully shown: clearing two
        // rows has made room for another press, and the stream keeps going.
        var board = VibeTenBoard(stacks: Array(repeating: Array(repeating: 1, count: 16),
                                               count: 9),
                                 seed: 1234,
                                 dealtRows: 18)
        XCTAssertTrue(board.canAddRow)
        XCTAssertEqual(board.roomForRows, 2)
        XCTAssertTrue(board.addRow())
        XCTAssertTrue(board.addRow())
        XCTAssertEqual(board.dealtRows, 20)
        for column in 0..<9 {
            XCTAssertEqual(board.value(at: .init(column: column, row: 16)),
                           VibeTenBoard.rowDigits(seed: 1234, columns: 9, row: 18)[column],
                           "column \(column): the row after the first deal")
            XCTAssertEqual(board.value(at: .init(column: column, row: 17)),
                           VibeTenBoard.rowDigits(seed: 1234, columns: 9, row: 19)[column],
                           "column \(column): and the one after it")
        }
    }

    func testAFullGridHasNowhereToPutOne() {
        var board = VibeTenBoard(seed: 7)
        XCTAssertFalse(board.canAddRow, "eighteen rows is the top of the grid")
        XCTAssertFalse(board.addRow())
    }

    func testARowIsAvailableOnlyWhenTheBottomOfTheGridIsFree() {
        // Every column one short of the last row: there is room underneath.
        var board = VibeTenBoard(stacks: Array(repeating: Array(repeating: 1, count: 17),
                                               count: 9))
        XCTAssertTrue(board.canAddRow)
        XCTAssertTrue(board.addRow())
        XCTAssertFalse(board.canAddRow, "the grid is full again")

        // One column still reaching the last row holds the new row back.
        let tall = VibeTenBoard(stacks: (0..<9).map {
            Array(repeating: 3, count: $0 == 4 ? 18 : 17)
        })
        XCTAssertFalse(tall.canAddRow, "a single digit on the last row is in the way")
    }
}

/// The board's shape: always nine columns, always room for eighteen rows, and
/// the first rows chosen.
final class VibeTenShapeTests: XCTestCase {

    func testEveryShapeDealsNineColumns() {
        for startRows in VibeTenBoard.rowOptions {
            let board = VibeTenBoard(seed: 12_345, startRows: startRows)
            XCTAssertEqual(board.columns, 9, "\(startRows): nine columns")
            XCTAssertEqual(board.rows, VibeTenBoard.maximumRows,
                           "\(startRows): the board has room for eighteen rows")
            XCTAssertEqual(board.values.count, 9)
            for column in board.values {
                XCTAssertEqual(column.count, startRows,
                               "\(startRows): the digits start that many rows deep")
                XCTAssertTrue(column.allSatisfy { (1...9).contains($0) },
                              "\(startRows): digits one to nine")
            }
            XCTAssertEqual(board.remaining, 9 * startRows)
            XCTAssertEqual(board.roomForRows, VibeTenBoard.maximumRows - startRows)
        }
    }

    func testTheStartingRowsArePartOfTheDeal() {
        XCTAssertEqual(VibeTenBoard(seed: 7, startRows: 12).values,
                       VibeTenBoard(seed: 7, startRows: 12).values)
        XCTAssertNotEqual(VibeTenBoard(seed: 7, startRows: 12).values,
                          VibeTenBoard(seed: 7, startRows: 14).values,
                          "two rows more is a different board")
        XCTAssertNotEqual(VibeTenBoard(seed: 7, startRows: 12).values,
                          VibeTenBoard(seed: 8, startRows: 12).values,
                          "and so is another seed")
        // The default is the board the game shipped with: nine by eighteen.
        XCTAssertEqual(VibeTenBoard(seed: 7).values,
                       VibeTenBoard(seed: 7, columns: 9, startRows: 18).values)

        // Every start is the top of one whole deal: the rows underneath are
        // already drawn and wait face down.
        let full = VibeTenBoard.deal(seed: 7, columns: 9,
                                     rows: VibeTenBoard.maximumRows).map { $0.map(\.value) }
        for startRows in VibeTenBoard.rowOptions {
            XCTAssertEqual(VibeTenBoard(seed: 7, startRows: startRows).values,
                           full.map { Array($0.prefix(startRows)) },
                           "\(startRows): the starting rows are the deal's first rows")
        }
    }

    func testRowsAreRevealedUnderTheDigitsAndGrowTheBoard() {
        var board = VibeTenBoard(stacks: Array(repeating: Array(repeating: 1, count: 6),
                                               count: 9))
        let before = board.values
        XCTAssertTrue(board.addRow())
        XCTAssertEqual(board.height(ofColumn: 0), 7)
        for column in 0..<9 {
            XCTAssertEqual(Array(board.values[column].prefix(6)), before[column],
                           "nothing already on the board moved")
        }
    }

    func testABoardCanBeGrownToEighteenRowsAndNoFurther() {
        var board = VibeTenBoard(seed: 1234, startRows: 12)
        XCTAssertTrue(board.canAddRow, "six rows of room under a twelve-row start")
        for _ in 0..<6 {
            XCTAssertTrue(board.addRow())
        }
        XCTAssertEqual(board.height(ofColumn: 0), 18)
        XCTAssertEqual(board.dealtRows, 18)
        XCTAssertFalse(board.canAddRow, "eighteen is the last row")
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
