import SwiftUI

/// The on-screen QWERTY keyboard, tinted by what has been learned so far.
///
/// This is deliberately *not* the system keyboard: it has to tint each key
/// green/amber/grey to show which letters are known, which `UIKeyboard` cannot
/// do. The trade is that a custom keyboard has to earn back the forgiveness the
/// system one gives you for free, so:
///
///   * keys are taller than the system keyboard's ~42pt;
///   * each key's *touch* area is the whole cell, with the visible cap drawn
///     inset — so the gaps between caps are still tappable, instead of being
///     dead space that swallows a slightly-off tap.
struct VibeWordsKeyboardView: View {
    let feedbackFor: (Character) -> FeedbackLookup
    let onKey: (VibeWordsModel.Key) -> Void

    /// How a key should be drawn. `nil` means "not guessed yet".
    typealias FeedbackLookup = LetterFeedback?

    /// Fires once per key press, purely to drive haptics.
    @State private var pressCount = 0

    private let rows: [[Key]] = [
        "QWERTYUIOP".map { Key.letter($0) },
        "ASDFGHJKL".map { Key.letter($0) },
        [.enter] + "ZXCVBNM".map { Key.letter($0) } + [.delete]
    ]

    enum Key: Hashable {
        case letter(Character)
        case enter
        case delete
    }

    /// What the return key is drawn with.
    ///
    /// The `\u{FE0E}` is not decoration. The up arrow is an emoji, and without
    /// the variation selector iOS draws it as a small blue rounded square — the
    /// only colour on a keyboard that is otherwise monochrome and tinted. The
    /// text glyph comes from a fallback font drawn small for its point size, so
    /// it is set well above the letters either side of it.
    static let returnGlyph = "\u{2B06}\u{FE0E}"

    /// How far to lift the return glyph so it sits on the same line as the
    /// letters.
    ///
    /// The fallback font that supplies the text glyph draws it low in its box,
    /// so the arrow's bottom edge landed below every letter beside it — measured
    /// against a screenshot at 14px, or 4.7pt at 3x, under the baseline of
    /// Z X C V B N M. Guessed values here look *almost* right, which is worse
    /// than obviously wrong.
    static let returnGlyphRise: CGFloat = 4.7

    // MARK: Metrics

    private let keyHeight: CGFloat = 58
    /// Gap between visible caps. The touch area ignores it.
    private let capInset: CGFloat = 3
    private let rowSpacing: CGFloat = 2

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                // Zero spacing: neighbouring cells touch, so there is no dead
                // strip between keys to miss.
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { key in
                        button(for: key)
                    }
                }
            }
        }
        // Keeps keys from becoming absurdly wide on an iPad.
        .frame(maxWidth: 520)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pressCount)
        // Scoped as a container: without this the identifier propagates down
        // and overwrites every key's own identifier.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("words.keyboard")
    }

    private func button(for key: Key) -> some View {
        Button {
            pressCount += 1
            onKey(translate(key))
        } label: {
            label(for: key)
                // An untried key is pale in light mode, so its label has to
                // flip; scored keys keep white on their saturated fill.
                .foregroundStyle(feedbackFor(letterOf(key)) == nil
                                 ? VibeTheme.primaryText
                                 : Color.white)
        }
        .buttonStyle(KeyStyle(fill: fill(for: key),
                              height: keyHeight,
                              capInset: capInset))
        .accessibilityLabel(accessibilityLabel(for: key))
        .accessibilityValue(accessibilityValue(for: key))
        .accessibilityIdentifier(identifier(for: key))
    }

    private func letterOf(_ key: Key) -> Character {
        if case .letter(let character) = key { return character }
        return " "
    }

    @ViewBuilder
    private func label(for key: Key) -> some View {
        switch key {
        case .letter(let character):
            Text(String(character))
        case .enter:
            // The up arrow, rather than the word: "ENTER" was too wide for one
            // key and had to be shrunk until it looked like a mistake. See
            // `returnGlyph` for the variation selector, and `returnGlyphRise`
            // for why it is nudged up.
            Text(Self.returnGlyph)
                .font(.system(size: 30, weight: .bold))
                .offset(y: -Self.returnGlyphRise)
        case .delete:
            Image(systemName: "delete.left.fill").font(.system(size: 18, weight: .bold))
        }
    }

    /// Four clearly separated steps on the dark canvas. An untried key has to
    /// be visibly *lighter* than a ruled-out one, otherwise "not in the word"
    /// reads as "nothing happened" and the keyboard looks broken.
    private func fill(for key: Key) -> Color {
        switch key {
        case .letter(let character):
            switch feedbackFor(character) {
            case .correct: return VibeTheme.tileCorrect
            case .present: return VibeTheme.tilePresent
            case .absent: return VibeTheme.tileAbsent
            case nil: return VibeTheme.keyUntried
            }
        case .enter, .delete:
            return VibeTheme.surfaceStrong
        }
    }

    private func translate(_ key: Key) -> VibeWordsModel.Key {
        switch key {
        case .letter(let character): return .letter(character)
        case .enter: return .enter
        case .delete: return .delete
        }
    }

    private func identifier(for key: Key) -> String {
        switch key {
        case .letter(let character): return "words.key.\(character)"
        case .enter: return "words.key.enter"
        case .delete: return "words.key.delete"
        }
    }

    private func accessibilityLabel(for key: Key) -> String {
        switch key {
        case .letter(let character): return String(character)
        case .enter: return "Submit guess"
        case .delete: return "Delete letter"
        }
    }

    /// Spoken alongside the letter, so VoiceOver conveys the same hint the
    /// colour does.
    private func accessibilityValue(for key: Key) -> String {
        guard case .letter(let character) = key else { return "" }
        switch feedbackFor(character) {
        case .correct: return "correct"
        case .present: return "in the word"
        case .absent: return "not in the word"
        case nil: return "not tried"
        }
    }
}

private struct KeyStyle: ButtonStyle {
    let fill: Color
    let height: CGFloat
    let capInset: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 21, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            // The whole cell responds, not just the drawn cap.
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
                    .padding(.horizontal, capInset)
                    .padding(.vertical, capInset)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}
