import Foundation

/// How a taken pair leaves the board.
enum VibeTenMode: String, CaseIterable, Identifiable {
    /// The pair's digits are gone, and the digits above drop into the hole.
    case remove = "remove"
    /// The pair's digits are dimmed: still there to look at, but gone as far as
    /// the rules are concerned. A row whose every digit is dimmed is cleared at
    /// once, and the board drops a row.
    case dim = "dim"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remove: return "Remove"
        case .dim: return "Dim"
        }
    }

    var blurb: String {
        switch self {
        case .remove:
            return "A matched pair disappears and the digits above fall into the gap."
        case .dim:
            return "A matched pair dims and stays put. Dimmed digits are treated as empty, so a pair can be made across them. When every digit in a row is dimmed the row clears and everything above drops one row."
        }
    }
}

/// One digit on the board.
struct VibeTenCell: Equatable {
    let value: Int
    /// Taken in dim mode: still drawn, but gone for the rules.
    var dimmed = false
}

/// The Vibe Ten board: nine columns of digits, packed at the bottom.
///
/// A column is stored bottom-first as a plain array, which is the whole of the
/// gravity rule: take a digit out and the ones above it are already one place
/// lower. There are no gaps inside a column, ever, so "what is above" is just
/// "what is at the next index".
struct VibeTenBoard: Equatable {

    static let columnCount = 9
    static let rowCount = 18

    /// A cell. `row` is 0 at the bottom of the board.
    struct Position: Hashable {
        let column: Int
        let row: Int
    }

    /// What a match did, for the screen to animate or count.
    struct MatchResult: Equatable {
        /// Rows cleared in dim mode because every digit in them was dimmed.
        var rowsCleared: [Int] = []
    }

    /// The seed the board was dealt from, for a shared game's report.
    let seed: UInt32

    private(set) var stacks: [[VibeTenCell]]

    // MARK: - Building

    /// Deal a new board. A shared game stores only the seed, so every device —
    /// phone or browser — deals the identical 162 digits from it.
    init(seed: UInt32) {
        self.seed = seed
        var generator = SeededGenerator(seed: seed)
        var digits: [Int] = []
        for value in 1...9 {
            digits.append(contentsOf: Array(repeating: value, count: VibeTenBoard.rowCount))
        }
        digits.shuffle(using: &generator)

        var stacks = [[VibeTenCell]](repeating: [], count: VibeTenBoard.columnCount)
        var index = 0
        for column in 0..<VibeTenBoard.columnCount {
            stacks[column] = digits[index..<(index + VibeTenBoard.rowCount)]
                .map { VibeTenCell(value: $0) }
            index += VibeTenBoard.rowCount
        }
        self.stacks = stacks
    }

    /// A board with an exact shape, for tests and for the browser to check
    /// itself against. Every digit starts undimmed.
    init(stacks: [[Int]], seed: UInt32 = 0) {
        self.seed = seed
        self.stacks = stacks.prefix(VibeTenBoard.columnCount).map { column in
            column.prefix(VibeTenBoard.rowCount).map { VibeTenCell(value: $0) }
        }
        while self.stacks.count < VibeTenBoard.columnCount { self.stacks.append([]) }
    }

    /// A board of cells, so a test can start with dimmed digits.
    init(cells: [[VibeTenCell]], seed: UInt32 = 0) {
        self.seed = seed
        self.stacks = cells.prefix(VibeTenBoard.columnCount).map { column in
            Array(column.prefix(VibeTenBoard.rowCount))
        }
        while self.stacks.count < VibeTenBoard.columnCount { self.stacks.append([]) }
    }

    // MARK: - Reading

    var remaining: Int {
        stacks.reduce(0) { $0 + $1.filter { !$0.dimmed }.count }
    }

    /// The digits in the shape the fixture and the browser use.
    var values: [[Int]] { stacks.map { $0.map(\.value) } }

    var isCleared: Bool { stacks.allSatisfy(\.isEmpty) }

    func height(ofColumn column: Int) -> Int {
        guard stacks.indices.contains(column) else { return 0 }
        return stacks[column].count
    }

    func cell(at position: Position) -> VibeTenCell? {
        guard stacks.indices.contains(position.column) else { return nil }
        let stack = stacks[position.column]
        guard stack.indices.contains(position.row) else { return nil }
        return stack[position.row]
    }

    func value(at position: Position) -> Int? { cell(at: position)?.value }

    /// Dimmed digits count as gone: they cannot be picked, and a line can be
    /// drawn through them.
    func isDimmed(at position: Position) -> Bool {
        cell(at: position)?.dimmed ?? true
    }

