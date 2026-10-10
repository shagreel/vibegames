import Foundation

// Dumps what the Swift Sudoku engine generates, so the TypeScript port can be
// checked against it rather than assumed to match. A shared race sends a seed
// and a difficulty, and nothing else: if the two engines carve differently, two
// players are racing different boards while the screen says otherwise.
func grid(_ values: [Int]) -> String {
    values.map(String.init).joined()
}

var out: [String: Any] = [:]
let seeds: [UInt32] = [1, 2, 3, 7, 42, 12345, 999]
let difficulties: [SudokuDifficulty] = [.easy, .medium, .hard]

for seed in seeds {
    for difficulty in difficulties {
        let generated = SudokuGenerator.puzzle(seed: seed, difficulty: difficulty)
        out["\(seed)-\(difficulty.rawValue)"] = [
            "seed": Int(seed),
            "difficulty": difficulty.rawValue,
            "givens": grid(generated.givens),
            "solution": grid(generated.solution),
            "clues": generated.clueCount,
            "grade": SudokuGrader.grade(generated.givens).rawValue,
        ]
    }
}

let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys, .prettyPrinted])
print(String(data: data, encoding: .utf8)!)
