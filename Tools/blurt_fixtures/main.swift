import Foundation

// Dumps what the Swift Vibe Blurt engine does, so the TypeScript port can be
// checked against it rather than assumed to match.
//
// Registering a room happens once and is written down, but the *words* come from
// the seed on every device. If a browser dealt a different deck from a phone,
// the two would disagree about what the describer is looking at while the score
// still ticked along — which is a bug nobody would think to look for.

let seeds: [UInt32] = [1, 42, 12345]
let allPacks = Set(BlurtPack.allCases)
/// A subset, so the browser has to agree about which packs are in and in what
/// order — not just about the shuffle.
let somePacks: Set<BlurtPack> = [.food, .play]
let rosters: [[String]] = [
    ["p1", "p2", "p3", "p4", "p5"],
    ["p1", "p2", "p3", "p4", "p5", "p6"],
]

/// Every pack's own words, in order. The browser's word list is generated from
/// these, so this catches the two drifting apart as well as disagreeing.
var packsOut: [String: [String]] = [:]
for pack in BlurtPack.allCases {
    packsOut[pack.rawValue] = pack.words
}

var decks: [String: [String]] = [:]
for seed in seeds {
    decks["\(seed)"] = BlurtDeck.shuffled(seed: seed, packs: allPacks)
}
var subsetDecks: [String: [String]] = [:]
for seed in seeds {
    subsetDecks["\(seed)"] = BlurtDeck.shuffled(seed: seed, packs: somePacks)
}

var splits: [String: [String: Int]] = [:]
var describers: [String: [String]] = [:]
var offsetsOut: [String: [String: Int]] = [:]

for seed in seeds {
    for roster in rosters {
        let key = "\(seed):\(roster.count)"
        let teams = BlurtRules.split(players: roster, seed: seed)
        splits[key] = teams.mapValues { $0.rawValue }

        let one = BlurtRules.members(of: .one, in: teams)
        let two = BlurtRules.members(of: .two, in: teams)
        let offsets = BlurtRules.describerOffsets(oneMembers: one.count,
                                                  twoMembers: two.count,
                                                  seed: seed)
        offsetsOut[key] = ["one": offsets.one, "two": offsets.two]

        // Twelve turns, so each team describes six times and the rotation wraps
        // at least once on a three-person team.
        describers[key] = (0..<12).map { turn in
            let team = BlurtRules.describingTeam(turn: turn)
            let members = team == .one ? one : two
            let offset = team == .one ? offsets.one : offsets.two
            return BlurtRules.describer(for: team, members: members, turn: turn, offset: offset) ?? ""
        }
    }
}

// The scoring is small enough to state outright rather than sample.
var scoring: [String: [String: Any]] = [:]
for turn in 0..<4 {
    let team = BlurtRules.describingTeam(turn: turn)
    scoring["\(turn)"] = ["describing": team.rawValue,
                          "scoring": BlurtRules.scoringTeam(describing: team).rawValue]
}
var winners: [String: String] = [:]
for (one, two) in [(6, 7), (7, 6), (7, 7), (0, 0), (6, 6)] {
    winners["\(one)-\(two)"] = BlurtRules.winner(one: one, two: two, target: BlurtRules.target)?.rawValue.description ?? "nil"
}

// How urgent a round feels, and how much of the bar is filled, sampled across a
// whole one. Dumped rather than described because these two decide when the
// ticking hurries and when the bar starts pulsing, and a phone and a browser
// that disagreed about the last 15% would look like a bug in whichever one the
// player was not holding.
//
// Sampled at whole percents, so the two sides agree on the keys as well as the
// values.
var urgencyAt: [String: Double] = [:]
var barFillAt: [String: Double] = [:]
var tickIntervalAt: [String: Double] = [:]
var tickVolumeAt: [String: Double] = [:]
let sampleTotal: TimeInterval = 60
for percent in 0...100 {
    let remaining = sampleTotal * (1 - Double(percent) / 100)
    let urgency = BlurtTiming.urgency(remaining: remaining, total: sampleTotal)
    urgencyAt["\(percent)"] = urgency
    barFillAt["\(percent)"] = BlurtTiming.barFill(remaining: remaining, total: sampleTotal)
    tickIntervalAt["\(percent)"] = BlurtTiming.tickInterval(urgency: urgency)
    tickVolumeAt["\(percent)"] = BlurtTiming.tickVolume(urgency: urgency)
}

// A whole round's ticks, as absolute offsets from the start. This is what stops
// one phone's rhythm drifting from another's, so it is worth pinning exactly.
var schedule: [[String: Double]] = []
for tick in BlurtTiming.tickSchedule(total: sampleTotal) {
    schedule.append(["at": tick.at, "volume": tick.volume])
}

let timing: [String: Any] = [
    "shortest": BlurtTiming.shortest,
    "longest": BlurtTiming.longest,
    "tailFraction": BlurtTiming.tailFraction,
    "steadyInterval": BlurtTiming.steadyInterval,
    "urgentInterval": BlurtTiming.urgentInterval,
    "steadyVolume": BlurtTiming.steadyVolume,
    "urgentVolume": BlurtTiming.urgentVolume,
    "sampleTotal": sampleTotal,
    "urgencyAt": urgencyAt,
    "barFillAt": barFillAt,
    "tickIntervalAt": tickIntervalAt,
    "tickVolumeAt": tickVolumeAt,
    "schedule": schedule,
]

let out: [String: Any] = [
    "target": BlurtRules.target,
    "minimumPlayers": BlurtRules.minimumPlayers,
    "minimumPerTeam": BlurtRules.minimumPerTeam,
    "wordCount": BlurtWords.all.count,
    "packOrder": BlurtPack.allCases.map(\.rawValue),
    "packs": packsOut,
    "packsChosen": somePacks.map(\.rawValue).sorted(),
    "decks": decks,
    "subsetDecks": subsetDecks,
    "timing": timing,
    "splits": splits,
    "offsets": offsetsOut,
    "describers": describers,
    "scoring": scoring,
    "winners": winners,
]

let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys, .prettyPrinted])
print(String(data: data, encoding: .utf8)!)
