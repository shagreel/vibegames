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

/// How much of the grid a game starts with.
enum VibeTenStartFill: String, CaseIterable, Identifiable {
    case full = "full"
    /// A third of the rows, with the empty space underneath: the new-row offer
    /// is what fills it in.
    case third = "third"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: return "Full"
        case .third: return "One third"
        }
    }

    var blurb: String {
        switch self {
        case .full: return "The whole grid, as it has always been."
        case .third: return "A third of the rows to start with, and room below for the new rows to fill."
        }
    }
}

/// How hard a board is to take apart.
///
/// Every level is dealt so that a solution exists — the board is built out of
/// pairs, in an order that is itself a way through. What changes is what a pair
/// is nested in: at Easy every pair is already next to itself; at Medium pairs
/// are nested across a row, down a column, corner to corner, or round the join
/// between two rows; and at Hard whole rows and whole columns are nested, which
/// makes for longer chains of "clear that before this".
///
/// All four of those are the game's own lines — a pair can be found along a row,
/// a column, a diagonal, or, when the rows join end to end, across the join — so
/// a hard board can need a column cleared before a row, which is a different
/// puzzle from a row before a row.
enum VibeTenDifficulty: String, CaseIterable, Identifiable, Codable {
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

    var blurb: String {
        switch self {
        case .easy:
            return "Every pair starts side by side: a gentle board."
        case .medium:
            return "Pairs are nested across a row, down a column, corner to corner, or round the join between two rows."
        case .hard:
            return "Whole rows and whole columns are nested: the pair at the edge of a band only comes together once the digits around it are gone."
        }
    }
}

/// How one band of rows is filled. A band is a short block of rows dealt as a
/// unit, so a pair never spans two bands and every band can be cleared on its
/// own. The patterns are the ways a pair can be found: side by side, and nested
/// along one of the four lines — a row, a column, a diagonal, or the join.
enum VibeTenBandPattern: Equatable {
    /// Side by side along each row, with any odd column paired down the band.
    case sideBySide
    /// Nested along each row, with any odd column nested down the band.
    case rows
    /// Nested down each column.
    case columns
    /// Nested corner to corner, two columns and one row at a time.
    case diagonals
    /// Nested round the join: the last square of a row to the first of the next.
    case wrap
}

/// A block of rows and the way it is filled.
struct VibeTenBand: Equatable {
    let start: Int
    let height: Int
    let pattern: VibeTenBandPattern

    var end: Int { start + height }
}

/// A pair in the order it is dealt, at the rows and columns it will occupy in
/// the finished board.
private struct DealTarget {
    let first: VibeTenBoard.Position
    let second: VibeTenBoard.Position
}

/// One pair, and where it was placed. In a nested band a pair is put in before
/// the pairs that cover it, so the row it lands in is also the row it will be
/// taken from when the placements are read backwards.
struct DealStep: Equatable {
    let first: VibeTenBoard.Position
    let second: VibeTenBoard.Position
    let firstValue: Int
    let secondValue: Int
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
/// top row — so a row that clears closes upward, and a board that starts part
/// filled hangs from the top with the empty space beneath it.
struct VibeTenBoard: Equatable {

    /// The size a board is unless the player asks for another. Columns run
    /// 6–9 and rows 12–18, so every shape is a grid that still fills the screen
    /// with bigger digits.
    static let defaultColumns = 9
    static let defaultRows = 18
    static let columnOptions = [6, 7, 8, 9]
    static let rowOptions = [12, 14, 16, 18]
    /// One press of the new-row offer adds this many rows, at most.
    static let rowsPerAddOptions = [1, 2, 3, 4]
    static let minimumRowsPerAdd = rowsPerAddOptions.first ?? 1
    static let maximumRowsPerAdd = rowsPerAddOptions.last ?? 1

    /// How many columns and rows this board has. A room's board is dealt from
    /// the seed *and* these two numbers, so the size is part of the deal.
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

    /// How the board was dealt. Part of the deal, like the seed and the shape:
    /// a room's board has to be the same on every device.
    let difficulty: VibeTenDifficulty

    private(set) var stacks: [[VibeTenCell]]

    // MARK: - Building

