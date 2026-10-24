import XCTest

/// Reading the Vibe Ten board off the screen.
///
/// A board is 162 accessibility elements whose labels carry everything a test
/// needs — "Column 2 row 5: 7", and ", taken" once a digit has been dimmed — so
/// the parsing lives here rather than in each test that wants to look at the
/// grid. The functional tests use it to play, and the screenshot run uses it to
/// take the same pairs a player would have taken.
extension XCUIApplication {

    /// Every cell, dimmed ones included.
    var tenAllCells: [(column: Int, row: Int, value: Int, taken: Bool)] {
        descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "ten.cell."))
            .allElementsBoundByIndex
            .compactMap { element in
                let label = element.label
                guard let colon = label.lastIndex(of: ":") else { return nil }
                let whole = label[label.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                let taken = whole.hasSuffix(", taken")
                let digits = taken ? whole.replacingOccurrences(of: ", taken", with: "") : whole
                guard let value = Int(digits) else { return nil }
                let parts = label[..<colon].split(separator: " ")
                guard parts.count >= 4,
                      let column = Int(parts[1]), let row = Int(parts[3]) else { return nil }
                return (column - 1, row - 1, value, taken)
            }
    }

    /// The digits still in play, which is what a test that is playing the game
    /// cares about: a dimmed digit is on the screen but not on the board.
    var tenCells: [(column: Int, row: Int, value: Int)] {
        tenAllCells.filter { !$0.taken }.map { ($0.column, $0.row, $0.value) }
    }

    /// Taps the digit at a column and row, both counted from zero.
    func tenTap(column: Int, row: Int) {
        let element = descendants(matching: .any)["ten.cell.\(column).\(row)"].firstMatch
        XCTAssertTrue(element.exists, "cell \(column),\(row) should exist")
        element.tap()
    }

    func tenTap(_ cell: TenPlan.Cell) {
        tenTap(column: cell.column, row: cell.row)
    }

    func tenTap(_ position: (column: Int, row: Int)) {
        tenTap(column: position.column, row: position.row)
    }

    /// Taps both digits of a pair, in the order they are given.
    func tenTap(_ pair: ((column: Int, row: Int), (column: Int, row: Int))) {
        tenTap(pair.0)
        tenTap(pair.1)
    }
}

/// A mirror of the board's rules, so a test can work out the takes it wants
/// from one read of the screen instead of one read per take — which, at 162
/// accessibility elements a time, is the whole cost of the test.
///
/// The shape is the app's: nine columns, bottom first, so gravity is just
/// "delete the digit, and the ones above are already one place lower". It is a
/// mirror, not a second opinion: if it and the app ever disagree about what is
/// where, the taps land on the wrong cells and the test fails rather than
/// quietly passing.
struct TenPlan {

    struct Cell: Equatable {
        let column: Int
        let row: Int
        let value: Int
    }

    private var stacks: [[Int]]

    init(cells: [(column: Int, row: Int, value: Int)]) {
        var stacks = Array(repeating: [Int](), count: 9)
        for column in 0..<9 {
            let inColumn = cells.filter { $0.column == column }
            guard let tallest = inColumn.map(\.row).max() else { continue }
            var values = Array(repeating: 0, count: tallest + 1)
            for cell in inColumn { values[cell.row] = cell.value }
            stacks[column] = values
        }
        self.stacks = stacks
    }

    var height: (Int) -> Int {
        { [stacks] column in stacks[column].count }
    }

    private func value(column: Int, row: Int) -> Int? {
        guard stacks.indices.contains(column), stacks[column].indices.contains(row) else { return nil }
        return stacks[column][row]
    }

    func cell(column: Int, row: Int) -> Cell? {
        value(column: column, row: row).map { Cell(column: column, row: row, value: $0) }
    }

    private func cell(_ position: (column: Int, row: Int)) -> Cell? {
        cell(column: position.column, row: position.row)
    }

