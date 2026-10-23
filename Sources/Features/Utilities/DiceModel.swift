import Foundation

/// One die on the table.
///
/// It remembers its own sides: rolling rerolls the dice that are there, it does
/// not deal new ones, so a d4 stays a d4 however many times it is rolled.
struct Die: Identifiable, Equatable {
    let id = UUID()
    let sides: Int
    var value: Int
}

/// The dice bag.
///
/// The rules are here rather than in the view so they can be tested without one:
/// what a die rolls, what "roll" means and what "clear" means are all decided in
/// this file. The generator is injectable for the same reason — a test that
/// cannot repeat a roll is not testing the roll.
@MainActor
final class DiceModel: ObservableObject {
    /// The dice anyone might have in a bag. d4 to d20 covers what a party game
    /// needs, and d20 is the loudest one.
    static let sidesOptions = [4, 6, 8, 10, 12, 20]

    /// How many dice the table takes. Past this the table is a mess, the results
    /// list stops being readable, and the physics has more bodies than a phone
    /// screen can usefully show.
    static let maximum = 20

    @Published private(set) var dice: [Die] = []

    /// Held as a closure rather than as a generator so a seeded one can be
    /// handed in without making the model generic: `Int.random` needs the
    /// generator in place, and a captured one keeps its state between rolls.
    private let rollWithin: (ClosedRange<Int>) -> Int

    init(generator: RandomNumberGenerator = SystemRandomNumberGenerator()) {
        var generator = generator
        rollWithin = { range in Int.random(in: range, using: &generator) }
    }

    var isEmpty: Bool { dice.isEmpty }

    /// Adds a die of that many sides, already rolled — tapping d12 and getting
    /// an unrolled die would be a second tap for no reason.
    @discardableResult
    func add(sides: Int) -> Die? {
        guard sides > 0, dice.count < Self.maximum else { return nil }
        let die = Die(sides: sides, value: rollWithin(1...sides))
        dice.append(die)
        return die
    }

    /// Records what a die actually landed on.
    ///
    /// Physics decides the number, so the model is told rather than asked: a die
    /// can come to rest on any of its faces, and the number on the one looking up
    /// is the result. It is clamped to the die's own sides so a bad read cannot
    /// put a 9 on a d6.
    func record(_ value: Int, for id: UUID) {
        guard let index = dice.firstIndex(where: { $0.id == id }) else { return }
        dice[index].value = min(max(value, 1), dice[index].sides)
    }

    /// Rolls every die on the table again, keeping the table as it is.
    ///
    /// Provisional: the physics throw replaces these as each die settles, but a
    /// die always holds a number inside its own range, even mid-air.
    func rollAll() {
        for index in dice.indices {
            dice[index].value = rollWithin(1...dice[index].sides)
        }
    }

    /// Takes every die off the table. The sides are not remembered: the next
    /// tap deals whatever was tapped.
    func clear() {
        dice.removeAll()
    }
}
