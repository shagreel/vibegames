import SwiftUI

/// Sheet for the one thing Number Vibe lets you choose.
///
/// The choice lived on the keypad for a day, which was the wrong place for a
/// setting: it sat next to the keys you are using while solving and changed
/// shape under your thumb as it was tapped. Every other game puts its settings
/// behind the same button, so this one does too, and the keypad goes back to the
/// three things a player actually touches — notes, erase and the digits.
struct VibeSudokuSettingsView: View {
    @ObservedObject var model: VibeSudokuModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    notesSection
                    explanation
                }
                .padding(20)
            }
            .vibeCanvas()
            .navigationTitle("Game Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("sudokuSettings.done")
                }
            }
            .toolbarBackground(VibeTheme.canvasTop, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Notes per square")

            VStack(spacing: 0) {
                ForEach(Array(VibeSudokuModel.noteLimits.enumerated()), id: \.element) { index, limit in
                    if index > 0 {
                        Divider().overlay(VibeTheme.hairline)
                    }
                    noteRow(limit)
                }
            }
            .background(card)
        }
    }

    private var explanation: some View {
        Text("""
            A square can hold nine candidates, and four of them make a hard puzzle \
            harder. Nine are every candidate, each in its own little box, the way \
            pencil marks are read on paper — but nine marks in a phone-sized square \
            are hard to read, and an unreadable note is worse than no note at all. \
            Whichever you pick is kept for next time.
            """)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(VibeTheme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Building blocks

    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(VibeTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VibeTheme.hairline, lineWidth: 1)
            }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .black, design: .rounded))
            .kerning(1.6)
            .foregroundStyle(VibeTheme.tertiaryText)
    }

    private func noteRow(_ limit: Int) -> some View {
        let isOn = model.noteLimit == limit
        let side = limit == 9 ? 3 : 2

        return Button {
            withAnimation(.snappy) { model.setNoteLimit(limit) }
        } label: {
            HStack(spacing: 14) {
                // The sample marks, drawn the way the square will draw them, so
                // the choice is read rather than imagined.
                sampleGrid(side: side)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(limit) notes")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(VibeTheme.primaryText)
                    Text(limit == 4
                         ? "Bigger, two by two"
                         : "Every candidate, three by three")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.tertiaryText)
                }

                Spacer(minLength: 8)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(isOn ? VibeTheme.go : VibeTheme.tertiaryText.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier("sudokuSettings.notes.\(limit)")
    }

    private func sampleGrid(side: Int) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<side, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<side, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(VibeTheme.calm.opacity(0.55))
                            .frame(width: side == 3 ? 5 : 8,
                                   height: side == 3 ? 5 : 8)
                            .opacity(row * side + column < 4 ? 1 : 0.3)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
