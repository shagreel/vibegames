/// Finds seeds whose deck deals a given word first.
///
/// The Similar Vibe screenshots on the landing page show a word, and a word is a
/// pure function of the room's seed — so changing the word on the page means
/// finding another seed for `UITests/VibeBlurtScreenshots.swift` to pin. Nothing
/// else can do it: the deal is Swift's own `Array.shuffle` over SplitMix64, so a
/// replica in another language would be a guess.
///
/// Compiles against the real pack files rather than a copy of them, so a word
/// added to a pack is immediately findable:
///
///   swiftc -O -o /tmp/vibe-find-seed Tools/find_blurt_seed.swift \
///     Sources/Features/VibeBlurt/BlurtEngine.swift \
///     Sources/Features/VibeBlurt/BlurtPack.swift \
///     Sources/Features/VibeBlurt/Packs/*.swift \
///     Sources/Model/SeededGenerator.swift
///   /tmp/vibe-find-seed "Game Night"
///
/// Prints the first few seeds that deal the word first, with the words that
/// follow each — the buzz screenshot shows the deck's fourth word, so a seed
/// worth pinning is one where that is a word worth reading too.
import Foundation

@main
enum FindBlurtSeed {
    static func main() {
        let arguments = CommandLine.arguments.dropFirst()
        let wanted = arguments.first ?? "Game Night"
        let howMany = Int(arguments.dropFirst().first ?? "") ?? 5

        // Every pack, which is what a room has until somebody turns one off.
        let packs = Set(BlurtPack.allCases)
        let library = BlurtDeck.words(in: packs)

        print("The deck is \(library.count) words across \(BlurtPack.allCases.count) packs.")
        guard library.contains(wanted) else {
            print("\(wanted) is not in the deck — add it to a pack first.")
            exit(1)
        }

        /// How many seeds to walk before giving up. The word is one of thousands, so a
        /// handful of hits turn up in the first few thousand; this is a ceiling, not an
        /// expectation.
        let ceiling: UInt32 = 500_000

        var found = 0
        var seed: UInt32 = 0

        while found < howMany && seed < ceiling {
            let deck = BlurtDeck.shuffled(seed: seed, packs: packs)
            if deck.first == wanted {
                // The buzz screen photographs the word at index 3, so the four that
                // follow are shown rather than just the one.
                let following = (1...4).map { BlurtDeck.word(at: $0, in: deck) }.joined(separator: ", ")
                print("  seed \(seed)  →  \(wanted) · \(following)")
                found += 1
            }
            seed += 1
        }

        if found == 0 {
            print("No seed under \(ceiling) deals \(wanted) first.")
            exit(1)
        }
        print("\nPin one of these in UITests/VibeBlurtScreenshots.swift.")
    }
}
