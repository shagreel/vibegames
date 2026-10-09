import XCTest
@testable import VibeGames

/// The board has to show every card without scrolling, on anything from an
/// iPhone in landscape to a 13-inch iPad. Getting that wrong is not a crash, it
/// is a card you cannot reach, so the sizes are checked rather than eyeballed.
final class TrioBoardLayoutTests: XCTestCase {

    private let aspect = TrioCardView.aspectRatio

    /// The one thing that must never be false.
    private func assertFits(_ layout: TrioBoardLayout,
                            count: Int,
                            size: CGSize,
                            file: StaticString = #filePath,
                            line: UInt = #line) {
        let width = CGFloat(layout.columns) * layout.cardWidth
            + TrioBoardLayout.spacing * CGFloat(layout.columns - 1)
        let height = CGFloat(layout.rows) * (layout.cardWidth / aspect)
            + TrioBoardLayout.spacing * CGFloat(layout.rows - 1)

        XCTAssertLessThanOrEqual(width, size.width + 0.001,
                                 "\(count) cards over \(layout.columns) columns are \(width) wide in \(size.width)",
                                 file: file, line: line)
        XCTAssertLessThanOrEqual(height, size.height + 0.001,
                                 "\(count) cards over \(layout.rows) rows are \(height) tall in \(size.height)",
                                 file: file, line: line)
        XCTAssertEqual(layout.columns * layout.rows >= count, true,
                       "\(layout.columns)x\(layout.rows) cannot hold \(count) cards",
                       file: file, line: line)
    }

    func testEveryRealisticScreenFitsTheWholeTable() {
        let screens: [(String, CGSize)] = [
            ("iPhone 17 Pro portrait", CGSize(width: 378, height: 700)),
            ("iPhone 17 Pro Max portrait", CGSize(width: 416, height: 760)),
            ("iPhone SE portrait", CGSize(width: 351, height: 500)),
            ("iPhone 17 Pro landscape", CGSize(width: 850, height: 260)),
            ("iPad Pro 11 portrait", CGSize(width: 810, height: 1000)),
            ("iPad Pro 11 landscape", CGSize(width: 1150, height: 650)),
            ("iPad Pro 13 portrait", CGSize(width: 1008, height: 1200)),
            ("iPad Pro 13 landscape", CGSize(width: 1352, height: 820)),
            ("iPad Slide Over", CGSize(width: 300, height: 900)),
        ]

        for (name, size) in screens {
            // The deck grows by three whenever it runs out of trios, so the
            // board has to cope with more than twelve.
            for count in [12, 15, 18, 21, 24] {
                let layout = TrioBoardLayout.fitting(count, in: size)
                assertFits(layout, count: count, size: size)
            }
        }
    }

    func testTheCardsAreAsBigAsTheyCanBe() {
        let size = CGSize(width: 402, height: 700)
        let chosen = TrioBoardLayout.fitting(12, in: size)

        // Nothing fits twelve cards into this space bigger than the choice made.
        for columns in 1...12 {
            let rows = (12 + columns - 1) / columns
            let cellWidth = (size.width - TrioBoardLayout.spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (size.height - TrioBoardLayout.spacing * CGFloat(rows - 1)) / CGFloat(rows)
            let width = min(cellWidth, cellHeight * aspect)
            XCTAssertLessThanOrEqual(width, chosen.cardWidth + 1.001,
                                     "\(columns) columns would have been bigger")
        }
    }

    /// Three across is the shape the game was designed around, so it should win
    /// wherever it is not actually the smaller arrangement.
    func testThreeAcrossIsKeptOnAPhone() {
        XCTAssertEqual(TrioBoardLayout.fitting(12, in: CGSize(width: 378, height: 700)).columns, 3)
        XCTAssertEqual(TrioBoardLayout.fitting(12, in: CGSize(width: 416, height: 760)).columns, 3)
    }

    /// A short, wide window is the case that forces a different shape: four rows
    /// of twelve do not fit, but six across do.
    func testAShortWideScreenUsesMoreColumns() {
        let layout = TrioBoardLayout.fitting(12, in: CGSize(width: 850, height: 260))
        XCTAssertGreaterThan(layout.columns, 3, "landscape cannot afford four rows")
        XCTAssertLessThanOrEqual(layout.rows, 3)
    }

    func testRowsAreIndexedInReadingOrder() {
        let layout = TrioBoardLayout.fitting(12, in: CGSize(width: 400, height: 700))
        let rows = layout.rowsOfIndices(12)

        XCTAssertEqual(rows.flatMap { $0 }, Array(0..<12), "every card exactly once, in order")
        XCTAssertEqual(rows.count, layout.rows)
        XCTAssertTrue(rows.dropLast().allSatisfy { $0.count == layout.columns })
    }

    func testAnUnevenLastRowKeepsEveryCard() {
        let layout = TrioBoardLayout.fitting(14, in: CGSize(width: 400, height: 700))
        let rows = layout.rowsOfIndices(14)

        XCTAssertEqual(rows.flatMap { $0 }, Array(0..<14))
        XCTAssertLessThanOrEqual(rows.last?.count ?? 0, layout.columns)
    }

    func testNothingToShowIsNotADivideByZero() {
        let layout = TrioBoardLayout.fitting(0, in: CGSize(width: 400, height: 700))
        XCTAssertEqual(layout.cardWidth, 0)
        XCTAssertEqual(layout.rows, 0)
        XCTAssertEqual(layout.rowsOfIndices(0), [])
    }

    func testAZeroSizedContainerGivesZeroRatherThanNonsense() {
        let layout = TrioBoardLayout.fitting(12, in: .zero)
        XCTAssertEqual(layout.cardWidth, 0)
        XCTAssertEqual(layout.rowsOfIndices(12).flatMap { $0 }, Array(0..<12))
    }
}
