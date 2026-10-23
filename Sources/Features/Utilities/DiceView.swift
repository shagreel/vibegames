import SwiftUI
import simd

/// The dice bag, on screen.
///
/// One bag for the table: tap a die to add it and roll it, "Roll" again for the
/// dice that are there, "Clear" to sweep the table. Nothing is remembered
/// between visits — the table is a moment, not a scoreboard.
struct DiceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = DiceModel()

    /// The table itself: a physics simulation that the dice are thrown onto.
    @StateObject private var diceTable = DiceTable()

    /// Shaking the phone rolls the dice, the same as the button. Held in `@State`
    /// so the body being rebuilt does not start a second sensor.
    @State private var shake = ShakeMonitor()

    @State private var showingSettings = false

    /// Three across, so d4–d20 fits two rows even on a small phone.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            GameHeaderBar(title: "DICE",
                          subtitle: subtitle,
                          backIdentifier: "dice.back",
                          backLabel: "Back to utilities",
                          onBack: { dismiss() }) {
                SupportButton()
                GameSettingsButton(prefix: "dice") { showingSettings = true }
            }

            picker

            table

            results

            controls
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .onAppear {
            Haptics.shared.prepare()
            shake.start { rollAll() }
            // The physics is what decides a number, so the model is told what
            // each die landed on rather than the other way round.
            diceTable.onSettled = { id, value in model.record(value, for: id) }
        }
        .sheet(isPresented: $showingSettings) {
            DiceSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear {
            diceTable.onSettled = nil
            shake.stop()
        }
    }

    private var subtitle: String {
        if model.isEmpty { return "Tap a die to roll it." }
        let count = model.dice.count
        if isFull { return "\(count) dice — the table is full" }
        return "\(count) \(count == 1 ? "die" : "dice") on the table"
    }

    private var isFull: Bool { model.dice.count >= DiceModel.maximum }

    // MARK: - The bag

    private var picker: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(DiceModel.sidesOptions, id: \.self) { sides in
                Button {
                    add(sides: sides)
                } label: {
                    ZStack {
                        DieBody(sides: sides, depth: 5, cornerRadius: 7)

                        Text("d\(sides)")
                            .font(.system(size: sides >= 10 ? 18 : 21,
                                          weight: .black,
                                          design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    }
                    // A square, so a face keeps its proportions: a square that
                    // is 110 wide and 78 tall is not a face of anything.
                    .aspectRatio(1, contentMode: .fit)
                    .frame(height: 90)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(isFull)
                .opacity(isFull ? 0.4 : 1)
                .accessibilityLabel("Roll a d\(sides)")
                .accessibilityIdentifier("dice.add.\(sides)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - The table

    private var table: some View {
        ZStack {
            if model.isEmpty {
                emptyTable
            } else {
                DiceTableView(table: diceTable)
                    .accessibilityIdentifier("dice.tableView")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - The results

    /// What each die came up, under the table.
    ///
    /// A number appears here only once the die has actually stopped: a die that
    /// lands on another and rolls off it would otherwise be read while it was
    /// still on its way down.
    private var results: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                ForEach(groupedResults, id: \.sides) { column in
                    VStack(spacing: 6) {
                        Text("d\(column.sides)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .kerning(0.5)
                            .foregroundStyle(VibeTheme.secondaryText)

                        // Five to a column, then the next column of the same
                        // kind: twenty dice in one column would be taller than the
                        // screen.
                        ForEach(Array(column.chunks.enumerated()), id: \.offset) { _, chunk in
                            VStack(spacing: 4) {
                                ForEach(chunk) { die in
                                    resultPill(die)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                // At least the width of the screen, so a few columns spread out
                // across it instead of huddling on the left; more than fits
                // scrolls, column by column.
                .frame(minWidth: geo.size.width, alignment: .leading)
            }
        }
        .frame(height: resultsHeight)
        .opacity(model.isEmpty ? 0 : 1)
        .accessibilityIdentifier("dice.results")
    }

    /// As tall as the fullest column needs, so the table gives up no more room
    /// than the numbers take.
    private var resultsHeight: CGFloat {
        let rows = groupedResults.map { min($0.dice.count, ResultColumn.rows) }.max() ?? 0
        return CGFloat(rows) * 28 + 26
    }

    /// The dice grouped by kind, smallest first.
    ///
    /// A column per kind, so two d4s are stacked in the first column and the d12s
    /// follow — reading down a column is how a table of results is read, and it
    /// keeps the same die in the same place as more are thrown.
    private struct ResultColumn: Identifiable {
        let sides: Int
        let dice: [Die]
        /// At most this many, so a column cannot run off the bottom of its space.
        static let rows = 5

        var chunks: [[Die]] {
            stride(from: 0, to: dice.count, by: Self.rows).map { start in
                Array(dice[start..<min(start + Self.rows, dice.count)])
            }
        }
        var id: Int { sides }
    }

    private var groupedResults: [ResultColumn] {
        let grouped = Dictionary(grouping: model.dice, by: \.sides)
        return grouped.keys.sorted().map { ResultColumn(sides: $0, dice: grouped[$0] ?? []) }
    }

    private func resultPill(_ die: Die) -> some View {
        let stopped = diceTable.settled.contains(die.id)
        let colour = VibeTheme.diceColour(sides: die.sides)

        return Text(stopped ? "\(die.value)" : "–")
            .font(.system(size: 15, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(VibeTheme.primaryText)
            .frame(width: 34, height: 24)
            .contentTransition(.numericText())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colour.opacity(0.18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(colour.opacity(0.55), lineWidth: 1)
                    }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stopped ? "d\(die.sides): \(die.value)" : "d\(die.sides): rolling")
            .accessibilityIdentifier("dice.result")
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
                rollAll()
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
                clear()
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

    // MARK: - Rolling

    private func add(sides: Int) {
        guard let die = model.add(sides: sides) else { return }
        diceTable.addDie(id: die.id, sides: die.sides, value: die.value)
    }

    private func rollAll() {
        guard !model.isEmpty else { return }
        // The model moves its own numbers at once so the table is never showing a
        // result from the last throw; the physics replaces them as each die lands.
        model.rollAll()
        diceTable.tossAll()
    }

    private func clear() {
        diceTable.removeAll()
        model.clear()
    }
}

/// The settings sheet for the dice table: the shared ones, which are the player's
/// name and the appearance, because a table of dice has nothing else to choose.
private struct DiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    GameSettingsSections()
                }
                .padding(20)
            }
            .vibeCanvas()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("diceSettings.done")
                }
            }
            .toolbarBackground(VibeTheme.canvasTop, for: .navigationBar)
        }
        .followingAppearance()
    }
}
