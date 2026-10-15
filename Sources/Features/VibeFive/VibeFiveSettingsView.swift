import SwiftUI

/// Sheet for choosing which category packs are in play plus sound/haptics.
struct VibeFiveSettingsView: View {
    @ObservedObject var model: VibeFiveModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    feedbackSection
                    packsSection
                    summary
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
                }
            }
            .toolbarBackground(VibeTheme.canvasTop, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Feedback")

            VStack(spacing: 0) {
                settingRow(
                    symbol: "speaker.wave.2.fill",
                    title: "Buzzer & ticks",
                    subtitle: "Plays even in silent mode"
                ) {
                    Toggle("", isOn: Binding(
                        get: { model.soundEnabled },
                        set: { model.setSound($0) }
                    ))
                    .labelsHidden()
                    .tint(VibeTheme.go)
                }

                Divider().overlay(VibeTheme.hairline)

                settingRow(
                    symbol: "iphone.radiowaves.left.and.right",
                    title: "Haptics",
                    subtitle: "Ticks and a jolt when time runs out"
                ) {
                    Toggle("", isOn: Binding(
                        get: { model.hapticsEnabled },
                        set: { model.setHaptics($0) }
                    ))
                    .labelsHidden()
                    .tint(VibeTheme.go)
                }
            }
            .background(card)
        }
    }

    private var packsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Category packs")
                Spacer()
                Button(model.allPacksEnabled ? "Clear" : "All") {
                    withAnimation(.snappy) { model.toggleAllPacks() }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.calm)
            }

            VStack(spacing: 0) {
                ForEach(Array(CategoryPack.allCases.enumerated()), id: \.element.id) { index, pack in
                    if index > 0 {
                        Divider().overlay(VibeTheme.hairline)
                    }
                    packRow(pack)
                }
            }
            .background(card)

            Text("At least one pack always stays on.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .padding(.top, 2)
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.stack.fill")
                .foregroundStyle(VibeTheme.vibeFive)
            Text("\(model.activePromptCount) categories · \(model.enabledPacks.count) of \(CategoryPack.allCases.count) packs")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 14)
        .background(card)
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

    private func settingRow<Trailing: View>(symbol: String,
                                            title: String,
                                            subtitle: String,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VibeTheme.calm)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
            }

            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func packRow(_ pack: CategoryPack) -> some View {
        let isOn = model.enabledPacks.contains(pack)

        return Button {
            withAnimation(.snappy) { model.togglePack(pack) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: pack.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isOn ? VibeTheme.primaryText : VibeTheme.tertiaryText)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isOn ? VibeTheme.primaryText : VibeTheme.secondaryText)
                    Text(pack.blurb)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                // Trailing count keeps every row the same height regardless of
                // how long the blurb is.
                Text("\(pack.promptCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isOn
                                     ? VibeTheme.secondaryText
                                     : VibeTheme.tertiaryText.opacity(0.7))

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
    }
}
