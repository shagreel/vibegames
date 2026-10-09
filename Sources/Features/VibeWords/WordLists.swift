import Foundation

/// The five-letter dictionary, loaded once from bundled text resources.
///
/// The lists are generated from the shared source by `Tools/import_words.py`
/// and are stored uppercase, matching what is written to the Realtime Database.
enum WordLists {

    /// Every word a player is allowed to guess.
    static let valid: Set<String> = Set(loadWords(named: "valid-words"))

    /// The narrower pool answers are drawn from.
    static let answers: [String] = loadWords(named: "answer-words")

    static var isLoaded: Bool { !valid.isEmpty && !answers.isEmpty }

    static func isPlayable(_ word: String) -> Bool {
        valid.contains(word.uppercased())
    }

    /// Picks an answer using the system's cryptographic generator.
    static func randomAnswer() -> String {
        answers.randomElement() ?? "ABOUT"
    }

    private static func loadWords(named name: String) -> [String] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing bundled word list: \(name).txt")
            return []
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
