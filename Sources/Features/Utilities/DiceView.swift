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

    /// How a die is falling: when it was thrown, and the spin it was given.
    ///
    /// The face it will land on is already decided by the model, so the spin is
    /// a turn *down* to that resting orientation rather than a random tumble
    /// that happens to end somewhere.
    private struct Roll {
        let started: Date
        let duration: TimeInterval
        let resting: simd_quatf
        let axisA: SIMD3<Float>
        let axisB: SIMD3<Float>
        let turns: Double
        let tilt: Double
    }

    @State private var rolls: [UUID: Roll] = [:]
    @State private var rolling = false
    @State private var rollTask: Task<Void, Never>?

    /// Three across, so d4–d20 fits two rows even on a small phone.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

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
        .onDisappear {
            rollTask?.cancel()
            rollTask = nil
        }
    }

    private var subtitle: String {
        if model.isEmpty { return "Tap a die to roll it." }
        let count = model.dice.count
        return "\(count) \(count == 1 ? "die" : "dice") on the table"
    }

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
                .accessibilityLabel("Roll a d\(sides)")
                .accessibilityIdentifier("dice.add.\(sides)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - The table

    private var table: some View {
        // Only redrawn frame by frame while something is in the air: at rest the
        // dice are a still picture, and a timeline running for nothing is a
        // battery bug on a phone being passed round a table.
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !rolling)) { timeline in
            ScrollView {
                if model.isEmpty {
                    emptyTable
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ON THE TABLE")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .kerning(1.1)
                            .foregroundStyle(VibeTheme.tertiaryText)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(model.dice) { die in
                                dieTile(die, at: timeline.date)
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

    private func dieTile(_ die: Die, at now: Date) -> some View {
        let mesh = DiceMeshes.mesh(sides: die.sides)
        let resting = DiceRenderer.restingRotation(mesh: mesh, value: die.value, yaw: yaw(for: die))

        var rotation = resting
        var lift: Float = 0
        if let roll = rolls[die.id] {
            let progress = now.timeIntervalSince(roll.started) / roll.duration
            if progress < 1 {
                rotation = DiceRenderer.rollingRotation(rest: roll.resting,
                                                        progress: progress,
                                                        axisA: roll.axisA,
                                                        axisB: roll.axisB,
                                                        turns: roll.turns,
                                                        tilt: roll.tilt)
                lift = Float(sin(.pi * min(max(progress, 0), 1))) * 0.35
            }
        }

        return Canvas { context, size in
            DiceRenderer.draw(mesh: mesh,
                              value: die.value,
                              colour: VibeTheme.diceColour(sides: die.sides),
                              rotation: rotation,
                              lift: lift,
                              in: size,
                              into: &context)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(height: 116)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("d\(die.sides): \(die.value)")
        .accessibilityIdentifier("dice.die")
    }

    /// A stable twist for each die, so two d6s on the table are not twins.
    private func yaw(for die: Die) -> Double {
        let sum = die.id.uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Double(sum % 360) * .pi / 180
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
        model.add(sides: sides)
        // The new die is thrown in, so a tap reads as a roll rather than as a
        // tile appearing.
        if let die = model.dice.last {
            throwDice([die], duration: 0.55)
        }
    }

    private func rollAll() {
        guard !model.isEmpty else { return }
        let dice = model.dice
        model.rollAll()
        throwDice(dice, duration: 0.85)
    }

    private func clear() {
        rollTask?.cancel()
        rollTask = nil
        rolls = [:]
        rolling = false
        // No animation: dice drifting out of the way end up half over the empty
        // table, which reads as a glitch rather than a sweep.
        model.clear()
    }

    /// Throws the dice: each one gets a random spin that eases down onto the
    /// face the model has already chosen.
    ///
    /// The model stays the source of truth and keeps its rules testable; this is
    /// only what a roll *looks* like.
    private func throwDice(_ dice: [Die], duration: TimeInterval) {
        guard !dice.isEmpty else { return }

        let now = Date()
        var next = rolls
        for die in dice {
            let mesh = DiceMeshes.mesh(sides: die.sides)
            next[die.id] = Roll(started: now,
                                duration: duration,
                                resting: DiceRenderer.restingRotation(mesh: mesh,
                                                                     value: die.value,
                                                                     yaw: yaw(for: die)),
                                axisA: randomUnitVector(),
                                axisB: randomUnitVector(),
                                turns: Double.random(in: 1.4...2.6),
                                tilt: Double.random(in: 0.6...1.6))
        }
        rolls = next
        rolling = true

        rollTask?.cancel()
        rollTask = Task { @MainActor in
            // The timeline only needs to keep running while something is still
            // in the air; this brings it back to a still picture afterwards.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard !Task.isCancelled else { return }
                let time = Date()
                let live = rolls.filter { time.timeIntervalSince($0.value.started) < $0.value.duration }
                if live.count != rolls.count { rolls = live }
                if live.isEmpty {
                    rolling = false
                    return
                }
            }
        }
    }

    private func randomUnitVector() -> SIMD3<Float> {
        while true {
            let candidate = SIMD3<Float>(Float.random(in: -1...1),
                                         Float.random(in: -1...1),
                                         Float.random(in: -1...1))
            let length = simd_length(candidate)
            if length > 0.2 { return candidate / length }
        }
    }
}