    /// Deals a board, optionally starting part-filled.
    ///
    /// The deal is always the full grid — that is what keeps the seed meaning
    /// one thing — and `startRows` then keeps that many rows off the top of each
    /// column. Whole bands are kept, so a part-filled board is the top of the
    /// same deal with every pair it holds still whole, which is what both
    /// clients reproduce from the same numbers.
    init(seed: UInt32,
         columns: Int = VibeTenBoard.defaultColumns,
         rows: Int = VibeTenBoard.defaultRows,
         startRows: Int? = nil,
         wrapRows: Bool = false,
         difficulty: VibeTenDifficulty = .easy) {
        self.seed = seed
        self.columns = columns
        self.rows = rows
        self.wrapRows = wrapRows
        self.difficulty = difficulty
        let planned = VibeTenBoard.plan(seed: seed,
                                        columns: columns,
                                        rows: rows,
                                        difficulty: difficulty,
                                        wrapRows: wrapRows)
        let wanted = max(1, min(rows, startRows ?? rows))
        let kept = planned.bandEnds.last(where: { $0 <= wanted })
            ?? planned.bandEnds.first
            ?? wanted
        self.stacks = planned.stacks.map { Array($0.prefix(kept)) }
    }

    /// The digits, dealt so that every board can be cleared.
    ///
    /// A random shuffle of the right digits is a board with a random chance of
    /// being finishable — usually none. So the board is built the other way
    /// round: the grid is cut into bands of rows, each band is filled with pairs
    /// nested along its own lines, and the pairs are *placed* one at a time in an
    /// order where each can be seen. Read backwards, the placements are a way to
    /// clear the board.
    ///
    /// Both clients have to reproduce the recipe exactly — the same generator,
    /// the same draws in the same order — because a room's board comes back from
    /// one seed. `board.fixtures.json` pins it.
    static func deal(seed: UInt32,
                     columns: Int,
                     rows: Int,
                     difficulty: VibeTenDifficulty = .easy,
                     wrapRows: Bool = false) -> [[VibeTenCell]] {
        plan(seed: seed, columns: columns, rows: rows,
             difficulty: difficulty, wrapRows: wrapRows).stacks
    }

    /// The placing order, the board it makes, and where its bands end.
    ///
    /// Kept separate from `deal` so a test can check the thing that matters:
    /// every pair could be seen when it was placed, and the board it leaves is
    /// full. Read backwards, the steps are a way to clear the board.
    static func plan(seed: UInt32,
                     columns: Int,
                     rows: Int,
                     difficulty: VibeTenDifficulty,
                     wrapRows: Bool = false) -> (steps: [DealStep],
                                                  stacks: [[VibeTenCell]],
                                                  bandEnds: [Int]) {
        var generator = SeededGenerator(seed: seed)

        let heights = bandHeights(rows: rows, difficulty: difficulty,
                                  wrapRows: wrapRows, generator: &generator)
        let patterns = bandPatterns(heights: heights, difficulty: difficulty,
                                    wrapRows: wrapRows, generator: &generator)
        var start = 0
        let bands = zip(heights, patterns).map { pair -> VibeTenBand in
            let band = VibeTenBand(start: start, height: pair.0, pattern: pair.1)
            start += pair.0
            return band
        }

        let deck = makeDeck(pairs: columns * rows / 2, generator: &generator)

        // The pairs of every band, in placing order. Bands are dealt top to
        // bottom, so clearing the finished board runs bottom to top: nothing
        // below a band is left to move it, and a band comes apart from the
        // inside out.
        let targets = bands.flatMap { targets(for: $0, columns: columns) }

        var columnsCells = [[(row: Int, cell: VibeTenCell)]](repeating: [], count: columns)
        var steps: [DealStep] = []
        var nextPair = 0

        /// The next pair of digits, either way round.
        func takePair() -> (Int, Int) {
            let pair = deck[nextPair]
            nextPair += 1
            return Int.random(in: 0...1, using: &generator) == 1 ? (pair.1, pair.0) : pair
        }

        /// Puts one digit into its column in front of every digit that will end
        /// up below it, and says which row it landed in.
        ///
        /// The digits already there are the ones placed earlier, which are the
        /// ones that end up below it: that is how a pair laid down first ends up
        /// *outside* the pairs placed after it.
        func place(_ value: Int, at target: Position) -> Position {
            var index = 0
            while index < columnsCells[target.column].count,
                  columnsCells[target.column][index].row < target.row {
                index += 1
            }
            columnsCells[target.column].insert((row: target.row, cell: VibeTenCell(value: value)),
                                               at: index)
            return Position(column: target.column, row: index)
        }

        for target in targets {
            let digits = takePair()
            // The upper square of a pair goes in first when they share a column,
            // so that the lower one lands underneath it.
            let firstIsUpper = target.first.row <= target.second.row
            let upper = firstIsUpper ? target.first : target.second
            let lower = firstIsUpper ? target.second : target.first
            let upperValue = firstIsUpper ? digits.0 : digits.1
            let lowerValue = firstIsUpper ? digits.1 : digits.0
            let placedUpper = place(upperValue, at: upper)
            let placedLower = place(lowerValue, at: lower)
            steps.append(DealStep(first: placedUpper,
                                  second: placedLower,
                                  firstValue: upperValue,
                                  secondValue: lowerValue))
        }

        return (steps,
                columnsCells.map { $0.map(\.cell) },
                bands.map(\.end))
    }

