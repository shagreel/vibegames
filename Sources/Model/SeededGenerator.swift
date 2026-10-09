import Foundation

/// A small SplitMix64 generator.
///
/// Determinism is the whole point: a shared game stores only a seed, and every
/// device must build the byte-identical puzzle from it. `SystemRandomNumberGenerator`
/// would give each player a different board.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt32) {
        // Any non-zero scramble works; this one just spreads low seeds out.
        state = UInt64(seed) &* 0x9E37_79B9_7F4A_7C15 &+ 0x2545_F491_4F6C_DD1D
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
