import Foundation

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

    /// The seed the board was dealt from, for a shared game's report.
    let seed: UInt32

    private(set) var stacks: [[Int]]

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

        var stacks = [[Int]](repeating: [], count: VibeTenBoard.columnCount)
        var index = 0
        for column in 0..<VibeTenBoard.columnCount {
            stacks[column] = Array(digits[index..<(index + VibeTenBoard.rowCount)])
            index += VibeTenBoard.rowCount
        }
        self.stacks = stacks
    }

    /// A board with an exact shape, for tests and for the browser to check
    /// itself against.
    init(stacks: [[Int]], seed: UInt32 = 0) {
        self.seed = seed
        self.stacks = stacks
        for column in 0..<stacks.count {
            self.stacks[column] = Array(stacks[column].prefix(VibeTenBoard.rowCount))
        }
    }

    // MARK: - Reading

    var remaining: Int { stacks.reduce(0) { $0 + $1.count } }
    var isCleared: Bool { remaining == 0 }

    func height(ofColumn column: Int) -> Int {
        guard stacks.indices.contains(column) else { return 0 }
        return stacks[column].count
    }

    func value(at position: Position) -> Int? {
        guard stacks.indices.contains(position.column) else { return nil }
        let stack = stacks[position.column]
        guard stack.indices.contains(position.row) else { return nil }
        return stack[position.row]
    }

    /// Every cell that holds a digit, column by column from the bottom.
    var cells: [(position: Position, value: Int)] {
        var cells: [(Position, Int)] = []
        for column in 0..<min(stacks.count, Self.columnCount) {
            for row in 0..<stacks[column].count {
                cells.append((Position(column: column, row: row), stacks[column][row]))
            }
        }
        return cells
    }

    // MARK: - The rule

    /// Two digits pair when they are equal or add up to ten.
    static func valuesPair(_ a: Int, _ b: Int) -> Bool {
        a == b || a + b == 10
    }

    /// Whether a pair can be taken: the digits pair, and they sit on the same
    /// row, column or diagonal with nothing between them.
    ///
    /// "Nothing between" is what makes this a game rather than a search: the gap
    /// has to be empty, and inside a column there is never a gap, so a pair in
    /// one column has to be neighbours.
    func canMatch(_ a: Position, _ b: Position) -> Bool {
        guard a != b,
              let first = value(at: a), let second = value(at: b),
              Self.valuesPair(first, second) else { return false }
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
            if board.value(at: between) != nil { return false }
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

    /// Takes a pair off the board, dropping whatever was above it.
    @discardableResult
    mutating func remove(_ a: Position, _ b: Position) -> Bool {
        guard canMatch(a, b) else { return false }

        // The higher digit goes first, so the lower one is still at its index.
        for position in [a, b].sorted(by: { $0.row > $1.row }) {
            guard stacks.indices.contains(position.column),
                  stacks[position.column].indices.contains(position.row) else { continue }
            stacks[position.column].remove(at: position.row)
        }
        return true
    }
}
