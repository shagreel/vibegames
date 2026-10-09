import Foundation

/// How hard a puzzle is, judged by what it takes to solve rather than how many
/// clues it happens to show.
enum SudokuGrade: Int, Comparable, CaseIterable {
    case easy
    case medium
    case hard

    static func < (lhs: SudokuGrade, rhs: SudokuGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Distance between two grades, for picking the least-bad fallback.
    func distance(to other: SudokuGrade) -> Int { abs(rawValue - other.rawValue) }
}

/// The solving techniques the grader knows, ordered by how hard they are.
enum SudokuTechnique: Int, Comparable {
    case nakedSingle
    case hiddenSingle
    case lockedCandidates
    case nakedPair
    case hiddenPair
    case nakedTriple
    case xWing
    case xyWing

    static func < (lhs: SudokuTechnique, rhs: SudokuTechnique) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var grade: SudokuGrade {
        switch self {
        case .nakedSingle, .hiddenSingle:
            return .easy
        case .lockedCandidates, .nakedPair, .hiddenPair, .nakedTriple:
            return .medium
        case .xWing, .xyWing:
            return .hard
        }
    }
}

/// Grades a Sudoku by solving it the way a person would.
///
/// It repeatedly applies the *easiest* technique that makes progress, and
/// remembers the hardest one it needed. If it runs out of techniques before the
/// grid is full, the puzzle needs trial and error, which counts as hard.
///
/// This is what makes a difficulty tier meaningful. Clue count only correlates
/// with difficulty: a 26-clue grid that falls to singles is far easier than a
/// 32-clue grid that needs an X-Wing.
enum SudokuGrader {

    private static let allValues: UInt16 = 0x1FF

    /// 27 units: nine rows, nine columns, nine boxes.
    static let units: [[Int]] = {
        var result: [[Int]] = []
        for row in 0..<9 { result.append((0..<9).map { row * 9 + $0 }) }
        for column in 0..<9 { result.append((0..<9).map { $0 * 9 + column }) }
        for box in 0..<9 {
            let baseRow = (box / 3) * 3
            let baseColumn = (box % 3) * 3
            result.append((0..<9).map { (baseRow + $0 / 3) * 9 + baseColumn + $0 % 3 })
        }
        return result
    }()

    /// Cells sharing a row, column or box with each cell. Precomputed because
    /// the wing techniques ask the question far too often to recompute it.
    private static let peers: [[Int]] = {
        var result = [[Int]](repeating: [], count: 81)
        for cell in 0..<81 {
            result[cell] = (0..<81).filter {
                $0 != cell
                    && (SudokuSolver.row(of: $0) == SudokuSolver.row(of: cell)
                        || SudokuSolver.column(of: $0) == SudokuSolver.column(of: cell)
                        || SudokuSolver.box(of: $0) == SudokuSolver.box(of: cell))
            }
        }
        return result
    }()

    /// Every unit each cell belongs to.
    private static let unitsByCell: [[Int]] = {
        var result = [[Int]](repeating: [], count: 81)
        for (index, unit) in units.enumerated() {
            for cell in unit { result[cell].append(index) }
        }
        return result
    }()

    // MARK: - Public

    static func grade(_ grid: [Int]) -> SudokuGrade {
        solve(grid) ?? .hard
    }

