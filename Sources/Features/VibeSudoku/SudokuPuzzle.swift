import Foundation

/// How hard a puzzle is. Expressed as a target clue count — see the note on
/// ``SudokuGenerator`` for what that does and does not guarantee.
enum SudokuDifficulty: String, CaseIterable, Identifiable, Hashable, Sendable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    /// The grade a puzzle of this difficulty must actually earn. Generation
    /// keeps trying until the grader agrees, so this is a real target rather
    /// than a clue count in disguise.
    var grade: SudokuGrade {
        switch self {
        case .easy: return .easy
        case .medium: return .medium
        case .hard: return .hard
        }
    }

    /// How far to keep carving. Easy stops while the grid is still generous;
    /// the others carve until the grader says the grade has been reached.
    var minimumClues: Int {
        switch self {
        case .easy: return 44
        case .medium: return 26
        case .hard: return 22
        }
    }

    /// Whether to stop at the *first* puzzle of this grade, or keep carving and
    /// take the last one that still graded the same.
    ///
    /// Medium wants the first: it is the gentlest board that needs real
    /// technique. Hard wants the last, so it ends up genuinely sparse as well.
    var stopsAtFirstMatch: Bool {
        self == .medium
    }

    /// How many carves to try before settling for the closest grade. In
    /// practice the first one matches, so this only bounds the worst case.
    var maxAttempts: Int {
        switch self {
        case .easy: return 4
        case .medium: return 8
        case .hard: return 8
        }
    }

    var blurb: String {
        switch self {
        case .easy: return "Singles all the way down"
        case .medium: return "Needs pairs and locked candidates"
        case .hard: return "Sparse, and needs real technique"
        }
    }

    /// Used when a difficulty has to be assumed — parsing an older record, say.
    static let fallback: SudokuDifficulty = .easy
}

/// A generated puzzle, fully reproducible from its seed.
struct SudokuPuzzle: Equatable {
    let seed: UInt32
    let difficulty: SudokuDifficulty
    /// 81 values, row-major. `0` means empty.
    let givens: [Int]
    /// The one solution the givens admit.
    let solution: [Int]

    static let side = 9
    static let cellCount = 81

    func isGiven(_ index: Int) -> Bool { givens[index] != 0 }

    var clueCount: Int { givens.filter { $0 != 0 }.count }
}

/// Grid maths. Deliberately free of UI and networking so it can be tested hard.
enum SudokuSolver {

    static func row(of index: Int) -> Int { index / 9 }
    static func column(of index: Int) -> Int { index % 9 }
    static func box(of index: Int) -> Int { (index / 27) * 3 + (index % 9) / 3 }

    /// Counts solutions, stopping early once `limit` is reached.
    ///
    /// Uses bitmasks plus a minimum-remaining-values search, which is what makes
    /// uniqueness checking fast enough to run once per removed clue.
    static func solutionCount(of grid: [Int], limit: Int = 2) -> Int {
        guard grid.count == SudokuPuzzle.cellCount else { return 0 }

        var rows = [UInt16](repeating: 0, count: 9)
        var columns = [UInt16](repeating: 0, count: 9)
        var boxes = [UInt16](repeating: 0, count: 9)
        var cells = grid

        for index in 0..<SudokuPuzzle.cellCount where grid[index] != 0 {
            let value = grid[index]
            guard (1...9).contains(value) else { return 0 }
            let bit = UInt16(1 << (value - 1))
            let r = row(of: index), c = column(of: index), b = box(of: index)
            // A well-formed givens grid never repeats within a unit.
            if rows[r] & bit != 0 || columns[c] & bit != 0 || boxes[b] & bit != 0 { return 0 }
            rows[r] |= bit
            columns[c] |= bit
            boxes[b] |= bit
        }

        var found = 0

        func search() {
            if found >= limit { return }

            var target = -1
            var targetMask: UInt16 = 0
            var fewest = 10

            for index in 0..<SudokuPuzzle.cellCount where cells[index] == 0 {
                let r = row(of: index), c = column(of: index), b = box(of: index)
                let available = ~(rows[r] | columns[c] | boxes[b]) & 0x1FF
                let count = available.nonzeroBitCount
                if count == 0 { return }               // dead end
                if count < fewest {
                    fewest = count
                    target = index
                    targetMask = available
                    if count == 1 { break }            // cannot do better
                }
            }

            if target == -1 {                          // nothing empty: a solution
                found += 1
                return
            }

            let r = row(of: target), c = column(of: target), b = box(of: target)
            var mask = targetMask
            while mask != 0 {
                let bit = mask & (~mask &+ 1)
                mask &= ~bit

                cells[target] = bit.trailingZeroBitCount + 1
                rows[r] |= bit; columns[c] |= bit; boxes[b] |= bit

                search()

                rows[r] &= ~bit; columns[c] &= ~bit; boxes[b] &= ~bit
                cells[target] = 0

                if found >= limit { return }
            }
        }

        search()
        return found
    }

    /// Indices whose value repeats within its row, column or box.
    static func conflicts(in grid: [Int]) -> Set<Int> {
        var result: Set<Int> = []

        for index in 0..<SudokuPuzzle.cellCount where grid[index] != 0 {
            let value = grid[index]
            let r = row(of: index), c = column(of: index), b = box(of: index)

            for other in (index + 1)..<SudokuPuzzle.cellCount where grid[other] == value {
                if row(of: other) == r || column(of: other) == c || box(of: other) == b {
                    result.insert(index)
                    result.insert(other)
                }
            }
        }

        return result
    }

    /// Whether every cell is filled and nothing conflicts.
    static func isComplete(_ grid: [Int]) -> Bool {
        grid.count == SudokuPuzzle.cellCount
            && !grid.contains(0)
            && conflicts(in: grid).isEmpty
    }
}
