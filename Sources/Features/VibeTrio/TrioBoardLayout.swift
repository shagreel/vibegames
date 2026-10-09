import CoreGraphics

/// How the cards are arranged so that every one of them is on screen at once.
///
/// The board used to be three across inside a scroll view, which meant the table
/// ran off the bottom of an iPad: on the biggest screen, with the most room, you
/// could see the fewest cards. A trio is a puzzle about the whole table at once —
/// scrolling to see the rest of it is a different, worse game — so the table is
/// fitted to the room it has instead. Every arrangement from one column to one
/// per card is measured, and the one leaving the cards biggest wins.
struct TrioBoardLayout: Equatable {

    let columns: Int
    let rows: Int
    let cardWidth: CGFloat

    static let spacing: CGFloat = 8

    /// Arrangements within this much of each other are a tie, and the one with
    /// fewer columns takes it. Three across is the shape the game was designed
    /// around; there is no sense giving it up for a fifth of a point.
    private static let tie: CGFloat = 1

    static func fitting(_ count: Int,
                        in size: CGSize,
                        spacing: CGFloat = TrioBoardLayout.spacing) -> TrioBoardLayout {
        guard count > 0 else {
            return TrioBoardLayout(columns: 1, rows: 0, cardWidth: 0)
        }
        guard size.width > 0, size.height > 0 else {
            return TrioBoardLayout(columns: count, rows: 1, cardWidth: 0)
        }

        var best: TrioBoardLayout?
        for columns in 1...count {
            let rows = (count + columns - 1) / columns
            let cellWidth = (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            guard cellWidth > 0, cellHeight > 0 else { continue }

            // Cards are taller than they are wide, so the row height is usually
            // what limits them — but a short, wide window flips that round.
            let width = min(cellWidth, cellHeight * TrioCardView.aspectRatio)
            if let current = best, width <= current.cardWidth + tie { continue }
            best = TrioBoardLayout(columns: columns, rows: rows, cardWidth: width)
        }

        return best ?? TrioBoardLayout(columns: count, rows: 1, cardWidth: 0)
    }

    /// Card indices by row, so a last row that does not fill can be centred
    /// rather than left hanging under the others.
    func rowsOfIndices(_ count: Int) -> [[Int]] {
        stride(from: 0, to: count, by: columns).map { start in
            Array(start..<min(start + columns, count))
        }
    }
}
