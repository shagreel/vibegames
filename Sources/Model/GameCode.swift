import Foundation

/// The code that shares a game.
///
/// Two four-letter words joined by a hyphen — `cars-feed`, `dock-time` — rather
/// than eight characters of noise. A code is read out loud across a room and
/// typed in by somebody who only heard it, and nobody can say `k3f9xq2p` twice
/// the same way. Two words that already exist in the language are remembered
/// after one hearing.
///
/// It is a name, not a secret: the code only has to be hard to guess, not
/// impossible, and a few hundred words squared is tens of thousands of rooms.
enum GameCode {

    /// A fresh code: two different words.
    static func make() -> String {
        let words = GameCodeWords.all
        guard let first = words.randomElement() else { return "game-code" }

        // The same word twice reads like a mistake when it is said aloud, and
        // like a bug when it is seen.
        var second = first
        while second == first, words.count > 1 {
            second = words.randomElement() ?? first
        }
        return "\(first)-\(second)"
    }

    /// How a code is shown to a person: two words, a space apart.
    ///
    /// The separator is a reading aid and nothing more. It is what stops
    /// `carsfeed` reading as one long noise, and it is why somebody who hears the
    /// code can hold it in their head long enough to type it. It is *not* part of
    /// the code: nothing has to type it, `normalise` drops whatever punctuation
    /// arrives with it, and a hyphen, a space, or nothing at all all resolve to
    /// the same room. So the display can show the words the way they are said —
    /// and what is on screen is not a format anybody has to reproduce exactly.
    static func display(_ code: String) -> String {
        code.replacingOccurrences(of: "-", with: " ").uppercased()
    }

    /// Turns whatever somebody typed into what the database holds.
    ///
    /// Deliberately forgiving, because these arrive second-hand: somebody hears
    /// the code, types it into their phone, and lands here with capitals, a
    /// stray space, or no hyphen at all. Everything that is not a letter, a
    /// digit or a hyphen is dropped — which also disposes of the space in
    /// `cars feed` — and eight letters with no hyphen in them get one put back.
    ///
    /// Digits are kept rather than stripped so that a code from before the words
    /// changed still resolves to the room it names.
    static func normalise(_ typed: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        let cleaned = String(typed.lowercased().filter { allowed.contains($0) })

        let letters = cleaned.filter(\.isLetter)
        guard cleaned.count == 8, letters.count == 8 else { return cleaned }

        let middle = cleaned.index(cleaned.startIndex, offsetBy: 4)
        return "\(cleaned[..<middle])-\(cleaned[middle...])"
    }
}
