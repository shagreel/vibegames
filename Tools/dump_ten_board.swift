import Foundation

/// Dumps Vibe Ten boards as JSON: the cross-platform fixtures.
///
/// Run with `swift Tools/dump_ten_board.swift` (the sources are compiled with
/// it), then hand the output to `web/src/games/ten/board.fixtures.json` and the
/// Swift fixture table in `Tests/VibeTenBoardTests.swift`.

func values(_ stacks: [[VibeTenCell]]) -> [[Int]] {
    stacks.map { $0.map(\.value) }
}

@main
struct DumpTenBoard {
    static func main() throws {
        try run()
    }

    static func run() throws {
        let shapes = [
    ("9x18", 9, 18),
    ("6x12", 6, 12)
]
        let levels: [VibeTenDifficulty] = [.easy, .medium, .hard]
        let seed: UInt32 = 1234

        var fixtures: [String: [[Int]]] = [:]
        for (shapeName, columns, rows) in shapes {
            for level in levels {
                let board = VibeTenBoard(seed: seed, columns: columns, rows: rows,
                                         difficulty: level)
                fixtures["\(seed)-\(shapeName)-\(level.rawValue)"] = values(board.stacks)
                let wrapped = VibeTenBoard(seed: seed, columns: columns, rows: rows,
                                           wrapRows: true, difficulty: level)
                fixtures["\(seed)-\(shapeName)-\(level.rawValue)-wrap"] = values(wrapped.stacks)
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(fixtures)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    }
}