    /// Returns the hardest technique needed, or `nil` if the puzzle cannot be
    /// finished without guessing.
    static func solve(_ grid: [Int]) -> SudokuGrade? {
        guard grid.count == SudokuPuzzle.cellCount else { return nil }

        var cells = grid
        var candidates = makeCandidates(cells)
        var hardest = SudokuTechnique.nakedSingle

        while cells.contains(0) {
            if placeNakedSingle(&cells, &candidates) {
                hardest = max(hardest, .nakedSingle)
                continue
            }
            if placeHiddenSingle(&cells, &candidates) {
                hardest = max(hardest, .hiddenSingle)
                continue
            }
            if eliminateLockedCandidates(&candidates) {
                hardest = max(hardest, .lockedCandidates)
                continue
            }
            if eliminateNakedPair(&candidates) {
                hardest = max(hardest, .nakedPair)
                continue
            }
            if eliminateHiddenPair(&candidates) {
                hardest = max(hardest, .hiddenPair)
                continue
            }
            if eliminateNakedTriple(&candidates) {
                hardest = max(hardest, .nakedTriple)
                continue
            }
            if eliminateXWing(&candidates) {
                hardest = max(hardest, .xWing)
                continue
            }
            if eliminateXYWing(&candidates) {
                hardest = max(hardest, .xyWing)
                continue
            }
            // Nothing left that a person could reason with.
            return nil
        }

        return hardest.grade
    }

    // MARK: - Candidates

    private static func makeCandidates(_ cells: [Int]) -> [UInt16] {
        var used = [UInt16](repeating: 0, count: 27)
        for index in 0..<SudokuPuzzle.cellCount where cells[index] != 0 {
            let bit = bitFor(cells[index])
            for unit in unitsByCell[index] { used[unit] |= bit }
        }

        var result = [UInt16](repeating: 0, count: SudokuPuzzle.cellCount)
        for index in 0..<SudokuPuzzle.cellCount where cells[index] == 0 {
            var mask = allValues
            for unit in unitsByCell[index] { mask &= ~used[unit] }
            result[index] = mask
        }
        return result
    }

    private static func bitFor(_ value: Int) -> UInt16 { UInt16(1 << (value - 1)) }

    private static func valueFor(_ bit: UInt16) -> Int { bit.trailingZeroBitCount + 1 }

    private static func bits(in mask: UInt16) -> [UInt16] {
        var result: [UInt16] = []
        var remaining = mask
        while remaining != 0 {
            let bit = remaining & (~remaining &+ 1)
            result.append(bit)
            remaining &= ~bit
        }
        return result
    }

    @discardableResult
    private static func place(_ value: Int, at index: Int,
                              _ cells: inout [Int], _ candidates: inout [UInt16]) -> Bool {
        guard cells[index] == 0 else { return false }
        cells[index] = value
        candidates[index] = 0

        let bit = bitFor(value)
        for unit in unitsByCell[index] {
            for peer in units[unit] where cells[peer] == 0 {
                candidates[peer] &= ~bit
            }
        }
        return true
    }

    // MARK: - Techniques

    private static func placeNakedSingle(_ cells: inout [Int], _ candidates: inout [UInt16]) -> Bool {
        for index in 0..<SudokuPuzzle.cellCount
        where cells[index] == 0 && candidates[index].nonzeroBitCount == 1 {
            return place(valueFor(candidates[index]), at: index, &cells, &candidates)
        }
        return false
    }

    private static func placeHiddenSingle(_ cells: inout [Int], _ candidates: inout [UInt16]) -> Bool {
        for unit in units {
            var seen: UInt16 = 0
            var duplicates: UInt16 = 0
            for cell in unit where cells[cell] == 0 {
                duplicates |= seen & candidates[cell]
                seen |= candidates[cell]
            }
            let unique = seen & ~duplicates
            guard unique != 0 else { continue }

            // One value has a single home in this unit.
            let bit = bits(in: unique)[0]
            for cell in unit where cells[cell] == 0 && candidates[cell] & bit != 0 {
                return place(valueFor(bit), at: cell, &cells, &candidates)
            }
        }
        return false
    }

