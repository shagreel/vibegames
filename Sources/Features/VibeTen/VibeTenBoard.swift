import Foundation

/// How a taken pair leaves the board.
enum VibeTenMode: String, CaseIterable, Identifiable, Codable {
    /// The pair's digits are gone, and the digits below rise into the hole.
    case remove = "remove"
    /// The pair's digits are dimmed: still there to look at, but gone as far as
    /// the rules are concerned. A row whose every digit is dimmed is cleared at
    /// once, and everything below it rises a row.
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
            return "A matched pair dims and stays put. Dimmed digits are treated as empty, so a pair can be made across them. When every digit in a row is dimmed the row clears and everything below it rises one row."
        }
    }
}

/// One digit on the board.
struct VibeTenCell: Equatable, Codable {
    let value: Int
    /// Taken in dim mode: still drawn, but gone for the rules.
    var dimmed = false
}

/// The Vibe Ten board: columns of digits, hanging from the top.
///
/// A column is stored top-first as a plain array, which is the whole of the
/// gravity rule: take a digit out and the ones below it are already one place
/// higher. There are no gaps inside a column, ever, so "what is below" is just
/// "what is at the next index". The board is anchored at the top — row 0 is the
/// top row — so a row that clears closes upward.
struct VibeTenBoard: Equatable {

    /// The board is always nine columns and always has room for eighteen rows.
    /// What the settings choose is how many of those rows start full of digits:
    /// twelve, fourteen, sixteen or eighteen. The rest is room to grow into.
    static let defaultColumns = 9
    static let minimumRows = 12
    static let maximumRows = 18
    static let defaultStartRows = 18
    static let rowOptions = [12, 14, 16, 18]
    /// One press of the new-row offer adds this many rows, at most.
    static let rowsPerAddOptions = [1, 2, 3, 4]
    static let minimumRowsPerAdd = rowsPerAddOptions.first ?? 1
    static let maximumRowsPerAdd = rowsPerAddOptions.last ?? 1

    /// Every unordered pair the deal can draw from: two of the same number, or
    /// two that add to ten. A pair of fives is both, so it is listed once.
    static let pairOptions: [(Int, Int)] = [
        (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9),
        (1, 9), (2, 8), (3, 7), (4, 6)
    ]

    /// How many columns this board has, and how many rows it has room for. The
    /// capacity is always eighteen; `startRows` decides how many of them the
    /// deal fills.
    let columns: Int
    let rows: Int

    /// Whether the end of a row joins the start of the next: a digit in the last
    /// column can pair with one in the first column of the row below, with
    /// dimmed or empty squares between them.
    let wrapRows: Bool

    /// A cell. `row` is 0 at the top of the board.
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

    /// Deals a board that starts with `startRows` rows of digits.
    ///
    /// The board still has room for eighteen rows; the rows the deal fills hang
    /// from the top, and the space beneath is where the new-row offer grows the
    /// board. The deal is two steps: a set of valid pairs is drawn — pairs of
    /// the same number or pairs that add up to ten — enough of them to fill the
    /// starting rows, and then all of those digits are shuffled and laid out.
    /// So a pair's two halves land anywhere; the board reads as dealt rather
    /// than sorted, and clearing every digit is the aim, not a promise.
    init(seed: UInt32,
         columns: Int = VibeTenBoard.defaultColumns,
         startRows: Int = VibeTenBoard.defaultStartRows,
         wrapRows: Bool = false) {
        let dealtRows = VibeTenBoard.validStartRows(startRows)
        self.seed = seed
        self.columns = columns
        self.rows = VibeTenBoard.maximumRows
        self.wrapRows = wrapRows
        self.stacks = VibeTenBoard.deal(seed: seed, columns: columns, rows: dealtRows)
    }

    /// A starting row count that is a board this game can deal: twelve to
    /// eighteen, and even so every digit has a pair.
    static func validStartRows(_ rows: Int) -> Int {
        var value = min(max(rows, minimumRows), maximumRows)
        if value % 2 == 1 { value -= 1 }
        return value
    }

    /// The pairs a board is dealt from, before their digits are shuffled onto
    /// it. Each one is a pair the rules can take: equal, or adding to ten.
    static func pairChoices(seed: UInt32, count: Int) -> [(Int, Int)] {
        var generator = SeededGenerator(seed: seed)
        var pairs: [(Int, Int)] = []
        pairs.reserveCapacity(count)
        for _ in 0..<count {
            pairs.append(pairOptions[Int.random(in: 0..<pairOptions.count,
                                                using: &generator)])
        }
        return pairs
    }

