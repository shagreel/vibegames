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
            // Apple's own return glyph rather than the word: "ENTER" was too
            // wide for one key and had to be shrunk until it looked like a
            // mistake. The arrow says the same thing at any width.
            Image(systemName: "return").font(.system(size: 18, weight: .bold))
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
