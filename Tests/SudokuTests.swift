import XCTest
@testable import VibeGames

/// The generator is the part of Sudoku that can be quietly wrong, so it gets
/// the most scrutiny: deterministic, uniquely solvable, and consistent with the
/// solution it hands back.
final class SudokuGeneratorTests: XCTestCase {

    private let sampleSeeds: [UInt32] = [0, 1, 42, 1337, 999_999, 4_294_967_295]

    // MARK: - Determinism
    //
    // Shared games send only a seed, so two devices must build the same board.

    func testSameSeedProducesAnIdenticalPuzzle() {
        for seed in sampleSeeds {
            for difficulty in SudokuDifficulty.allCases {
                let first = SudokuGenerator.puzzle(seed: seed, difficulty: difficulty)
                let second = SudokuGenerator.puzzle(seed: seed, difficulty: difficulty)

                XCTAssertEqual(first.givens, second.givens,
                               "seed \(seed) / \(difficulty) givens differ")
                XCTAssertEqual(first.solution, second.solution,
                               "seed \(seed) / \(difficulty) solutions differ")
            }
        }
    }

    func testDifferentSeedsProduceDifferentPuzzles() {
        let boards = Set(sampleSeeds.map {
            SudokuGenerator.puzzle(seed: $0, difficulty: .easy).givens.description
        })
        XCTAssertEqual(boards.count, sampleSeeds.count,
                       "Distinct seeds should not collapse to the same board")
    }

    // MARK: - Correctness

    func testSolutionIsAValidCompleteGrid() {
        for seed in sampleSeeds {
            let puzzle = SudokuGenerator.puzzle(seed: seed, difficulty: .medium)
            let solution = puzzle.solution

            XCTAssertEqual(solution.count, 81)
            XCTAssertFalse(solution.contains(0), "solution has gaps for seed \(seed)")
            XCTAssertTrue(solution.allSatisfy { (1...9).contains($0) })
            XCTAssertTrue(SudokuSolver.conflicts(in: solution).isEmpty,
                          "solution conflicts for seed \(seed)")
            XCTAssertTrue(SudokuSolver.isComplete(solution))
        }
    }

    func testEveryUnitContainsOneToNine() {
        let solution = SudokuGenerator.puzzle(seed: 7, difficulty: .easy).solution

        for unit in 0..<9 {
            var row: Set<Int> = [], column: Set<Int> = [], box: Set<Int> = []
            for offset in 0..<9 {
                row.insert(solution[unit * 9 + offset])
                column.insert(solution[offset * 9 + unit])
                let boxRow = (unit / 3) * 3 + offset / 3
                let boxColumn = (unit % 3) * 3 + offset % 3
                box.insert(solution[boxRow * 9 + boxColumn])
            }
            XCTAssertEqual(row, Set(1...9), "row \(unit)")
            XCTAssertEqual(column, Set(1...9), "column \(unit)")
            XCTAssertEqual(box, Set(1...9), "box \(unit)")
        }
    }

    func testGivensAgreeWithTheSolution() {
        for seed in sampleSeeds {
            let puzzle = SudokuGenerator.puzzle(seed: seed, difficulty: .hard)
            for index in 0..<81 where puzzle.isGiven(index) {
                XCTAssertEqual(puzzle.givens[index], puzzle.solution[index],
                               "given at \(index) contradicts the solution")
            }
        }
    }

    /// The property that actually makes a Sudoku fair: exactly one answer.
    func testGivensAdmitExactlyOneSolution() {
        for seed in sampleSeeds {
            for difficulty in SudokuDifficulty.allCases {
                let puzzle = SudokuGenerator.puzzle(seed: seed, difficulty: difficulty)
                XCTAssertEqual(SudokuSolver.solutionCount(of: puzzle.givens, limit: 2), 1,
                               "seed \(seed) / \(difficulty) is not uniquely solvable")
            }
        }
    }

    // MARK: - Difficulty

    /// Difficulty is defined by the technique needed, not the clue count, so
    /// the tiers are allowed to overlap. Easy should still be the most generous.
    func testEasyLeavesTheMostClues() {
        for seed in sampleSeeds {
            let easy = SudokuGenerator.puzzle(seed: seed, difficulty: .easy).clueCount
            let hard = SudokuGenerator.puzzle(seed: seed, difficulty: .hard).clueCount
            XCTAssertGreaterThan(easy, hard, "seed \(seed): easy should beat hard")
        }
    }

    func testClueCountsStayInABelievableRange() {
        for seed in sampleSeeds {
            for difficulty in SudokuDifficulty.allCases {
                let puzzle = SudokuGenerator.puzzle(seed: seed, difficulty: difficulty)
                // A 17-clue grid is the proven minimum for a unique Sudoku, so
                // anything below that would mean the uniqueness check is broken.
                XCTAssertGreaterThanOrEqual(puzzle.clueCount, 17,
                                            "\(difficulty) has implausibly few clues")
                XCTAssertLessThanOrEqual(puzzle.clueCount, 60)
            }
        }
    }

    // MARK: - Cost
    //
    // Generation runs on the main thread when a round starts, so it has to stay
    // well inside a frame budget's order of magnitude.

    func testRandomSeedVaries() {
        let seeds = Set((0..<200).map { _ in SudokuGenerator.randomSeed() })
        XCTAssertGreaterThan(seeds.count, 190, "Seeds should not collide in practice")
    }
}

final class SudokuSolverTests: XCTestCase {

