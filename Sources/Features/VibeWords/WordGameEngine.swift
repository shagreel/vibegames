import Foundation

/// How a single letter of a guess relates to the answer.
enum LetterFeedback: Equatable, Hashable {
    /// Right letter, right place.
    case correct
    /// Letter is in the word, but not here.
    case present
    /// Letter is not in the word (or has already been accounted for).
    case absent
}

/// The rules of the word game, with no UI or networking attached.
enum WordGameEngine {

    static let wordSize = 5
    static let maxGuesses = 6

    /// Scores a guess against an answer.
    ///
    /// Uses the standard two-pass approach so repeated letters behave: exact
    /// matches are claimed first, then remaining letters are matched against
    /// what is left of the answer. Guessing `SPEED` against `ABIDE` marks only
    /// one `E` as present, not both.
    static func score(guess: String, answer: String) -> [LetterFeedback] {
        let guessed = Array(guess.uppercased())
        let solution = Array(answer.uppercased())

        guard guessed.count == solution.count, !solution.isEmpty else { return [] }

        var result = Array(repeating: LetterFeedback.absent, count: guessed.count)
        var unclaimed: [Character: Int] = [:]

        // Pass one: exact positions.
        for index in guessed.indices where guessed[index] == solution[index] {
            result[index] = .correct
        }

        // Everything in the answer that was not an exact match is up for grabs.
        for index in solution.indices where guessed[index] != solution[index] {
            unclaimed[solution[index], default: 0] += 1
        }

        // Pass two: present letters, each consuming one unclaimed occurrence.
        for index in guessed.indices where result[index] != .correct {
            let letter = guessed[index]
            if let count = unclaimed[letter], count > 0 {
                result[index] = .present
                unclaimed[letter] = count - 1
            }
        }

        return result
    }

    /// The best state known for a letter across every guess so far, used to
    /// colour the on-screen keyboard.
    static func keyboardFeedback(for letter: Character,
                                 guesses: [String],
                                 answer: String) -> LetterFeedback? {
        let target = Character(letter.uppercased())
        var best: LetterFeedback?

        for guess in guesses {
            let scored = score(guess: guess, answer: answer)
            for (index, character) in guess.uppercased().enumerated() where character == target {
                guard index < scored.count else { continue }
                switch scored[index] {
                case .correct:
                    return .correct
                case .present:
                    best = .present
                case .absent:
                    if best == nil { best = .absent }
                }
            }
        }

        return best
    }

    /// Whether a guess is worth submitting. Returns the reason it is not.
    enum Rejection: Equatable {
        case tooShort
        case notAWord
    }

    static func validate(_ guess: String, against dictionary: Set<String>) -> Rejection? {
        let candidate = guess.uppercased()
        if candidate.count != wordSize { return .tooShort }
        if !dictionary.contains(candidate) { return .notAWord }
        return nil
    }
}