    /// The bands a full board is dealt in.
    ///
    /// Easy and Medium are two rows at a time. Hard is taller, so a pair can be
    /// nested down a column as well as across a row, and it opens with a two-row
    /// band of diagonals — and, when the rows join end to end, one of wrap
    /// pairs — so those lines are always part of the puzzle.
    static func bandHeights(rows: Int,
                            difficulty: VibeTenDifficulty,
                            wrapRows: Bool,
                            generator: inout SeededGenerator) -> [Int] {
        guard rows > 2 else { return [rows] }
        switch difficulty {
        case .easy, .medium:
            return Array(repeating: 2, count: rows / 2)
        case .hard:
            var heights: [Int] = []
            var remaining = rows
            // A deep band first, then the two-row ones: that puts a band
            // boundary at four and at six rows, which is where a third of every
            // shape falls, so "start with one third" keeps a whole band instead
            // of dropping to the first two rows.
            heights.append(4)
            remaining -= 4
            if wrapRows {
                heights.append(2)
                remaining -= 2
            }
            heights.append(2)
            remaining -= 2
            while remaining > 0 {
                let options = [4, 6, 8].filter { height in
                    height <= remaining && (remaining - height == 0 || remaining - height >= 4)
                }
                let height: Int
                if options.isEmpty {
                    height = remaining
                } else if options.count == 1 {
                    height = options[0]
                } else {
                    height = options[Int.random(in: 0..<options.count, using: &generator)]
                }
                heights.append(height)
                remaining -= height
            }
            return heights
        }
    }

    /// How each band is filled.
    static func bandPatterns(heights: [Int],
                             difficulty: VibeTenDifficulty,
                             wrapRows: Bool,
                             generator: inout SeededGenerator) -> [VibeTenBandPattern] {
        switch difficulty {
        case .easy:
            return heights.map { _ in .sideBySide }
        case .medium:
            return heights.indices.map { index in
                if index == 0 { return wrapRows ? .wrap : .diagonals }
                return VibeTenBoard.randomPattern(wrapRows: wrapRows, generator: &generator)
            }
        case .hard:
            var patterns: [VibeTenBandPattern] = []
            var sawTwoRow = false
            var sawTall = false
            for height in heights {
                if height == 2 {
                    patterns.append(wrapRows && !sawTwoRow ? .wrap : .diagonals)
                    sawTwoRow = true
                    continue
                }
                // Tall bands are whole rows or whole columns, and they alternate
                // so a hard board is not all one line.
                if sawTall {
                    patterns.append(patterns.last == .columns ? .rows : .columns)
                } else {
                    patterns.append(Int.random(in: 0...1, using: &generator) == 1 ? .columns : .rows)
                    sawTall = true
                }
            }
            return patterns
        }
    }

    /// A pattern for a two-row Medium band: mostly rows, some columns and
    /// diagonals, and the join when the rules allow it.
    static func randomPattern(wrapRows: Bool, generator: inout SeededGenerator) -> VibeTenBandPattern {
        var choices: [VibeTenBandPattern] = [.rows, .rows, .rows,
                                             .columns, .columns,
                                             .diagonals, .diagonals]
        if wrapRows { choices.append(contentsOf: [.wrap, .wrap]) }
        return choices[Int.random(in: 0..<choices.count, using: &generator)]
    }

    /// The digits a board is dealt from.
    ///
    /// Balanced so every digit appears about as often as every other, and with
    /// both kinds of pair guaranteed: some equal pairs (two of a number) and
    /// plenty that add to ten. A pair of fives is both, so it gets its own
    /// smaller share of the deck.
    static func makeDeck(pairs: Int, generator: inout SeededGenerator) -> [(Int, Int)] {
        // A fives-pair puts two 5s on the board and every other pair puts one of
        // each digit, so the fives need half as many pairs as the others to keep
        // the digits even.
        let fivePairs = (2 * pairs + 9) / 18
        let otherPairs = pairs - fivePairs

        var order = Array(0..<4)
        order.shuffle(using: &generator)
        var groupPairs = [Int](repeating: otherPairs / 4, count: 4)
        for index in 0..<(otherPairs % 4) { groupPairs[order[index]] += 1 }

        var deck: [(Int, Int)] = []
        for group in 0..<5 {
            if group == 4 {
                deck.append(contentsOf: Array(repeating: (5, 5), count: fivePairs))
                continue
            }
            let count = groupPairs[group]
            let low = group + 1
            let high = 10 - low
            guard count >= 3 else {
                deck.append(contentsOf: Array(repeating: (low, high), count: max(0, count)))
                continue
            }
            // At least one equal pair, and at least one that adds to ten: the
            // board is the game, and both kinds of pair are the game.
            let most = min(2, (count - 1) / 2)
            let equal = most == 1 ? 1 : Int.random(in: 1...most, using: &generator)
            deck.append(contentsOf: Array(repeating: (low, low), count: equal))
            deck.append(contentsOf: Array(repeating: (high, high), count: equal))
            deck.append(contentsOf: Array(repeating: (low, high), count: count - 2 * equal))
        }
        deck.shuffle(using: &generator)
        return deck
    }

