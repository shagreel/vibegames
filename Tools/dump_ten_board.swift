import Foundation

/// Dumps Vibe Ten boards as JSON: the cross-platform fixtures.
///
/// Compile it with the engine sources, then write the output to
/// `web/src/games/ten/board.fixtures.json` and update the fixture table in
/// `Tests/VibeTenBoardTests.swift`:
///
///     swiftc -O Sources/Model/SeededGenerator.swift \
///       Sources/Features/VibeTen/VibeTenBoard.swift \
///       Tools/dump_ten_board.swift -o /tmp/dump_ten_board
///     /tmp/dump_ten_board > web/src/games/ten/board.fixtures.json

func values(_ stacks: [[VibeTenCell]]) -> [[Int]] {
    stacks.map { $0.map(\.value) }
}

@main
struct DumpTenBoard {
    static func main() {
        let seed: UInt32 = 1234
        var fixtures: [String: [[Int]]] = [:]
        for rows in VibeTenBoard.rowOptions {
            let board = VibeTenBoard(seed: seed, rows: rows)
            fixtures["\(seed)-\(VibeTenBoard.defaultColumns)x\(rows)"] = values(board.stacks)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(fixtures)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    }
}