    /// Two digits pair when they are equal or add up to ten, on one line, with
    /// nothing in between.
    func canMatch(_ a: (column: Int, row: Int), _ b: (column: Int, row: Int)) -> Bool {
        guard a != b,
              let first = value(column: a.column, row: a.row),
              let second = value(column: b.column, row: b.row),
              first == second || first + second == 10 else { return false }

        let down = b.row - a.row
        let across = b.column - a.column
        let steps = max(abs(down), abs(across))
        guard steps > 0,
              down == 0 || across == 0 || abs(down) == abs(across) else { return false }

        for step in 1..<steps {
            let between = (column: a.column + step * (across / steps),
                           row: a.row + step * (down / steps))
            if value(column: between.column, row: between.row) != nil { return false }
        }
        return true
    }

    /// Takes a pair off the board, dropping whatever was above it.
    mutating func take(_ a: (column: Int, row: Int), _ b: (column: Int, row: Int)) -> Bool {
        guard canMatch(a, b) else { return false }
        for position in [a, b].sorted(by: { $0.row > $1.row }) {
            stacks[position.column].remove(at: position.row)
        }
        return true
    }

    /// Whether a new row would fit: no column reaches the top of the grid.
    var hasRoomForARow: Bool {
        stacks.allSatisfy { $0.count < 18 }
    }

    /// Every pair on the board, in reading order.
    private var matches: [((column: Int, row: Int), (column: Int, row: Int))] {
        var all: [(column: Int, row: Int)] = []
        for column in 0..<9 {
            for row in 0..<stacks[column].count { all.append((column, row)) }
        }
        var pairs: [((column: Int, row: Int), (column: Int, row: Int))] = []
        for first in all.indices {
            for second in (first + 1)..<all.count where canMatch(all[first], all[second]) {
                pairs.append((all[first], all[second]))
            }
        }
        return pairs
    }

    /// The first pair on the board, as a player glancing at it would take it.
    func firstPair() -> ((column: Int, row: Int), (column: Int, row: Int))? {
        matches.first
    }

    /// A set of pairs that can all be taken in dim mode: nothing moves on that
    /// board, and a dimmed digit never blocks a line, so any set of pairs that
    /// was legal before the first take stays legal for every take after it.
    func pairsForDimming(_ count: Int) -> [((column: Int, row: Int), (column: Int, row: Int))] {
        var used = Set<String>()
        var chosen: [((column: Int, row: Int), (column: Int, row: Int))] = []
        for pair in matches {
            let keys = ["\(pair.0.column)-\(pair.0.row)", "\(pair.1.column)-\(pair.1.row)"]
            guard keys.allSatisfy({ !used.contains($0) }) else { continue }
            used.formUnion(keys)
            chosen.append(pair)
            if chosen.count == count { break }
        }
        return chosen
    }

    /// The pair worth taking to clear the top of the grid: one that takes from a
    /// column still reaching the top, because a digit taken anywhere in a column
    /// lowers that column by one. Prefers a pair that lowers two of them.
    func pairFreeingTheTopRow() -> ((column: Int, row: Int), (column: Int, row: Int))? {
        let full = Set((0..<9).filter { stacks[$0].count == 18 })
        var best: ((column: Int, row: Int), (column: Int, row: Int))?
        var bestScore = 0
        for pair in matches {
            let score = (full.contains(pair.0.column) ? 1 : 0) + (full.contains(pair.1.column) ? 1 : 0)
            if score > bestScore {
                bestScore = score
                best = pair
            }
        }
        return best
    }

    /// A plan of takes that empties the top row of the grid, if the board allows
    /// it. Nil means the board has no way to shorten a column that still reaches
    /// the top — the offer can never appear on this deal.
    static func takesFreeingTheTopRow(startingFrom cells: [(column: Int, row: Int, value: Int)],
                                     limit: Int = 60)
        -> [((column: Int, row: Int), (column: Int, row: Int))]? {
        var plan = TenPlan(cells: cells)
        var takes: [((column: Int, row: Int), (column: Int, row: Int))] = []
        while !plan.hasRoomForARow, takes.count < limit {
            guard let pair = plan.pairFreeingTheTopRow(), plan.take(pair.0, pair.1) else { return nil }
            takes.append(pair)
        }
        return plan.hasRoomForARow ? takes : nil
    }
}

extension XCTestCase {

    /// A screenshot of whatever is on screen, kept in the test report.
    func tenAttach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
