import Foundation

// Dumps what the Swift Vibe Blurt engine does, so the TypeScript port can be
// checked against it rather than assumed to match.
//
// Registering a room happens once and is written down, but the *words* come from
// the seed on every device. If a browser dealt a different deck from a phone,
// the two would disagree about what the describer is looking at while the score
// still ticked along — which is a bug nobody would think to look for.

let seeds: [UInt32] = [1, 42, 12345]
let rosters: [[String]] = [
    ["p1", "p2", "p3", "p4", "p5"],
    ["p1", "p2", "p3", "p4", "p5", "p6"],
]

var decks: [String: [String]] = [:]
for seed in seeds {
    decks["\(seed)"] = BlurtDeck.shuffled(seed: seed)
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

let out: [String: Any] = [
    "target": BlurtRules.target,
    "wordCount": BlurtWords.all.count,
    "decks": decks,
    "splits": splits,
    "offsets": offsetsOut,
    "describers": describers,
    "scoring": scoring,
    "winners": winners,
]

let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys, .prettyPrinted])
print(String(data: data, encoding: .utf8)!)
