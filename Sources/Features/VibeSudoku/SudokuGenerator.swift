import Foundation

/// Builds Sudoku puzzles on demand. Nothing is stored: a puzzle is a pure
/// function of `(seed, difficulty)`, so there are as many boards as there are
/// seeds — about four billion — and a shared game only has to send a number.
///
/// On difficulty: a puzzle is **graded by the techniques it needs**, not by how
/// many clues it shows. Generation carves a candidate, grades it, and keeps
/// trying different carve orders until the grade matches the request. That is
/// slower than counting clues, but it is the difference between a board that
/// merely looks sparse and one that actually makes you think.
///
/// Everything derives from the seed, so two devices still build identical
/// boards — including which attempt succeeded.
enum SudokuGenerator {

    /// ~4 billion, minus nothing. Enough that repeats are not a concern.
    static func randomSeed() -> UInt32 {
        UInt32.random(in: 0...UInt32.max)
    }

    static func puzzle(seed: UInt32, difficulty: SudokuDifficulty) -> SudokuPuzzle {
        var generator = SeededGenerator(seed: seed)
        let solution = makeSolution(using: &generator)

        var best: (givens: [Int], distance: Int)?

        for _ in 0..<difficulty.maxAttempts {
            let givens = carve(from: solution,
                               difficulty: difficulty,
                               using: &generator)
            let grade = SudokuGrader.grade(givens)
            let distance = grade.distance(to: difficulty.grade)

            if distance == 0 {
                return SudokuPuzzle(seed: seed,
                                    difficulty: difficulty,
                                    givens: givens,
                                    solution: solution)
            }

            // Keep the closest miss, so failing to hit the grade exactly still
            // returns the most fitting board we saw rather than the last one.
            if best == nil || distance < best!.distance {
                best = (givens, distance)
            }
        }

        return SudokuPuzzle(seed: seed,
                            difficulty: difficulty,
                            givens: best?.givens ?? solution,
                            solution: solution)
    }

    // MARK: - Carving

    /// Removes clues one at a time, keeping the puzzle uniquely solvable, and
    /// watches the grade as it goes.
    ///
    /// Clue count alone is a poor proxy for difficulty: a 34-clue grid very
    /// often still falls to singles. So rather than carving to a number, this
    /// carves until the *grader* says the requested grade has been reached —
    /// which is what makes the tiers mean something.
    private static func carve(from solution: [Int],
                              difficulty: SudokuDifficulty,
                              using generator: inout SeededGenerator) -> [Int] {
        var puzzle = solution
        var order = Array(0..<SudokuPuzzle.cellCount)
        order.shuffle(using: &generator)

        var clues = SudokuPuzzle.cellCount
        var match: [Int]?

        for index in order {
            if clues <= difficulty.minimumClues { break }

            let removed = puzzle[index]
            puzzle[index] = 0

            // Only keep the removal if the puzzle still has exactly one answer.
            guard SudokuSolver.solutionCount(of: puzzle, limit: 2) == 1 else {
                puzzle[index] = removed
                continue
            }
            clues -= 1

            let grade = SudokuGrader.grade(puzzle)

            if grade == difficulty.grade {
                match = puzzle
                if difficulty.stopsAtFirstMatch { break }
            } else if grade > difficulty.grade, difficulty.stopsAtFirstMatch {
                // Overshot the grade; the previous match is the one to keep.
                break
            }
        }

        return match ?? puzzle
    }

    // MARK: - Building a full grid

    /// Fills an empty grid by randomised backtracking.
    private static func makeSolution(using generator: inout SeededGenerator) -> [Int] {
        var grid = [Int](repeating: 0, count: SudokuPuzzle.cellCount)
        _ = fill(&grid, using: &generator)
        return grid
    }

    private static func fill(_ grid: inout [Int], using generator: inout SeededGenerator) -> Bool {
        guard let index = grid.firstIndex(of: 0) else { return true }

        var candidates = Array(1...9)
        candidates.shuffle(using: &generator)

        for candidate in candidates where isSafe(candidate, at: index, in: grid) {
            grid[index] = candidate
            if fill(&grid, using: &generator) { return true }
            grid[index] = 0
        }

        return false
    }

    private static func isSafe(_ value: Int, at index: Int, in grid: [Int]) -> Bool {
        let r = SudokuSolver.row(of: index)
        let c = SudokuSolver.column(of: index)
        let b = SudokuSolver.box(of: index)

        for other in 0..<SudokuPuzzle.cellCount where grid[other] == value {
            if SudokuSolver.row(of: other) == r
                || SudokuSolver.column(of: other) == c
                || SudokuSolver.box(of: other) == b {
                return false
            }
        }
        return true
    }
}
