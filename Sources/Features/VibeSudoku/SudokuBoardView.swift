import SwiftUI

/// The 9x9 grid.
struct SudokuBoardView: View {
    let puzzle: SudokuPuzzle
    let values: [Int]
    let notes: [Set<Int>]
    let selectedCell: Int?
    let conflictingCells: Set<Int>
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { column in
                                cellView(index: row * 9 + column, size: cell)
                            }
                        }
                    }
                }

                gridLines(side: side, cell: cell)
                    .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VibeTheme.hairline, lineWidth: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sudoku grid")
        .accessibilityValue("\(filledCount) of 81 cells filled")
        .accessibilityIdentifier("sudoku.board")
    }

    private var filledCount: Int { values.filter { $0 != 0 }.count }

    /// The grid's own rules, drawn as lines rather than per-cell borders so the
    /// 3x3 boxes can be heavier without doubling up strokes.
    private func gridLines(side: CGFloat, cell: CGFloat) -> some View {
        ZStack {
            Path { path in
                for step in 1..<9 where step % 3 != 0 {
                    let offset = CGFloat(step) * cell
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset, y: side))
                    path.move(to: CGPoint(x: 0, y: offset))
                    path.addLine(to: CGPoint(x: side, y: offset))
                }
            }
            .stroke(VibeTheme.hairline.opacity(0.75), lineWidth: 1)

            Path { path in
                for step in stride(from: 0, through: 9, by: 3) {
                    let offset = CGFloat(step) * cell
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset, y: side))
                    path.move(to: CGPoint(x: 0, y: offset))
                    path.addLine(to: CGPoint(x: side, y: offset))
                }
            }
            .stroke(VibeTheme.hairline, lineWidth: 2)
        }
    }

    @ViewBuilder
    private func cellView(index: Int, size: CGFloat) -> some View {
        let value = values[index]
        let isGiven = puzzle.isGiven(index)
        let isSelected = selectedCell == index
        let isClashing = conflictingCells.contains(index)

        Button {
            onSelect(index)
        } label: {
            ZStack {
                Rectangle().fill(background(isSelected: isSelected,
                                            isClashing: isClashing,
                                            value: value))

                if value != 0 {
                    Text("\(value)")
                        .font(.system(size: size * 0.56,
                                      weight: isGiven ? .bold : .semibold,
                                      design: .rounded))
                        .foregroundStyle(isClashing
                                         ? VibeTheme.sudokuClash
                                         : (isGiven ? VibeTheme.primaryText : VibeTheme.sudokuEntry))
                } else if !notes[index].isEmpty {
                    noteGrid(notes[index], size: size)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(index: index, value: value, isGiven: isGiven))
        .accessibilityIdentifier("sudoku.cell.\(index)")
    }

    private func background(isSelected: Bool, isClashing: Bool, value: Int) -> Color {
        if isSelected { return VibeTheme.sudokuSelection.opacity(0.45) }
        if isClashing { return VibeTheme.sudokuClash.opacity(0.22) }
        // Gently echo the selected digit, which makes scanning much easier.
        if let selected = selectedCell, value != 0, values[selected] == value {
            return VibeTheme.sudokuSelection.opacity(0.18)
        }
        return VibeTheme.tileIdle
    }

    /// The marks in a cell: up to four numbers, two by two.
    ///
    /// It used to be a 3x3 grid with each digit in its own fixed square, which
    /// made every digit the same size as the smallest possible one. With four
    /// marks at most, four bigger numbers in reading order are easier to read at
    /// a glance — and a glance is all a note gets.
    private func noteGrid(_ marks: Set<Int>, size: CGFloat) -> some View {
        let shown = marks.sorted().prefix(VibeSudokuModel.maximumNotes).map(String.init)

        return VStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { column in
                        let position = row * 2 + column
                        Text(position < shown.count ? shown[position] : " ")
                            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                            .foregroundStyle(VibeTheme.tertiaryText)
                            .frame(width: size / 2, height: size / 2)
                    }
                }
            }
        }
    }

    private func accessibilityLabel(index: Int, value: Int, isGiven: Bool) -> String {
        let position = "row \(SudokuSolver.row(of: index) + 1), column \(SudokuSolver.column(of: index) + 1)"
        let selection = (selectedCell == index) ? ", selected" : ""

        if value == 0 {
            let state = notes[index].isEmpty
                ? "empty"
                : "notes \(notes[index].sorted().map(String.init).joined(separator: " "))"
            return "\(position), \(state)\(selection)"
        }
        return "\(position), \(value)\(isGiven ? ", given" : "")\(selection)"
    }
}
