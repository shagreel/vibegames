import Foundation

/// A short, game-scoped id for a player.
///
/// The global id is a 32-character UUID. At a hundred players that length is paid
/// on every presence entry and every move, so each game uses an eight-character
/// id derived from the pair instead. Different games give different ids, and the
/// global identity itself is untouched.
///
/// Shared rather than copied per game: two implementations of a hash are two
/// implementations that can disagree, and a disagreement here would show up as
/// two players who cannot see each other.
enum ShortID {
    static func of(playerID: String, gameID: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325          // FNV-1a
        for byte in Array((playerID + "|" + gameID).utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        // The last eight hex digits, left-padded — so every id is the same
        // width and the rules can match it with a fixed pattern.
        let hex = String(String(hash, radix: 16).suffix(8))
        return hex.count >= 8 ? hex : String(repeating: "0", count: 8 - hex.count) + hex
    }
}
