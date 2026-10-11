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

/// How long a turn lasts. Chosen in the lobby, because a table of adults and a
/// table with a nine-year-old want very different amounts of it.
enum BlurtDuration: Int, CaseIterable, Identifiable, Sendable {
    case brisk = 30
    case standard = 60
    case generous = 90
    case long = 120

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .brisk: return "30 seconds"
        case .standard: return "1 minute"
        case .generous: return "90 seconds"
        case .long: return "2 minutes"
        }
    }

    var blurb: String {
        switch self {
        case .brisk: return "Frantic. Words come round again."
        case .standard: return "The one the box would have picked."
        case .generous: return "Room to think, and to get stuck."
        case .long: return "For a big table and slow clues."
        }
    }

    static let `default` = BlurtDuration.standard

    /// Anything the database hands back that is not one of ours becomes the
    /// default rather than a crash or a zero-length turn.
    static func nearest(to seconds: Int) -> BlurtDuration {
        allCases.min(by: { abs($0.rawValue - seconds) < abs($1.rawValue - seconds) }) ?? .default
    }
}

/// The deck, laid out from the game's seed and the packs the room chose.
///
/// The database never carries the words — only a seed, a round and which packs
/// are on. Every phone derives the same list, and only the describer's screen
/// shows the one that is in play.
enum BlurtDeck {

    /// Every word in the chosen packs, in pack order.
    ///
    /// Pack order rather than the order they were ticked in: the deck has to
    /// come out the same on every phone, and two people ticking the same boxes
    /// in a different order is not a difference worth having.
    static func words(in packs: Set<BlurtPack>) -> [String] {
        let chosen = packs.isEmpty ? Set(BlurtPack.allCases) : packs
        return BlurtPack.allCases.filter { chosen.contains($0) }.flatMap(\.words)
    }

    static func shuffled(seed: UInt32, packs: Set<BlurtPack>) -> [String] {
        var generator = SeededGenerator(seed: seed)
        var deck = words(in: packs)
        deck.shuffle(using: &generator)
        return deck
    }

    /// The deck for a round.
    ///
    /// A room keeps one seed; "play again" advances the round rather than
    /// rewriting it, so the reset stays a single transaction and the words still
    /// come out different the second time.
    static func shuffled(seed: UInt32, round: Int, packs: Set<BlurtPack>) -> [String] {
        shuffled(seed: seed &+ UInt32(truncatingIfNeeded: round), packs: packs)
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

    /// Two on each side, so there is always somebody to describe to and
    /// somebody on the other team to catch you doing it.
    static let minimumPerTeam = 2
    static let minimumPlayers = minimumPerTeam * 2
}
