import Foundation

/// The four features every card varies along, each with three options.
///
/// A "trio" is three cards where every feature is either the same on all three
/// or different on all three — the rule that makes the game work. The features
/// are the four zones of a charcuterie board, and each card is a picture of one
/// combination of them.
enum PlatterBase: Int, CaseIterable, Hashable, Sendable {
    case circle, hexagon, rectangle
}

enum Cheese: Int, CaseIterable, Hashable, Sendable {
    case swiss, gouda, brie
}

enum Meat: Int, CaseIterable, Hashable, Sendable {
    case prosciutto, salami, turkey
}

enum Garnish: Int, CaseIterable, Hashable, Sendable {
    case grapes, strawberry, pear
}

/// The option names, as they appear in the artwork's file names and as they are
/// spoken. One spelling, so the two cannot drift apart.
protocol NamedOption: CaseIterable, Hashable {
    var slug: String { get }
    var spoken: String { get }
}

extension PlatterBase: NamedOption {
    var slug: String {
        switch self {
        case .circle: return "circle"
        case .hexagon: return "hexagon"
        case .rectangle: return "rectangle"
        }
    }

    var spoken: String {
        switch self {
        case .circle: return "round walnut platter"
        case .hexagon: return "bamboo hexagon platter"
        case .rectangle: return "slate rectangle platter"
        }
    }
}

extension Cheese: NamedOption {
    var slug: String {
        switch self {
        case .swiss: return "swiss"
        case .gouda: return "gouda"
        case .brie: return "brie"
        }
    }

    var spoken: String {
        switch self {
        case .swiss: return "swiss wedge"
        case .gouda: return "gouda cubes"
        case .brie: return "brie round"
        }
    }
}

extension Meat: NamedOption {
    var slug: String {
        switch self {
        case .prosciutto: return "prosciutto"
        case .salami: return "salami"
        case .turkey: return "turkey"
        }
    }

    var spoken: String {
        switch self {
        case .prosciutto: return "prosciutto ribbon"
        case .salami: return "salami stack"
        case .turkey: return "turkey roll-up"
        }
    }
}

extension Garnish: NamedOption {
    var slug: String {
        switch self {
        case .grapes: return "grapes"
        case .strawberry: return "strawberry"
        case .pear: return "pear"
        }
    }

    var spoken: String {
        switch self {
        case .grapes: return "purple grapes"
        case .strawberry: return "red strawberry"
        case .pear: return "pear slices"
        }
    }
}

/// One card: a picture of one combination of the four features.
struct TrioCard: Identifiable, Hashable, Sendable {
    let base: PlatterBase
    let cheese: Cheese
    let meat: Meat
    let garnish: Garnish

    /// 0...80, unique across the deck, in the same order the artwork is numbered.
    var id: Int {
        ((base.rawValue * 3 + cheese.rawValue) * 3 + meat.rawValue) * 3 + garnish.rawValue
    }

    /// The file in the bundle. The artwork is numbered `card-01` upward in
    /// exactly this order, with the garnish varying fastest, and this is derived
    /// the same way rather than kept as a second list that could fall out of step.
    var imageName: String {
        let number = String(format: "%02d", id + 1)
        return "card-\(number)_\(base.slug)_\(cheese.slug)_\(meat.slug)_\(garnish.slug)"
    }

    /// The name to look the artwork up by. The cards ship as a folder reference
    /// in the bundle, so the folder is part of the name — and it lives here
    /// rather than in the view so the artwork tests look it up the same way the
    /// app does. A test that built its own name would pass while every card
    /// rendered blank.
    var artworkName: String { "cards/\(imageName)" }

    /// Spoken by VoiceOver, and read back by the UI tests.
    var spokenDescription: String {
        "\(base.spoken), \(cheese.spoken), \(meat.spoken), \(garnish.spoken)"
    }
}

/// The 81-card deck and the rule for what counts as a trio.
enum TrioDeck {

    static let all: [TrioCard] = PlatterBase.allCases.flatMap { base in
        Cheese.allCases.flatMap { cheese in
            Meat.allCases.flatMap { meat in
                Garnish.allCases.map { garnish in
                    TrioCard(base: base, cheese: cheese, meat: meat, garnish: garnish)
                }
            }
        }
    }

    /// Three cards form a trio when every feature is all-same or all-different.
    ///
    /// Equivalently — and this is the shortcut the rule is famous for — if two
    /// cards agree on a feature and the third differs, they are not a trio. Both
    /// forms are checked here so the tests can pin them against each other.
    static func isTrio(_ first: TrioCard, _ second: TrioCard, _ third: TrioCard) -> Bool {
        allSameOrAllDifferent(first.base, second.base, third.base)
            && allSameOrAllDifferent(first.cheese, second.cheese, third.cheese)
            && allSameOrAllDifferent(first.meat, second.meat, third.meat)
            && allSameOrAllDifferent(first.garnish, second.garnish, third.garnish)
    }

    private static func allSameOrAllDifferent<T: Equatable>(_ a: T, _ b: T, _ c: T) -> Bool {
        (a == b && b == c) || (a != b && b != c && a != c)
    }

    /// The card that completes a trio with the two given cards.
    ///
    /// Every pair has exactly one completion, which is what guarantees a trio
    /// can never be ambiguous.
    static func completingCard(_ first: TrioCard, _ second: TrioCard) -> TrioCard {
        TrioCard(base: complete(first.base, second.base),
                 cheese: complete(first.cheese, second.cheese),
                 meat: complete(first.meat, second.meat),
                 garnish: complete(first.garnish, second.garnish))
    }

    private static func complete<T: CaseIterable & Equatable & RawRepresentable>(
        _ a: T, _ b: T) -> T where T.RawValue == Int {
        if a == b { return a }
        let used = [a.rawValue, b.rawValue]
        let missing = T.allCases.first { !used.contains($0.rawValue) }!
        return missing
    }

    /// Indices of every trio among the given cards.
    static func allTrios(among cards: [TrioCard]) -> [[Int]] {
        var found: [[Int]] = []
        guard cards.count >= 3 else { return found }

        for i in 0..<(cards.count - 2) {
            for j in (i + 1)..<(cards.count - 1) {
                for k in (j + 1)..<cards.count
                where isTrio(cards[i], cards[j], cards[k]) {
                    found.append([i, j, k])
                }
            }
        }
        return found
    }

    static func hasTrio(among cards: [TrioCard]) -> Bool {
        !allTrios(among: cards).isEmpty
    }
}
