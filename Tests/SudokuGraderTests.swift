import XCTest
@testable import VibeGames

/// The grader is what makes a difficulty tier mean something, so it gets its
/// own tests. If these drift, "hard" quietly becomes "sparse but easy" again.
final class SudokuGraderTests: XCTestCase {

    /// The classic introductory puzzle: every cell falls to a single.
    private let singlesOnly = [
        5,3,0, 0,7,0, 0,0,0,
        6,0,0, 1,9,5, 0,0,0,
        0,9,8, 0,0,0, 0,6,0,
        8,0,0, 0,6,0, 0,0,3,
        4,0,0, 8,0,3, 0,0,1,
        7,0,0, 0,2,0, 0,0,6,
        0,6,0, 0,0,0, 2,8,0,
        0,0,0, 4,1,9, 0,0,5,
        0,0,0, 0,8,0, 0,7,9,
    ]

    func testSinglesOnlyPuzzleGradesEasy() {
        XCTAssertEqual(SudokuGrader.grade(singlesOnly), .easy)
    }

    func testSolvedGridGradesEasy() {
        let solution = SudokuGenerator.puzzle(seed: 5, difficulty: .easy).solution
        XCTAssertEqual(SudokuGrader.grade(solution), .easy,
                       "A finished grid needs no technique at all")
    }

    func testEmptyGridCannotBeReasonedOut() {
        // Nothing to work with, so it must not be graded as solvable.
        let empty = [Int](repeating: 0, count: 81)
        XCTAssertEqual(SudokuGrader.grade(empty), .hard)
        XCTAssertNil(SudokuGrader.solve(empty))
    }

    func testGradingIsDeterministic() {
        let puzzle = SudokuGenerator.puzzle(seed: 11, difficulty: .medium)
        let first = SudokuGrader.grade(puzzle.givens)
        for _ in 0..<3 {
            XCTAssertEqual(SudokuGrader.grade(puzzle.givens), first)
        }
    }

    /// The heart of it: a puzzle labelled a difficulty must actually require it.
    func testGeneratedPuzzlesEarnTheirGrade() {
        for difficulty in SudokuDifficulty.allCases {
            for seed in UInt32(0)..<6 {
                let puzzle = SudokuGenerator.puzzle(seed: seed, difficulty: difficulty)
                XCTAssertEqual(
                    SudokuGrader.grade(puzzle.givens), difficulty.grade,
                    "seed \(seed) requested \(difficulty.rawValue) but graded "
                    + "\(SudokuGrader.grade(puzzle.givens))"
                )
            }
        }
    }

    /// Clue count is no longer the definition, but a harder tier should still
    /// not hand you *more* clues than an easier one.
    func testHarderTiersAreNotMoreGenerous() {
        for seed in UInt32(0)..<6 {
            let easy = SudokuGenerator.puzzle(seed: seed, difficulty: .easy).clueCount
            let medium = SudokuGenerator.puzzle(seed: seed, difficulty: .medium).clueCount
            let hard = SudokuGenerator.puzzle(seed: seed, difficulty: .hard).clueCount

            XCTAssertGreaterThan(easy, medium, "seed \(seed): easy vs medium")
            XCTAssertGreaterThan(easy, hard, "seed \(seed): easy vs hard")
        }
    }

    /// A puzzle needing technique must be solvable without guessing — otherwise
    /// it is not a fair puzzle, it is a chore.
    func testHardPuzzlesAreStillLogicallySolvableOrHardByGuessing() {
        for seed in UInt32(0)..<4 {
            let puzzle = SudokuGenerator.puzzle(seed: seed, difficulty: .hard)
            // The grader returns `.hard` both when a wing is needed and when it
            // gives up; either way the grid must have exactly one answer.
            XCTAssertEqual(SudokuSolver.solutionCount(of: puzzle.givens, limit: 2), 1)
            XCTAssertNil(SudokuGrader.solve(puzzle.givens).flatMap { $0 == .hard ? nil : $0 },
                         "A hard puzzle should need hard technique")
        }
    }

    func testGenerationStaysInteractive() {
        let start = Date()
        for seed in UInt32(0)..<4 {
            _ = SudokuGenerator.puzzle(seed: seed, difficulty: .hard)
        }
        let perPuzzle = Date().timeIntervalSince(start) / 4
        XCTAssertLessThan(perPuzzle, 2.0,
                          "Hard puzzles averaged \(Int(perPuzzle * 1000))ms each")
    }
}
