import SwiftUI

/// The dice bag, on screen.
///
/// One bag for the table: tap a die to add it and roll it, "Roll" again for the
/// dice that are there, "Clear" to sweep the table. Nothing is remembered
/// between visits — the table is a moment, not a scoreboard.
struct DiceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = DiceModel()

    /// A die's pose while it is tumbling: two rotations in degrees, a roll
    /// around the face, and how far off the table it has been thrown.
    private struct Pose: Equatable {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        var lift: Double = 0
    }

    /// What a die shows while it is rolling — random faces settling onto the
    /// model's answer — and the lean it is drawn at while it does.
    @State private var tumbling: [UUID: Int] = [:]
    @State private var poses: [UUID: Pose] = [:]
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
        let pose = poses[die.id] ?? Pose()
        let value = tumbling[die.id] ?? die.value

        return ZStack {
            DieBody(sides: die.sides, depth: 9, cornerRadius: 11)

            VStack(spacing: 0) {
                DieValue(text: "\(value)", size: die.sides >= 10 ? 32 : 38)
                Text("d\(die.sides)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(height: 108)
        .frame(maxWidth: .infinity)
        .rotation3DEffect(.degrees(pose.x), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        .rotation3DEffect(.degrees(pose.y), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .rotationEffect(.degrees(pose.z))
        .offset(y: -pose.lift)
        .scaleEffect(rolling ? 1.06 : 1)
        .animation(.linear(duration: 0.08), value: pose)
        .animation(.spring(response: 0.32, dampingFraction: 0.62), value: rolling)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("d\(die.sides): \(value)")
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
        withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
            model.add(sides: sides)
        }
        // The new die tumbles into place, so a tap reads as a roll rather than
        // as a tile appearing.
        if let die = model.dice.last {
            tumble([die], duration: 0.34)
        }
    }

    private func rollAll() {
        guard !model.isEmpty else { return }
        let dice = model.dice
        model.rollAll()
        tumble(dice, duration: 0.7)
    }

    private func clear() {
        rollTask?.cancel()
        rollTask = nil
        tumbling = [:]
        poses = [:]
        rolling = false
        // No animation: dice drifting out of the way end up half over the empty
        // table, which reads as a glitch rather than a sweep.
        model.clear()
    }

    /// Shows random faces and random leans for a moment, then settles onto the
    /// values the model already decided.
    ///
    /// The model stays the source of truth and keeps its rules testable; this is
    /// only what a roll *looks* like. In the air it can show anything; where it
    /// comes to rest is the model's answer.
    private func tumble(_ dice: [Die], duration: TimeInterval) {
        guard !dice.isEmpty else { return }
        rollTask?.cancel()

        let frame = 0.06
        let frames = max(1, Int(duration / frame))
        let sides = Dictionary(uniqueKeysWithValues: dice.map { ($0.id, $0.sides) })
        let ids = dice.map(\.id)

        rolling = true
        rollTask = Task { @MainActor in
            for _ in 0..<frames {
                guard !Task.isCancelled else { return }
                for id in ids {
                    guard let sideCount = sides[id] else { continue }
                    tumbling[id] = Int.random(in: 1...sideCount)
                    poses[id] = Pose(x: Double.random(in: -60...60),
                                     y: Double.random(in: -75...75),
                                     z: Double.random(in: -25...25),
                                     lift: Double.random(in: 0...10))
                }
                try? await Task.sleep(nanoseconds: UInt64(frame * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }
            tumbling = [:]
            withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) {
                poses = [:]
            }
            rolling = false
        }
    }
}