    /// Every digit that can still be picked, column by column from the bottom.
    var cells: [(position: Position, value: Int)] {
        var cells: [(Position, Int)] = []
        for column in 0..<min(stacks.count, Self.columnCount) {
            for row in 0..<stacks[column].count where !stacks[column][row].dimmed {
                cells.append((Position(column: column, row: row), stacks[column][row].value))
            }
        }
        return cells
    }

    /// Whether a row exists and every digit in it has been taken.
    func isRowComplete(_ row: Int) -> Bool {
        var sawDigit = false
        for column in stacks {
            guard column.indices.contains(row) else { return false }
            guard column[row].dimmed else { return false }
            sawDigit = true
        }
        return sawDigit
    }

    // MARK: - The rule

    /// Two digits pair when they are equal or add up to ten.
    static func valuesPair(_ a: Int, _ b: Int) -> Bool {
        a == b || a + b == 10
    }

    /// Whether a pair can be taken: the digits pair, and they sit on the same
    /// row, column or diagonal with nothing between them.
    ///
    /// Dimmed digits are treated as missing, so a line can pass straight
    /// through them.
    func canMatch(_ a: Position, _ b: Position) -> Bool {
        guard a != b,
              let first = cell(at: a), let second = cell(at: b),
              !first.dimmed, !second.dimmed,
              Self.valuesPair(first.value, second.value) else { return false }
        return Self.hasClearLine(from: a, to: b, in: self)
    }

    static func hasClearLine(from a: Position, to b: Position, in board: VibeTenBoard) -> Bool {
        let down = b.row - a.row
        let across = b.column - a.column
        let steps = max(abs(down), abs(across))
        guard steps > 0 else { return false }
        // Only along a row, a column, or a diagonal.
        guard down == 0 || across == 0 || abs(down) == abs(across) else { return false }

        let stepDown = down / steps
        let stepAcross = across / steps
        for step in 1..<steps {
            let between = Position(column: a.column + step * stepAcross,
                                   row: a.row + step * stepDown)
            if let cell = board.cell(at: between), !cell.dimmed { return false }
        }
        return true
    }

    /// Every pair that can be taken right now.
    func availableMatches() -> [(Position, Position)] {
        let cells = cells
        var matches: [(Position, Position)] = []
        for first in cells.indices {
            for second in (first + 1)..<cells.count {
                if canMatch(cells[first].position, cells[second].position) {
                    matches.append((cells[first].position, cells[second].position))
                }
            }
        }
        return matches
    }

    var hasMoves: Bool {
        let cells = cells
        for first in cells.indices {
            for second in (first + 1)..<cells.count {
                if canMatch(cells[first].position, cells[second].position) { return true }
            }
        }
        return false
    }

    // MARK: - Playing

    /// Takes a pair, the way the chosen mode says to.
    @discardableResult
    mutating func take(_ a: Position, _ b: Position, mode: VibeTenMode) -> MatchResult? {
        guard canMatch(a, b) else { return nil }

        switch mode {
        case .remove:
            for position in [a, b].sorted(by: { $0.row > $1.row }) {
                guard stacks.indices.contains(position.column),
                      stacks[position.column].indices.contains(position.row) else { continue }
                stacks[position.column].remove(at: position.row)
            }
            return MatchResult()

        case .dim:
            for position in [a, b] {
                guard stacks.indices.contains(position.column),
                      stacks[position.column].indices.contains(position.row) else { continue }
                stacks[position.column][position.row].dimmed = true
            }
            // A row is cleared once every digit in it has been taken. Clearing
            // is a cascade: a row dropping onto another finished row clears that
            // one too, which is the same board as clearing both at once.
            var cleared: [Int] = []
            var row = 0
            while row < (stacks.map(\.count).max() ?? 0) {
                guard isRowComplete(row) else {
                    row += 1
                    continue
                }
                for column in stacks.indices where stacks[column].indices.contains(row) {
                    stacks[column].remove(at: row)
                }
                cleared.append(row)
                // No `row += 1`: the row above has just dropped into this one.
            }
            return MatchResult(rowsCleared: cleared)
        }
    }

    // MARK: - Adding a row

    /// A new row can go on the bottom only while the top of the grid is free.
    var canAddRow: Bool {
        stacks.allSatisfy { $0.count < Self.rowCount }
    }

    /// Puts a fresh row on the bottom, pushing everything else up one row.
    ///
    /// In `dim` mode the taken digits go up with their rows; the new row has
    /// nothing taken in it, which is what gives the player somewhere to play.
    @discardableResult
    mutating func addRow(_ digits: [Int]) -> Bool {
        guard canAddRow, digits.count >= Self.columnCount else { return false }
        for column in stacks.indices {
            stacks[column].insert(VibeTenCell(value: digits[column]), at: 0)
        }
        return true
    }
}