    /// The pairs of a band, in placing order: outermost first, so every pair can
    /// see itself when it arrives and the pairs that cover it arrive later.
    private static func targets(for band: VibeTenBand, columns: Int) -> [DealTarget] {
        var targets: [DealTarget] = []
        let top = band.start
        let bottom = band.start + band.height - 1

        func add(_ firstColumn: Int, _ firstRow: Int,
                 _ secondColumn: Int, _ secondRow: Int) {
            targets.append(DealTarget(first: Position(column: firstColumn, row: firstRow),
                                      second: Position(column: secondColumn, row: secondRow)))
        }

        switch band.pattern {
        case .sideBySide:
            let last = columns - (columns % 2 == 0 ? 1 : 2)
            for row in top...bottom {
                var column = 0
                while column < last {
                    add(column, row, column + 1, row)
                    column += 2
                }
            }
            if columns % 2 == 1 {
                add(columns - 1, top, columns - 1, bottom)
            }

        case .rows:
            let last = columns - (columns % 2 == 0 ? 1 : 2)
            for row in top...bottom {
                var low = 0
                var high = last
                while low < high {
                    add(low, row, high, row)
                    low += 1
                    high -= 1
                }
            }
            if columns % 2 == 1 {
                // The odd column left over by every row is nested down the band.
                var low = top
                var high = bottom
                while low < high {
                    add(columns - 1, low, columns - 1, high)
                    low += 1
                    high -= 1
                }
            }

        case .columns:
            for column in 0..<columns {
                var low = top
                var high = bottom
                while low < high {
                    add(column, low, column, high)
                    low += 1
                    high -= 1
                }
            }

        case .diagonals:
            var column = 0
            while column + 1 < columns {
                add(column, top, column + 1, bottom)
                add(column, bottom, column + 1, top)
                column += 2
            }
            if column < columns {
                add(column, top, column, bottom)
            }

        case .wrap:
            // The two ends of the join. The pair that runs the whole way round
            // is placed first and ends up outermost; the pair that owns the join
            // itself goes next; the columns between them are filled with
            // vertical pairs, which end up inside both. So the finished band is
            // a long wrap pair holding a short wrap pair holding the middle.
            if columns > 2 {
                add(0, top, columns - 1, bottom)
                add(columns - 1, top, 0, bottom)
                for column in 1..<(columns - 1) {
                    add(column, top, column, bottom)
                }
            } else {
                add(0, top, columns - 1, bottom)
            }
        }

        return targets
    }

    /// A board with an exact shape, for tests and for the browser to check
    /// itself against. Every digit starts undimmed. The default is the full
    /// board, so an existing test written for nine columns still has nine.
    init(stacks: [[Int]],
         seed: UInt32 = 0,
         columns: Int = VibeTenBoard.defaultColumns,
         rows: Int = VibeTenBoard.defaultRows,
         wrapRows: Bool = false,
         difficulty: VibeTenDifficulty = .easy) {
        self.seed = seed
        self.columns = columns
        self.rows = rows
        self.wrapRows = wrapRows
        self.difficulty = difficulty
        self.stacks = stacks.prefix(columns).map { column in
            column.prefix(rows).map { VibeTenCell(value: $0) }
        }
        while self.stacks.count < columns { self.stacks.append([]) }
    }

    /// A board of cells, so a test can start with dimmed digits.
    init(cells: [[VibeTenCell]],
         seed: UInt32 = 0,
         columns: Int = VibeTenBoard.defaultColumns,
         rows: Int = VibeTenBoard.defaultRows,
         wrapRows: Bool = false,
         difficulty: VibeTenDifficulty = .easy) {
        self.seed = seed
        self.columns = columns
        self.rows = rows
        self.wrapRows = wrapRows
        self.difficulty = difficulty
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
