import SwiftUI

/// What the host chooses before a game: what kind of things get described.
///
/// Held in the room rather than on the phone, because it changes the deck — the
/// words are derived from the seed *and* the packs — so two people choosing
/// differently would be describing different things at each other.
///
/// How long a turn lasts is deliberately not here. It is a random 50–70 seconds,
/// and that is the point of it: a length the table agreed on is a length the
/// table counts down out loud.
struct VibeBlurtSettingsView: View {
    let packs: Set<BlurtPack>
    /// False for everybody but the host, and after the start for the host too.
    let isEditable: Bool
    let onChange: (Set<BlurtPack>) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    // Name and appearance first, then the room's own setting.
                    GameSettingsSections()
                    words
                }
                .padding(20)
            }
            .vibeCanvas()
            .navigationTitle("Game Settings")
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


    // MARK: - Words

    private var words: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("Words")

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
                    onChange(next)
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

}
