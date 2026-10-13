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

/// How long a turn lasts, and how the last of it is signalled.
///
/// A round is a **random** 50–70 seconds rather than a length the table chose.
/// A known length gets counted down out loud, and a table watching the same
/// number arrive together all stop together; not knowing exactly when the
/// buzzer is coming is most of what makes the last few seconds tense.
///
/// So there is no number on screen, and the bar is deliberately spent *before*
/// the round is — it fills by the time the last 15% begins, so its end is not
/// the round's end. What the last 15% has instead is the two things nobody can
/// count: a tick that hurries and gets louder, and a bar that pulses.
///
/// Everything here is a pure function of the shared clock, so the phone and the
/// browser agree about how urgent a round is — see `Tools/blurt_fixtures`.
enum BlurtTiming {

    /// The shortest and the longest a round can be.
    static let shortest = 50
    static let longest = 70

    /// The last of the round, as a fraction of it, where the game stops being
    /// able to hide how much is left. This is the one number that decides when
    /// the hurrying starts, on both platforms.
    static let tailFraction = 0.15

    /// A fresh round length. Drawn by the phone that starts the round, which is
    /// the only one that needs to: it writes the end time, and every other phone
    /// reads the length back out of `startedAt` and `endsAt`.
    static func randomTurnSeconds() -> Int {
        Int.random(in: shortest...longest)
    }

    /// How close to the end, 0 for the whole of the first 85% and 1 at the
    /// buzzer, ramping in between.
    static func urgency(remaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 0 }
        let fraction = remaining / total
        guard fraction < tailFraction else { return 0 }
        return min(1, max(0, (tailFraction - fraction) / tailFraction))
    }

    /// How much of the bar is filled: 0 at the start, 1 from the moment the last
    /// 15% begins.
    ///
    /// The divisor is what stops the bar being a countdown. It reaches its end
    /// with time still on the clock, so the bar emptying is not the buzzer and
    /// cannot be read as one.
    static func barFill(remaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 0 }
        let elapsed = 1 - remaining / total
        return min(1, max(0, elapsed / (1 - tailFraction)))
    }

    // MARK: - The tick

    /// A steady tick for the first part of the round, then one that hurries.
    ///
    /// Kept in `Double` even though the player wants `Float`, so that this whole
    /// model can be compared with the browser's exactly rather than nearly.
    static let steadyInterval: TimeInterval = 1.0
    static let urgentInterval: TimeInterval = 0.17
    static let steadyVolume: Double = 0.28
    static let urgentVolume: Double = 1.0

    /// How long to wait before the next tick, at this urgency.
    static func tickInterval(urgency: Double) -> TimeInterval {
        steadyInterval + (urgentInterval - steadyInterval) * min(1, max(0, urgency))
    }
    /// How loud the next tick is, at this urgency.
    static func tickVolume(urgency: Double) -> Double {
        steadyVolume + (urgentVolume - steadyVolume) * min(1, max(0, urgency))
    }

    /// When every tick of a round falls, and how loud each one is.
    ///
    /// Laid out as *absolute* offsets from the start rather than as a chain of
    /// waits, so a phone that joins a round already in progress falls in with
    /// the ticks the rest of the table is hearing instead of starting its own
    /// rhythm. It is also what makes the schedule checkable without a clock.
    static func tickSchedule(total: TimeInterval) -> [(at: TimeInterval, volume: Double)] {
        guard total > 0 else { return [] }
        var schedule: [(at: TimeInterval, volume: Double)] = []
        var elapsed: TimeInterval = 0

        while true {
            let urgency = urgency(remaining: total - elapsed, total: total)
            elapsed += tickInterval(urgency: urgency)
            if elapsed >= total { break }
            schedule.append((at: elapsed, volume: tickVolume(urgency: urgency)))
        }
        return schedule
    }

    // MARK: - The pulse

    /// How fast the bar blinks once the hurry has started. The browser's CSS
    /// pulse is set to the same rate, so the two look alike.
    static let pulseRate: Double = 1.4

    /// How visible the bar is at a given moment.
    ///
    /// A function of the moment rather than of any stored "am I dim right now"
    /// flag, because a flag has to be reset when a round ends and a round can end
    /// mid-blink — which would leave the next round stuck at whatever the last
    /// one was doing.
    static func pulseOpacity(at time: TimeInterval) -> Double {
        let wave = 0.5 + 0.5 * sin(2 * .pi * pulseRate * time)
        return 1 - 0.65 * wave
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

    // Note: there is deliberately no per-round deck. A room has *one* deck and
    // "play again" carries on through it rather than shuffling a new one, so a
    // table playing several games in a sitting never gets a word twice. Drawing
    // a fresh shuffle each game only looks random — ten words out of a few
    // hundred twice shares one or two, which is often enough to notice.

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
    ///
    /// `present` narrows the rotation to the people actually in the room. The
    /// team list outlives any particular phone — that is what lets somebody who
    /// drops out come back to the same side — so whoever is missing is taken
    /// *out* of the order rather than standing in for. Walking forward to the
    /// next person instead looks equivalent and is not: the stand-in also holds
    /// the turn after, so they describe twice in a row.
    ///
    /// Removing them keeps the order that remains, so a returning player lands
    /// back in their own place.
    static func describer(for team: BlurtTeam,
                          members: [String],
                          turn number: Int,
                          offset: Int,
                          present: Set<String>? = nil) -> String? {
        let roster = present.map { here in members.filter { here.contains($0) } } ?? members
        guard !roster.isEmpty else { return nil }
        return roster[(number / 2 + offset) % roster.count]
    }

    /// Who is actually holding the word.
    ///
    /// Normally the person the turn was written down for. When that phone has
    /// left, the round does not carry on around them: the word moves to whoever
    /// the rotation names among the people still here — the same rule that walks
    /// the turn on at the end of a round, so a missing player is taken out of the
    /// order rather than described around.
    ///
    /// Leaving the word with somebody who has gone is not a small thing. The other
    /// team is shown the word and told to watch for a person who is not in the
    /// room; the describer's own team-mates are told that person is describing to
    /// them. Nobody can play that round, nothing ends it early, and the clock runs
    /// down on a turn that was never taken. A player out of the room is out of the
    /// game until they come back.
    ///
    /// `nil` only when the describing team has nobody left in the room at all,
    /// which is not a game any more.
    static func holder(named describer: String,
                       team: BlurtTeam,
                       turn number: Int,
                       teams: [String: BlurtTeam],
                       present: Set<String>,
                       seed: UInt32) -> String? {
        if present.contains(describer) { return describer }

        let roster = members(of: team, in: teams)
        let offsets = describerOffsets(oneMembers: members(of: .one, in: teams).count,
                                       twoMembers: members(of: .two, in: teams).count,
                                       seed: seed)
        return self.describer(for: team,
                              members: roster,
                              turn: number,
                              offset: team == .one ? offsets.one : offsets.two,
                              present: present)
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
