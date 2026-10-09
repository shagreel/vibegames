import SwiftUI

/// Digits plus erase, and a notes toggle.
///
/// Sits directly under the grid within thumb reach, and — like the Vibe Words
/// keyboard — each key's *touch* area is the whole cell with the cap drawn
/// inset, so a slightly-off tap still lands.
struct SudokuKeypadView: View {
    let isNoteMode: Bool
    let onDigit: (Int) -> Void
    let onErase: () -> Void
    let onToggleNotes: () -> Void

    @State private var pressCount = 0

    private let keyHeight: CGFloat = 56

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(1...9, id: \.self) { digit in
                    key(identifier: "sudoku.digit.\(digit)",
                        accessibility: "\(digit)") {
                        Text("\(digit)")
                    } action: {
                        onDigit(digit)
                    }
                }
            }

            HStack(spacing: 8) {
                wideKey(identifier: "sudoku.notes",
                        title: isNoteMode ? "NOTES ON" : "NOTES",
                        symbol: "pencil",
                        tint: isNoteMode ? VibeTheme.sudokuSelection : VibeTheme.surfaceStrong,
                        labelColor: isNoteMode ? .white : VibeTheme.primaryText) {
                    onToggleNotes()
                }

                wideKey(identifier: "sudoku.erase",
                        title: "ERASE",
                        symbol: "delete.left.fill",
                        tint: VibeTheme.surfaceStrong, labelColor: VibeTheme.primaryText) {
                    onErase()
                }
            }
        }
        .frame(maxWidth: 520)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pressCount)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sudoku.keypad")
    }

    private func key<Content: View>(identifier: String,
                                    accessibility: String,
                                    @ViewBuilder content: () -> Content,
                                    action: @escaping () -> Void) -> some View {
        Button {
            pressCount += 1
            action()
        } label: {
            content()
        }
        .buttonStyle(SudokuKeyStyle(fill: VibeTheme.keyUntried,
                                     height: keyHeight,
                                     labelColor: VibeTheme.primaryText))
        .accessibilityLabel(accessibility)
        .accessibilityIdentifier(identifier)
    }

    private func wideKey(identifier: String,
                         title: String,
                         symbol: String,
                         tint: Color,
                         labelColor: Color,
                         action: @escaping () -> Void) -> some View {
        Button {
            pressCount += 1
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 15, weight: .bold))
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded))
            }
        }
        .buttonStyle(SudokuKeyStyle(fill: tint, height: 46, labelColor: labelColor))
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

private struct SudokuKeyStyle: ButtonStyle {
    let fill: Color
    let height: CGFloat
    let labelColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 23, weight: .semibold, design: .rounded))
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 3)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}