    func testEmptyGridHasManySolutions() {
        let empty = [Int](repeating: 0, count: 81)
        XCTAssertEqual(SudokuSolver.solutionCount(of: empty, limit: 2), 2,
                       "An empty grid is far from unique")
    }

    func testSolvedGridHasExactlyOneSolution() {
        let solution = SudokuGenerator.puzzle(seed: 3, difficulty: .easy).solution
        XCTAssertEqual(SudokuSolver.solutionCount(of: solution, limit: 2), 1)
    }

    func testRejectsGivensThatAlreadyConflict() {
        var grid = [Int](repeating: 0, count: 81)
        grid[0] = 5
        grid[1] = 5          // same row
        XCTAssertEqual(SudokuSolver.solutionCount(of: grid), 0)
    }

    func testRejectsOutOfRangeValues() {
        var grid = [Int](repeating: 0, count: 81)
        grid[0] = 12
        XCTAssertEqual(SudokuSolver.solutionCount(of: grid), 0)
    }

    func testConflictsFindsRowClash() {
        var grid = [Int](repeating: 0, count: 81)
        grid[0] = 4
        grid[8] = 4
        XCTAssertEqual(SudokuSolver.conflicts(in: grid), [0, 8])
    }

    func testConflictsFindsColumnClash() {
        var grid = [Int](repeating: 0, count: 81)
        grid[0] = 7
        grid[72] = 7
        XCTAssertEqual(SudokuSolver.conflicts(in: grid), [0, 72])
    }

    func testConflictsFindsBoxClash() {
        var grid = [Int](repeating: 0, count: 81)
        grid[0] = 2
        grid[10] = 2         // same 3x3 box, different row and column
        XCTAssertEqual(SudokuSolver.conflicts(in: grid), [0, 10])
    }

    func testConflictsIgnoresEmptyCellsAndCleanGrids() {
        var grid = [Int](repeating: 0, count: 81)
        grid[0] = 1
        grid[1] = 2
        XCTAssertTrue(SudokuSolver.conflicts(in: grid).isEmpty)

        grid[2] = 0
        XCTAssertTrue(SudokuSolver.conflicts(in: grid).isEmpty)
    }

    func testIsCompleteRejectsPartiallyFilledGrids() {
        let solution = SudokuGenerator.puzzle(seed: 11, difficulty: .easy).solution
        var partial = solution
        partial[40] = 0

        XCTAssertTrue(SudokuSolver.isComplete(solution))
        XCTAssertFalse(SudokuSolver.isComplete(partial))
    }

    func testIsCompleteRejectsAConflictingGrid() {
        var grid = SudokuGenerator.puzzle(seed: 11, difficulty: .easy).solution
        // Swap two cells in the same row so the grid is full but invalid.
        grid.swapAt(0, 1)
        XCTAssertFalse(SudokuSolver.isComplete(grid))
    }
}

/// How many marks a square holds is a setting, and the interesting part is what
/// happens to marks already written when the setting shrinks.
@MainActor
final class VibeSudokuNoteLimitTests: XCTestCase {

    private let key = VibeSudokuModel.noteLimitKey
    private var savedValue: Any?

    override func setUp() {
        super.setUp()
        savedValue = UserDefaults.standard.object(forKey: key)
        // Nine, so a test can write more marks than four and then shrink.
        UserDefaults.standard.set(9, forKey: key)
    }

    override func tearDown() {
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    /// Dropping to four keeps the lowest marks: they are the ones written first,
    /// so losing the newest is the least surprising thing to lose.
    func testShrinkingToFourKeepsTheLowestMarks() throws {
        let model = VibeSudokuModel()
        XCTAssertEqual(model.noteLimit, 9)

        model.playSolo()
        let index = try emptyCell(in: model)
        model.select(index)
        model.isNoteMode = true
        for digit in 1...6 { model.enter(digit) }
        XCTAssertEqual(model.notes[index], Set(1...6))

        model.setNoteLimit(4)
        XCTAssertEqual(model.noteLimit, 4)
        XCTAssertEqual(model.notes[index], Set(1...4))
    }

    /// The choice outlives the puzzle, the game and the launch.
    func testTheLimitIsRemembered() {
        let model = VibeSudokuModel()
        model.setNoteLimit(4)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 4)

        let nextLaunch = VibeSudokuModel()
        XCTAssertEqual(nextLaunch.noteLimit, 4)
    }

    /// A key that does nothing is worse than one that says why: the fifth mark
    /// is refused, and the fourth is kept.
    func testAFifthMarkIsRefusedWithAReason() throws {
        let model = VibeSudokuModel()
        model.setNoteLimit(4)
        model.playSolo()

        let index = try emptyCell(in: model)
        model.select(index)
        model.isNoteMode = true
        for digit in 1...4 { model.enter(digit) }
        model.enter(5)

        XCTAssertEqual(model.notes[index], Set(1...4))
        XCTAssertEqual(model.noteNotice, "Notes hold 4 numbers.")
    }

    /// A value nobody offers is ignored rather than stored.
    func testAnUnknownLimitIsIgnored() {
        let model = VibeSudokuModel()
        model.setNoteLimit(7)
        XCTAssertEqual(model.noteLimit, 9)
    }

    private func emptyCell(in model: VibeSudokuModel) throws -> Int {
        let puzzle = try XCTUnwrap(model.puzzle)
        return try XCTUnwrap((0..<SudokuPuzzle.cellCount).first { !puzzle.isGiven($0) })
    }
}
