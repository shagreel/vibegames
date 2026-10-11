import Foundation

/// Which side of the room. There are two, always, and that is the whole game:
/// scoring is what the *other* team does to you.
enum BlurtTeam: Int, CaseIterable, Equatable, Sendable {
    case one = 1
    case two = 2

    var other: BlurtTeam { self == .one ? .two : .one }

    /// What the scoreboard calls it. Names rather than players, because a team
    /// outlives any particular phone being awake.
    var title: String {
        switch self {
        case .one: return "Team One"
        case .two: return "Team Two"
        }
    }
}

/// Why a turn stopped.
enum BlurtEnd: String, Equatable, Sendable {
    /// The clock ran out. The team *not* holding the word scores.
    case time
    /// Somebody on the other team said the describer broke the rules.
    case blurt
}

/// The deck, laid out from the game's seed.
///
/// The database never carries the words — only a seed and how far into the deck
/// the game has got. Every phone derives the same list, and only the describer's
/// screen shows the one that is in play.
enum BlurtDeck {

    static func shuffled(seed: UInt32) -> [String] {
        var generator = SeededGenerator(seed: seed)
        var deck = BlurtWords.all
        deck.shuffle(using: &generator)
        return deck
    }

    /// The deck for a round.
    ///
    /// A room keeps one seed; "play again" advances the round rather than
    /// rewriting it, so the reset stays a single transaction and the words still
    /// come out different the second time.
    static func shuffled(seed: UInt32, round: Int) -> [String] {
        shuffled(seed: seed &+ UInt32(truncatingIfNeeded: round))
    }

    /// The word for a turn.
    ///
    /// Wraps, deliberately: a long game can outlast the list, and the same word
    /// coming round again is better than a blank screen mid-turn.
    static func word(at index: Int, in deck: [String]) -> String {
        guard !deck.isEmpty else { return "" }
        let wrapped = ((index % deck.count) + deck.count) % deck.count
        return deck[wrapped]
    }
}

/// How a room of people becomes a game.
///
/// Pure, and free of any database or clock, so the awkward parts — who is on
/// which team, whose turn it is, who scored — can be tested without a network
/// and reproduced identically in the browser.
enum BlurtRules {

    /// Splits a roster into two teams, as evenly as the numbers allow.
    ///
    /// The host works this out once when the game starts and writes it down,
    /// rather than every phone deriving it: the roster changes when somebody's
    /// app reconnects, and a team assignment that reshuffled itself mid-game
    /// would be worse than useless.
    static func split(players: [String], seed: UInt32) -> [String: BlurtTeam] {
        var generator = SeededGenerator(seed: seed)
        // Sorted before shuffling, so the same room and the same seed always
        // splits the same way whatever order the players arrived in.
        var order = players.sorted()
        order.shuffle(using: &generator)

        var teams: [String: BlurtTeam] = [:]
        for (index, player) in order.enumerated() {
            teams[player] = index.isMultiple(of: 2) ? .one : .two
        }
        return teams
    }

    /// One team's players, in a stable order.
    static func members(of team: BlurtTeam, in teams: [String: BlurtTeam]) -> [String] {
        teams.filter { $0.value == team }.map(\.key).sorted()
    }

    /// Turns alternate, and team one has the first one.
    static func describingTeam(turn number: Int) -> BlurtTeam {
        number.isMultiple(of: 2) ? .one : .two
    }

    /// Where each team starts in its own rotation.
    ///
    /// Drawn from the seed so the first describer is random, but drawn in a
    /// fixed order — team one, then team two — so every device and both
    /// platforms walk the generator the same way.
    static func describerOffsets(oneMembers: Int, twoMembers: Int, seed: UInt32) -> (one: Int, two: Int) {
        var generator = SeededGenerator(seed: seed)
        let one = Int.random(in: 0..<max(1, oneMembers), using: &generator)
        let two = Int.random(in: 0..<max(1, twoMembers), using: &generator)
        return (one, two)
    }

    /// Whose phone shows the word.
    ///
    /// Rotates through the team so it is not the same person every time. `number`
    /// counts turns from zero across the whole game, so a team's own count is
    /// half of it.
    static func describer(for team: BlurtTeam,
                          members: [String],
                          turn number: Int,
                          offset: Int) -> String? {
        guard !members.isEmpty else { return nil }
        let within = (number / 2 + offset) % members.count
        return members[within]
    }

    /// The team that takes the point when a turn ends — never the one that was
    /// describing. This is the tension the game is built on: describing earns
    /// nothing, it only passes the risk on.
    static func scoringTeam(describing: BlurtTeam) -> BlurtTeam {
        describing.other
    }

    /// First to the target wins. Nil while the game is still going.
    static func winner(one: Int, two: Int, target: Int) -> BlurtTeam? {
        if one >= target { return .one }
        if two >= target { return .two }
        return nil
    }

    /// The default target. A game that lasts a while but not all evening.
    static let target = 7
}