    /// Pointing and claiming: if a value's only homes in a box lie on one line,
    /// it can be removed from the rest of that line, and vice versa.
    private static func eliminateLockedCandidates(_ candidates: inout [UInt16]) -> Bool {
        var changed = false

        for box in 0..<9 {
            let unit = units[18 + box]
            for value in 1...9 {
                let bit = bitFor(value)
                let homes = unit.filter { candidates[$0] & bit != 0 }
                guard homes.count >= 2, homes.count <= 3 else { continue }

                if Set(homes.map { SudokuSolver.row(of: $0) }).count == 1 {
                    let row = SudokuSolver.row(of: homes[0])
                    for cell in units[row] where !unit.contains(cell) && candidates[cell] & bit != 0 {
                        candidates[cell] &= ~bit
                        changed = true
                    }
                }
                if Set(homes.map { SudokuSolver.column(of: $0) }).count == 1 {
                    let column = SudokuSolver.column(of: homes[0])
                    for cell in units[9 + column] where !unit.contains(cell) && candidates[cell] & bit != 0 {
                        candidates[cell] &= ~bit
                        changed = true
                    }
                }
            }
        }

        for line in 0..<18 {
            let unit = units[line]
            for value in 1...9 {
                let bit = bitFor(value)
                let homes = unit.filter { candidates[$0] & bit != 0 }
                guard homes.count >= 2, homes.count <= 3 else { continue }
                guard Set(homes.map { SudokuSolver.box(of: $0) }).count == 1 else { continue }

                let box = SudokuSolver.box(of: homes[0])
                for cell in units[18 + box] where !unit.contains(cell) && candidates[cell] & bit != 0 {
                    candidates[cell] &= ~bit
                    changed = true
                }
            }
        }

        return changed
    }

    private static func eliminateNakedPair(_ candidates: inout [UInt16]) -> Bool {
        for unit in units {
            let pairs = unit.filter { candidates[$0].nonzeroBitCount == 2 }
            guard pairs.count >= 2 else { continue }

            for first in 0..<pairs.count {
                for second in (first + 1)..<pairs.count {
                    let mask = candidates[pairs[first]]
                    guard mask == candidates[pairs[second]] else { continue }

                    var changed = false
                    for cell in unit where cell != pairs[first] && cell != pairs[second] {
                        if candidates[cell] & mask != 0 {
                            candidates[cell] &= ~mask
                            changed = true
                        }
                    }
                    if changed { return true }
                }
            }
        }
        return false
    }

    private static func eliminateHiddenPair(_ candidates: inout [UInt16]) -> Bool {
        for unit in units {
            for first in 1...9 {
                let firstBit = bitFor(first)
                let firstHomes = unit.filter { candidates[$0] & firstBit != 0 }
                guard firstHomes.count == 2 else { continue }

                // `(first + 1)...9` would invert to 10...9 when first is 9.
                for second in (first + 1)..<10 {
                    let secondBit = bitFor(second)
                    let secondHomes = unit.filter { candidates[$0] & secondBit != 0 }
                    guard secondHomes == firstHomes else { continue }

                    let mask = firstBit | secondBit
                    var changed = false
                    for cell in firstHomes where candidates[cell] != mask {
                        candidates[cell] = mask
                        changed = true
                    }
                    if changed { return true }
                }
            }
        }
        return false
    }

    private static func eliminateNakedTriple(_ candidates: inout [UInt16]) -> Bool {
        for unit in units {
            let open = unit.filter { candidates[$0].nonzeroBitCount >= 2
                && candidates[$0].nonzeroBitCount <= 3 }
            guard open.count >= 3 else { continue }

            for combo in combinations(open, choose: 3) {
                var union: UInt16 = 0
                for cell in combo { union |= candidates[cell] }
                guard union.nonzeroBitCount == 3 else { continue }

                var changed = false
                for cell in unit where !combo.contains(cell) {
                    if candidates[cell] & union != 0 {
                        candidates[cell] &= ~union
                        changed = true
                    }
                }
                if changed { return true }
            }
        }
        return false
    }