    /// The digits, drawn as pairs and then laid out at random.
    ///
    /// Both clients have to reproduce the recipe exactly — the same generator,
    /// the same draws in the same order — because a room's board comes back from
    /// one seed. `board.fixtures.json` pins it.
    static func deal(seed: UInt32, columns: Int, rows: Int) -> [[VibeTenCell]] {
        var generator = SeededGenerator(seed: seed)
        let pairCount = columns * rows / 2
        var digits: [Int] = []
        digits.reserveCapacity(pairCount * 2)
        for _ in 0..<pairCount {
            let pair = pairOptions[Int.random(in: 0..<pairOptions.count,
                                              using: &generator)]
            digits.append(pair.0)
            digits.append(pair.1)
        }
        digits.shuffle(using: &generator)
        return (0..<columns).map { column in
            (0..<rows).map { row in
                VibeTenCell(value: digits[column * rows + row])
            }
        }
    }

    /// A board with an exact shape, for tests and for the browser to check
    /// itself against. Every digit starts undimmed. The default is the full
    /// board, so an existing test written for nine columns still has nine.
    init(stacks: [[Int]],
         seed: UInt32 = 0,
         columns: Int = VibeTenBoard.defaultColumns,
         rows: Int = VibeTenBoard.maximumRows,
         wrapRows: Bool = false) {
        self.seed = seed
        self.columns = columns
        self.rows = rows
        self.wrapRows = wrapRows
        self.stacks = stacks.prefix(columns).map { column in
            column.prefix(rows).map { VibeTenCell(value: $0) }
        }
        while self.stacks.count < columns { self.stacks.append([]) }
    }

    /// A board of cells, so a test can start with dimmed digits.
    init(cells: [[VibeTenCell]],
         seed: UInt32 = 0,
         columns: Int = VibeTenBoard.defaultColumns,
         rows: Int = VibeTenBoard.maximumRows,
         wrapRows: Bool = false) {
        self.seed = seed
        self.columns = columns
        self.rows = rows
        self.wrapRows = wrapRows
        self.stacks = cells.prefix(columns).map { Array($0.prefix(rows)) }
        while self.stacks.count < columns { self.stacks.append([]) }
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

    /// Every digit that can still be picked, column by column from the top.
    var cells: [(position: Position, value: Int)] {
        var cells: [(Position, Int)] = []
        for column in 0..<min(stacks.count, columns) {
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
    /// row, column or diagonal with nothing between them — or, when the rows
    /// wrap, at the two ends of the join between one row and the next.
    ///
    /// Dimmed digits are treated as missing, so a line can pass straight
    /// through them.
    func canMatch(_ a: Position, _ b: Position) -> Bool {
        guard a != b,
              let first = cell(at: a), let second = cell(at: b),
              !first.dimmed, !second.dimmed,
              Self.valuesPair(first.value, second.value) else { return false }
        if Self.hasClearLine(from: a, to: b, in: self) { return true }
        guard wrapRows else { return false }
        return Self.hasClearWrapLine(from: a, to: b, in: self)
    }

    /// The rows read end to end: from a square in one row the line runs to the
    /// end of that row, wraps round to the start of the next, and carries on.
    /// Everything it passes through has to be empty or already taken.
    ///
    /// This is what lets the last square of one row pair with the first of the
    /// next — and, with a dimmed square in between, with the second of the next.
    static func hasClearWrapLine(from a: Position, to b: Position, in board: VibeTenBoard) -> Bool {
        let (upper, lower) = a.row < b.row ? (a, b) : (b, a)
        guard lower.row == upper.row + 1 else { return false }
        guard upper.column < board.columns, lower.column >= 0 else { return false }

        for column in (upper.column + 1)..<board.columns {
            if let cell = board.cell(at: Position(column: column, row: upper.row)), !cell.dimmed {
                return false
            }
        }
        for column in 0..<lower.column {
            if let cell = board.cell(at: Position(column: column, row: lower.row)), !cell.dimmed {
                return false
            }
        }
        return true
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
            // is a cascade: a finished row rising into another one clears that
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
                // No `row += 1`: the row below has just risen into this one.
            }
            return MatchResult(rowsCleared: cleared)
        }
    }

    // MARK: - Adding rows

    /// Rows can be added only while the bottom of the grid is free: the board
    /// hangs from the top, so the empty space is underneath it.
    var canAddRow: Bool {
        stacks.allSatisfy { $0.count < rows }
    }

    /// How many rows would fit under the digits as they are.
    var roomForRows: Int {
        max(0, rows - (stacks.map(\.count).max() ?? 0))
    }

    /// Hangs a fresh row under the digits. Nothing else moves: the board is
    /// anchored at the top, so a new row simply extends it downward.
    @discardableResult
    mutating func addRow(_ digits: [Int]) -> Bool {
        guard canAddRow, digits.count >= columns else { return false }
        for column in stacks.indices {
            stacks[column].append(VibeTenCell(value: digits[column]))
        }
        return true
    }
}
