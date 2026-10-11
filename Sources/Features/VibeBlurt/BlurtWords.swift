import Foundation

/// Every word the game can draw, in pack order.
///
/// The packs exist so a room can choose what kind of thing it wants to describe;
/// this is the union, which is what a game with every pack switched on uses.
enum BlurtWords {
    static let all: [String] = BlurtPack.allCases.flatMap(\.words)
}