    /// X-Wing: a value with exactly two homes in each of two lines, and those
    /// homes sit in the same two crossing lines. It can be removed elsewhere on
    /// the crossing lines.
    private static func eliminateXWing(_ candidates: inout [UInt16]) -> Bool {
        for orientation in 0..<2 {
            for value in 1...9 {
                let bit = bitFor(value)

                var linesWithTwoHomes: [(line: Int, positions: [Int])] = []
                for line in 0..<9 {
                    let unit = orientation == 0 ? units[line] : units[9 + line]
                    let homes = unit.filter { candidates[$0] & bit != 0 }
                    if homes.count == 2 {
                        linesWithTwoHomes.append((line, homes))
                    }
                }
                guard linesWithTwoHomes.count >= 2 else { continue }

                for first in 0..<linesWithTwoHomes.count {
                    for second in (first + 1)..<linesWithTwoHomes.count {
                        let a = linesWithTwoHomes[first]
                        let b = linesWithTwoHomes[second]

                        let crossA = a.positions.map { orientation == 0 ? SudokuSolver.column(of: $0) : SudokuSolver.row(of: $0) }
                        let crossB = b.positions.map { orientation == 0 ? SudokuSolver.column(of: $0) : SudokuSolver.row(of: $0) }
                        guard Set(crossA) == Set(crossB) else { continue }

                        var changed = false
                        for cross in crossA {
                            let unit = orientation == 0 ? units[9 + cross] : units[cross]
                            for cell in unit {
                                if a.positions.contains(cell) || b.positions.contains(cell) { continue }
                                if candidates[cell] & bit != 0 {
                                    candidates[cell] &= ~bit
                                    changed = true
                                }
                            }
                        }
                        if changed { return true }
                    }
                }
            }
        }
        return false
    }

    /// XY-Wing: a pivot with two candidates and two pincers that each share one
    /// candidate with it, both able to see it. The third candidate is then
    /// impossible anywhere that sees both pincers.
    ///
    /// Written to avoid rescanning: the naive form is quartic and dominates
    /// generation time.
    private static func eliminateXYWing(_ candidates: inout [UInt16]) -> Bool {
        let bivalue = (0..<SudokuPuzzle.cellCount).filter {
            candidates[$0].nonzeroBitCount == 2
        }

        for pivot in bivalue {
            let pivotMask = candidates[pivot]

            for wingX in bits(in: pivotMask) {
                let wingY = pivotMask & ~wingX

                var xWings: [(cell: Int, z: UInt16)] = []
                var yWings: [(cell: Int, z: UInt16)] = []

                for peer in peers[pivot] where candidates[peer].nonzeroBitCount == 2 {
                    let mask = candidates[peer]
                    if mask & wingX != 0, mask & wingY == 0 {
                        xWings.append((peer, mask & ~wingX))
                    } else if mask & wingY != 0, mask & wingX == 0 {
                        yWings.append((peer, mask & ~wingY))
                    }
                }

                for x in xWings {
                    for y in yWings where x.z == y.z {
                        var changed = false
                        for cell in peers[x.cell]
                        where cell != x.cell && cell != y.cell && cell != pivot {
                            guard candidates[cell] & x.z != 0 else { continue }
                            guard sees(cell, y.cell) else { continue }
                            candidates[cell] &= ~x.z
                            changed = true
                        }
                        if changed { return true }
                    }
                }
            }
        }
        return false
    }

    private static func sees(_ a: Int, _ b: Int) -> Bool {
        SudokuSolver.row(of: a) == SudokuSolver.row(of: b)
            || SudokuSolver.column(of: a) == SudokuSolver.column(of: b)
            || SudokuSolver.box(of: a) == SudokuSolver.box(of: b)
    }

    private static func combinations(_ items: [Int], choose k: Int) -> [[Int]] {
        guard k > 0, items.count >= k else { return [] }
        if k == 1 { return items.map { [$0] } }

        var result: [[Int]] = []
        for index in 0...(items.count - k) {
            let rest = Array(items[(index + 1)...])
            for tail in combinations(rest, choose: k - 1) {
                result.append([items[index]] + tail)
            }
        }
        return result
    }
}
