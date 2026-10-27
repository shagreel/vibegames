import Foundation

/// Dumps the rows after the first deal as JSON: the cross-platform fixture for
/// the endless stream.
///
/// The board's first eighteen rows are one deal. After that the stream keeps
/// going in two-row blocks, drawn from seeds taken out of the board's own
/// generator. That derivation has to match in Swift and in TypeScript, and this
/// file pins it the way `board.fixtures.json` pins the deal:
///
///     swiftc -O Sources/Model/SeededGenerator.swift \
///       Sources/Features/VibeTen/VibeTenBoard.swift \
///       Tools/dump_ten_stream.swift -o /tmp/dump_ten_stream
///     /tmp/dump_ten_stream > web/src/games/ten/stream.fixtures.json

struct StreamFixture: Codable {
    let seed: UInt32
    let columns: Int
    let firstRow: Int
    let rows: [[Int]]
}

@main
struct DumpTenStream {
    static func main() {
        let seed: UInt32 = 1234
        let firstRow = VibeTenBoard.maximumRows
        let rows = (firstRow..<(firstRow + 6)).map {
            VibeTenBoard.rowDigits(seed: seed, columns: VibeTenBoard.defaultColumns, row: $0)
        }
        let fixture = StreamFixture(seed: seed,
                                    columns: VibeTenBoard.defaultColumns,
                                    firstRow: firstRow,
                                    rows: rows)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(fixture)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    }
}
