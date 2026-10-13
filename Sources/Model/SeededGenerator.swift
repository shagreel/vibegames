import Foundation

/// A small SplitMix64 generator.
///
/// Determinism is the whole point: a shared game stores only a seed, and every
/// device must build the byte-identical puzzle from it. `SystemRandomNumberGenerator`
/// would give each player a different board.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt32) {
        // The seed *is* the state; `next()` does the add-and-mix, which is how
        // SplitMix64 is defined.
        //
        // This used to pre-scramble it — `seed * gamma + constant` — which looks
        // like it only spreads low seeds out and is in fact much worse: because
        // `next()` adds the gamma again, seed `n + 1` produced the *same stream
        // as seed `n`, one draw later*. A game that derives a second shuffle
        // from `seed + 1` therefore got almost the same deck back, which is
        // exactly what Similar Vibe's "play again" did: measured at 10 of the
        // first 20 words shared, against 1.3 by chance.
        state = UInt64(seed)
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
