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
    func add(sides: Int) {
        guard sides > 0 else { return }
        dice.append(Die(sides: sides, value: rollWithin(1...sides)))
    }

    /// Rolls every die on the table again, keeping the table as it is.
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
