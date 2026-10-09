import Foundation

// Dumps what the Swift engine does, so the TypeScript port can be checked
// against it rather than assumed to match. Cross-play depends on it.
func ids(_ cards: [TrioCard]) -> [Int] { cards.map(\.id) }

var out: [String: Any] = [:]
let seeds: [UInt32] = [1, 2, 3, 7, 42, 12345, 4294967295]

var shuffles: [String: [Int]] = [:]
var tables: [String: [String: [Int]]] = [:]
var games: [String: [[Int]]] = [:]

for seed in seeds {
    var generator = SeededGenerator(seed: seed)
    var deck = TrioDeck.all
    deck.shuffle(using: &generator)
    shuffles["\(seed)"] = ids(deck)

    let table = TrioTable(seed: seed)
    tables["\(seed)"] = ["visible": ids(table.visible), "remaining": ids(table.remaining)]

    var played = TrioTable(seed: seed)
    var takes: [[Int]] = []
    while let trio = played.availableTrios.first {
        takes.append(trio.map { played.visible[$0].id }.sorted())
        _ = played.takeTrio(at: trio)
    }
    games["\(seed)"] = takes
}

out["shuffles"] = shuffles
out["tables"] = tables
out["games"] = games

let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
