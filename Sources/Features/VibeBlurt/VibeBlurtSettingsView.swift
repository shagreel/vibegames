import SwiftUI

/// What the host chooses before a game: how long a turn lasts, and what kind of
/// things get described.
///
/// Both live in the room rather than on the phone, because both change the deck
/// — the words are derived from the seed *and* the packs — so two people
/// choosing differently would be describing different things at each other.
struct VibeBlurtSettingsView: View {
    let packs: Set<BlurtPack>
    let seconds: Int
    /// False for everybody but the host, and after the start for the host too.
    let isEditable: Bool
    let onChange: (Set<BlurtPack>, Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    turnLength
                    words
                    footnote
                }
                .padding(20)
            }
            .vibeCanvas()
            .navigationTitle("Game settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("blurt.settings.done")
                }
            }
        }
    }

    // MARK: - Turn length

    private var turnLength: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TURN LENGTH")

            ForEach(BlurtDuration.allCases) { option in
                Button {
                    guard isEditable else { return }
                    onChange(packs, option.rawValue)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: seconds == option.rawValue
                              ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(VibeTheme.blurtTeam(.one))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(VibeTheme.primaryText)
                            Text(option.blurb)
                                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                .foregroundStyle(VibeTheme.secondaryText)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(VibeTheme.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(seconds == option.rawValue
                                            ? VibeTheme.blurtTeam(.one)
                                            : VibeTheme.hairline,
                                            lineWidth: seconds == option.rawValue ? 2 : 1)
                            }
                    }
                    .opacity(isEditable ? 1 : 0.6)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
                .accessibilityIdentifier("blurt.duration.\(option.rawValue)")
            }
        }
    }

    // MARK: - Words

    private var words: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("WORDS")

            ForEach(BlurtPack.allCases) { pack in
                Button {
                    guard isEditable else { return }
                    var next = packs
                    if next.contains(pack) {
                        // Leaving nothing ticked would deal an empty deck, so the
                        // last one cannot be turned off.
                        guard next.count > 1 else { return }
                        next.remove(pack)
                    } else {
                        next.insert(pack)
                    }
                    onChange(next, seconds)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: pack.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(VibeTheme.vibeBlurt)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(VibeTheme.primaryText)
                            Text(pack.blurb)
                                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                .foregroundStyle(VibeTheme.secondaryText)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: packs.contains(pack) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(packs.contains(pack)
                                             ? VibeTheme.blurtTeam(.one)
                                             : VibeTheme.tertiaryText)
                    }
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(VibeTheme.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(VibeTheme.hairline, lineWidth: 1)
                            }
                    }
                    .opacity(isEditable ? 1 : 0.6)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
                .accessibilityIdentifier("blurt.pack.\(pack.rawValue)")
            }

            Text("\(BlurtDeck.words(in: packs).count) words in the deck")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .accessibilityIdentifier("blurt.packCount")
        }
    }

    private var footnote: some View {
        Text(isEditable
             ? "Everyone in the room gets these, so you will all be describing the same things."
             : "Only the host can change these, and only before the game starts.")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(VibeTheme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .kerning(1.5)
            .foregroundStyle(VibeTheme.tertiaryText)
    }
}
