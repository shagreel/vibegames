import Foundation

/// The cards on the table, and the rules for keeping play possible.
///
/// Everything derives from a seed, so two devices in a shared game lay out the
/// identical table in the identical order — the whole game state is one number.
struct TrioTable {

    /// Cards face up. Starts at 12 and grows by 3 whenever the table has no trio.
    private(set) var visible: [TrioCard] = []
    /// Cards still to come, in the order they will appear.
    private(set) var remaining: [TrioCard] = []
    /// Trios taken so far.
    private(set) var triosTaken = 0
    /// Extra rows dealt because the table was stuck.
    private(set) var extraDeals = 0

    static let initialDeal = 12

    init(seed: UInt32) {
        var generator = SeededGenerator(seed: seed)
        var deck = TrioDeck.all
        deck.shuffle(using: &generator)

        visible = Array(deck.prefix(Self.initialDeal))
        remaining = Array(deck.dropFirst(Self.initialDeal))
        ensurePlayable()
    }

    // MARK: - State

    var hasTrio: Bool { TrioDeck.hasTrio(among: visible) }

    /// All trios currently on the table, as index triples.
    var availableTrios: [[Int]] { TrioDeck.allTrios(among: visible) }

    /// Over when the deck is spent and nothing on the table completes a trio.
    var isFinished: Bool { remaining.isEmpty && !hasTrio }

    var isStuck: Bool { !hasTrio && !remaining.isEmpty }

    // MARK: - Play

    /// Takes a trio if the three indices really do form one.
    @discardableResult
    mutating func takeTrio(at indices: [Int]) -> Bool {
        // The three indices must be *different* cards. Without this, three
        // copies of one card satisfy "all features the same" and would be
        // accepted — unreachable from the UI, but wrong nonetheless.
        guard indices.count == 3,
              Set(indices).count == 3,
              indices.allSatisfy({ visible.indices.contains($0) }) else { return false }

        let cards = indices.map { visible[$0] }
        guard TrioDeck.isTrio(cards[0], cards[1], cards[2]) else { return false }

        triosTaken += 1

        // Descending order, so each removal cannot shift the indices still to come.
        for index in indices.sorted(by: >) {
            if remaining.isEmpty {
                visible.remove(at: index)
            } else {
                visible[index] = remaining.removeFirst()
            }
        }

        ensurePlayable()
        return true
    }

    /// Takes the trio named by card id rather than by position.
    ///
    /// A shared game records *which cards* were taken, not where they sat: a
    /// position means different things on two phones a moment apart, but a card
    /// id means the same thing everywhere. Replaying by id is what lets two
    /// devices rebuild the identical table from the same seed and the same
    /// sequence of takes.
    ///
    /// Returns false if any of the cards has already gone — which is how a take
    /// that lost a race shows up.
    @discardableResult
    mutating func takeTrio(ids: [Int]) -> Bool {
        guard ids.count == 3, Set(ids).count == 3 else { return false }

        var indices: [Int] = []
        for id in ids {
            guard let index = visible.firstIndex(where: { $0.id == id }) else { return false }
            indices.append(index)
        }
        return takeTrio(at: indices)
    }

    /// The table a shared game is looking at, rebuilt from the seed and the
    /// takes the server accepted, in the order it accepted them.
    ///
    /// Every device runs this over the same inputs and lands on the same table,
    /// so nothing about the board has to be sent.
    static func replay(seed: UInt32, takes: [[Int]]) -> TrioTable {
        var table = TrioTable(seed: seed)
        for ids in takes { table.takeTrio(ids: ids) }
        return table
    }

    /// Deals three more whenever the table has no trio, and gives them back as
    /// soon as they are not needed.
    ///
    /// The extra deal is a way out of a dead end, not a new table size: once a
    /// take leaves the original twelve with a trio among them, the three that
    /// were added go back to the top of the deck and the board is twelve again.
    /// Without this the table only ever grew — fifteen, eighteen — and the cards
    /// dealt last sat on the board while the game went on among the first twelve.
    ///
    /// Returning them to the front of the deck, in the order they were dealt, is
    /// what keeps every device rebuilding the identical table from the same
    /// takes — this is the same arithmetic as `engine.ts`.
    private mutating func ensurePlayable() {
        while !hasTrio, !remaining.isEmpty {
            let take = min(3, remaining.count)
            visible.append(contentsOf: remaining.prefix(take))
            remaining.removeFirst(take)
            extraDeals += 1
        }

        if visible.count > Self.initialDeal {
            let base = Array(visible.prefix(Self.initialDeal))
            if TrioDeck.hasTrio(among: base) {
                remaining.insert(contentsOf: visible.dropFirst(Self.initialDeal), at: 0)
                visible = base
            }
        }
    }

    /// Whether the three cards at these indices form a trio, without taking them.
    func wouldFormTrio(_ indices: [Int]) -> Bool {
        guard indices.count == 3,
              Set(indices).count == 3,
              indices.allSatisfy({ visible.indices.contains($0) }) else { return false }
        let cards = indices.map { visible[$0] }
        return TrioDeck.isTrio(cards[0], cards[1], cards[2])
    }

    /// Whether the three *named cards* form a trio and are all still face up.
    ///
    /// Named by id, not by position. A shared game talks in card ids, and an id
    /// means a different thing on every device, so asking this the index way
    /// would silently answer a different question — and refuse every claim.
    func wouldFormTrio(ids: [Int]) -> Bool {
        var copy = self
        return copy.takeTrio(ids: ids)
    }
}
