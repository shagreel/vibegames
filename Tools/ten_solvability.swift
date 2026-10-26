import Foundation

/// Asks a question the deal stopped answering by construction: how often does a
/// freshly dealt board have a way through it?
///
/// The deal draws valid pairs and then shuffles their digits onto the board, so
/// whether a board can be cleared is a property of the shuffle. This tools deals
/// a run of boards and tries to solve each one: at every step it takes the pair
/// whose two digits have the fewest ways to pair with anything else, and breaks
/// ties at random. That is a player's heuristic, not a proof engine — a found
/// solution is proof that the board is clearable; a board it cannot clear within
/// the attempt budget is reported as unsolved, which is not proof that no
/// solution exists.
///
/// Build it with the engine and run it:
///
///     swiftc -O Sources/Model/SeededGenerator.swift \
///       Sources/Features/VibeTen/VibeTenBoard.swift \
///       Tools/ten_solvability.swift -o /tmp/ten_solvability
///     /tmp/ten_solvability --boards 500 --restarts 300
///
/// Options:
///   --boards N       boards per start-row setting (default 500)
///   --first N        the first seed to deal (default 1)
///   --restarts N     solver attempts per board (default 1000)
///   --rows LIST      start rows to test (default 12,14,16,18)
///   --mode MODE      remove (default) or dim
///   --wrap YES|NO    whether the rows join end to end (default NO)
///   --seed N         the solver's own seed (default 1)
///   --detail         print the attempts each board needed

@main
struct TenSolvability {

    static func main() {
        var boards = 500
        var firstSeed = 1
        var restarts = 1000
        var rows = VibeTenBoard.rowOptions
        var mode = VibeTenMode.remove
        var wrap = false
        var toolSeed: UInt32 = 1
        var detail = false

        var arguments = Array(CommandLine.arguments.dropFirst())
        while let flag = arguments.first {
            arguments.removeFirst()
            func value() -> String { arguments.isEmpty ? "" : arguments.removeFirst() }
            switch flag {
            case "--boards": boards = max(1, Int(value()) ?? boards)
            case "--first": firstSeed = max(1, Int(value()) ?? firstSeed)
            case "--restarts": restarts = max(1, Int(value()) ?? restarts)
            case "--rows":
                rows = value().split(separator: ",").compactMap { Int($0) }
                    .filter { VibeTenBoard.rowOptions.contains($0) }
                if rows.isEmpty { rows = VibeTenBoard.rowOptions }
            case "--mode":
                mode = VibeTenMode(rawValue: value()) ?? .remove
            case "--wrap":
                wrap = ["YES", "yes", "true", "1"].contains(value())
            case "--seed":
                toolSeed = UInt32(value()) ?? toolSeed
            case "--detail":
                detail = true
            default:
                FileHandle.standardError.write("unknown option \(flag)\n".data(using: .utf8)!)
                exit(2)
            }
        }

        var generator = SeededGenerator(seed: toolSeed)

        print("Vibe Ten solvability — \(mode.rawValue) mode, rows "
              + (wrap ? "joined" : "not joined"))
        print("\(boards) boards per row count, up to \(restarts) attempts each")
        print("")

        for startRows in rows {
            var solved = 0
            var failures: [UInt32] = []
            var attemptsUsed: [Int] = []
            var report: [(UInt32, Int)] = []
            let clock = Date()

            for seed in firstSeed..<(firstSeed + boards) {
                let board = VibeTenBoard(seed: UInt32(seed), startRows: startRows,
                                         wrapRows: wrap)
                var solvedThisBoard = false
                var attempt = 0
                while attempt < restarts && !solvedThisBoard {
                    solvedThisBoard = solve(board, mode: mode, generator: &generator)
                    attempt += 1
                }
                if solvedThisBoard {
                    solved += 1
                    attemptsUsed.append(attempt)
                    if detail { report.append((UInt32(seed), attempt)) }
                } else {
                    failures.append(UInt32(seed))
                }
            }

            attemptsUsed.sort()
            let median = attemptsUsed.isEmpty ? 0 : attemptsUsed[attemptsUsed.count / 2]
            let p95 = attemptsUsed.isEmpty ? 0
                : attemptsUsed[min(attemptsUsed.count - 1, Int(Double(attemptsUsed.count) * 0.95))]
            let elapsed = String(format: "%.1f", Date().timeIntervalSince(clock))
            let rate = String(format: "%.1f", Double(solved) / Double(boards) * 100)
            print("\(startRows) rows: \(solved)/\(boards) boards have a solution "
                  + "(\(rate)%) in \(elapsed)s")
            print("         attempts: median \(median), p95 \(p95), "
                  + "max \(attemptsUsed.last ?? 0)")
            if !failures.isEmpty {
                print("         no solution found for seeds: "
                      + failures.prefix(20).map(String.init).joined(separator: ",")
                      + (failures.count > 20 ? " …" : ""))
            }
            if detail {
                for (seed, attempts) in report {
                    print("         seed \(seed): \(attempts) attempts")
                }
            }
        }
    }

    /// One attempt to clear the board. A found clearance is a witness: the takes
    /// are legal according to the same rules the game uses.
    static func solve(_ start: VibeTenBoard,
                      mode: VibeTenMode,
                      generator: inout SeededGenerator) -> Bool {
        var board = start
        var steps = 0
        let limit = start.columns * start.rows / 2 + 16

        while !board.isCleared && steps < limit {
            let matches = board.availableMatches()
            if matches.isEmpty { return false }

            // How many ways each digit can pair with anything. Taking the pair
            // whose two ends have the fewest alternatives is the player's best
            // guess at a digit that would otherwise get stranded.
            var degree: [VibeTenBoard.Position: Int] = [:]
            for (first, second) in matches {
                degree[first, default: 0] += 1
                degree[second, default: 0] += 1
            }

            var bestScore = Int.max
            var best: [(VibeTenBoard.Position, VibeTenBoard.Position)] = []
            for pair in matches {
                let score = (degree[pair.0] ?? 0) + (degree[pair.1] ?? 0)
                if score < bestScore {
                    bestScore = score
                    best = [pair]
                } else if score == bestScore {
                    best.append(pair)
                }
            }

            let pair = best[Int.random(in: 0..<best.count, using: &generator)]
            guard board.take(pair.0, pair.1, mode: mode) != nil else { return false }
            steps += 1
        }

        return board.isCleared
    }
}
