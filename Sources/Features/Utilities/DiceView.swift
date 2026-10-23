import SwiftUI

/// The dice bag, on screen.
///
/// One bag for the table: tap a die to add it and roll it, "Roll" again for the
/// dice that are there, "Clear" to sweep the table. Nothing is remembered
/// between visits — the table is a moment, not a scoreboard.
struct DiceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = DiceModel()

    /// Three across, so d4–d20 fits two rows even on a small phone.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            GameHeaderBar(title: "DICE",
                          subtitle: subtitle,
                          backIdentifier: "dice.back",
                          backLabel: "Back to utilities",
                          onBack: { dismiss() }) {
                EmptyView()
            }

            picker

            table

            controls
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .onAppear { Haptics.shared.prepare() }
    }

    private var subtitle: String {
        if model.isEmpty { return "Tap a die to roll it." }
        let count = model.dice.count
        return "\(count) \(count == 1 ? "die" : "dice") on the table"
    }

    // MARK: - The bag

    private var picker: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(DiceModel.sidesOptions, id: \.self) { sides in
                Button {
                    Haptics.shared.tap()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        model.add(sides: sides)
                    }
                } label: {
                    VStack(spacing: 1) {
                        Text("d\(sides)")
                            .font(.system(size: 21, weight: .black, design: .rounded))
                        Text("roll")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .opacity(0.75)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VibeTheme.diceColour(sides: sides))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Roll a d\(sides)")
                .accessibilityIdentifier("dice.add.\(sides)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: - The table

    private var table: some View {
        ScrollView {
            if model.isEmpty {
                emptyTable
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ON THE TABLE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .kerning(1.1)
                        .foregroundStyle(VibeTheme.tertiaryText)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(model.dice) { die in
                            dieTile(die)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
        .frame(maxHeight: .infinity)
        .accessibilityIdentifier("dice.tableView")
        .accessibilityValue(model.isEmpty ? "No dice" : "\(model.dice.count) dice")
    }

    private var emptyTable: some View {
        VStack(spacing: 8) {
            Image(systemName: "dice")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(VibeTheme.tertiaryText)

            Text("No dice yet")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)

            Text("Tap one above to roll it.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .accessibilityIdentifier("dice.empty")
    }

    private func dieTile(_ die: Die) -> some View {
        VStack(spacing: 2) {
            Text("\(die.value)")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("d\(die.sides)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VibeTheme.diceColour(sides: die.sides))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
        .animation(.snappy, value: die.value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("d\(die.sides): \(die.value)")
        .accessibilityIdentifier("dice.die")
    }

    // MARK: - The two buttons

    private var controls: some View {
        // Disabled controls are drawn as furniture rather than as dimmed
        // buttons: a faded "Roll" is still the loudest thing on an empty table,
        // and in light mode it is also the least readable.
        let empty = model.isEmpty

        return HStack(spacing: 10) {
            Button {
                Haptics.shared.tap()
                withAnimation(.snappy) { model.rollAll() }
            } label: {
                Text("Roll")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(empty ? VibeTheme.tertiaryText : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(empty ? AnyShapeStyle(VibeTheme.surfaceStrong)
                                        : AnyShapeStyle(VibeTheme.vibeUtility))
                    }
            }
            .buttonStyle(.plain)
            .disabled(empty)
            .accessibilityIdentifier("dice.roll")

            Button {
                Haptics.shared.tap()
                // No animation: dice drifting out of the way end up half over the
                // empty table, which reads as a glitch rather than a sweep.
                model.clear()
            } label: {
                Text("Clear")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(empty ? VibeTheme.tertiaryText : VibeTheme.primaryText)
                    .frame(width: 110)
                    .frame(height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(VibeTheme.surfaceStrong)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(VibeTheme.hairline, lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
            .disabled(empty)
            .accessibilityIdentifier("dice.clear")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}
