import Foundation

/// Who goes first, decided by a question with one answer.
///
/// A question from the bank picks one person — the one with the longest hair,
/// the one whose birthday is next — and a second answer says which seat starts:
/// that person, the person on their left, or the person on their right. The
/// second part exists so the same person cannot quietly be chosen twice in a
/// row, and so reading the answer out loud has an obvious end.
///
/// The bank is deliberately things every table can settle by looking: no
/// question needs a fact nobody has, and none needs a judgement call ("whose
/// taste is best"), because an argument is the one thing a decider must not
/// start.
enum FirstPlayer {

    /// Which seat at the table starts.
    enum Seat: String, CaseIterable, Identifiable {
        /// Whoever the question picked.
        case them
        case left
        case right

        var id: String { rawValue }

        /// The whole instruction, said as one sentence: this is what the phone
        /// is handed over to read.
        var instruction: String {
            switch self {
            case .them: return "That person goes first"
            case .left: return "The person to their left goes first"
            case .right: return "The person to their right goes first"
            }
        }

        /// A word for the screen reader, and for a test that wants to know the
        /// seat without parsing the sentence.
        var name: String {
            switch self {
            case .them: return "them"
            case .left: return "the person to their left"
            case .right: return "the person to their right"
            }
        }
    }

    /// One turn of the card: a question, and the seat it starts at.
    struct Draw: Equatable {
        let question: String
        let seat: Seat
    }

    /// The questions.
    ///
    /// Short, answerable in a second, and all resolved by comparing the people
    /// in the room with each other rather than by knowing anything in advance.
    static let questions: [String] = [
        "Who has the longest hair?",
        "Who has travelled the farthest this month?",
        "Whose birthday is next?",
        "Who is the tallest?",
        "Who is wearing the shortest socks?",
        "Who most recently petted a dog?",
        "Who has the most keys on them?",
        "Who has the earliest alarm set for tomorrow?",
        "Who has the newest pair of shoes?",
        "Who lives closest to here?",
        "Who has the most siblings?",
        "Who woke up earliest today?",
        "Who has gone the longest without a haircut?",
        "Who has the largest hands?",
        "Who has the most cash on them?",
        "Who has the smallest handwriting?",
        "Who has the coldest hands?",
        "Who has taken the most steps today?",
        "Who most recently did the washing up?",
        "Who has the shortest name?",
        "Who is wearing the most colours?",
        "Who has been to the most countries?",
        "Who has the fewest photos on their phone?",
        "Who has the loudest whistle?",
        "Who has the most plants at home?",
        "Who has the biggest shoes?",
        "Who has the most unread messages?",
        "Who has the newest phone?",
        "Who has the most pockets?",
        "Who can stand on one leg the longest?",
        "Who most recently laughed until it hurt?",
        "Who has the oldest keyring?",
        "Who has the most apps open?",
        "Who has the tidiest bag?",
        "Who has the largest family?",
        "Who has the coldest nose?",
        "Who has been awake the longest?",
        "Who most recently ate a biscuit?",
    ]

    /// Draws a question and a seat, never repeating the question just answered.
    ///
    /// Without that, a decider that reads a question out and is handed straight
    /// back would happily say the same thing twice, and the table would think it
    /// had not worked.
    static func draw(avoiding previous: Draw? = nil,
                     using generator: inout some RandomNumberGenerator) -> Draw {
        var pool = questions
        if let previous, pool.count > 1, let index = pool.firstIndex(of: previous.question) {
            pool.remove(at: index)
        }
        let question = pool.randomElement(using: &generator) ?? questions[0]
        let seat = Seat.allCases.randomElement(using: &generator) ?? .them
        return Draw(question: question, seat: seat)
    }

    /// A draw with the system's own randomness, for the screen.
    static func draw(avoiding previous: Draw? = nil) -> Draw {
        var generator = SystemRandomNumberGenerator()
        return draw(avoiding: previous, using: &generator)
    }
}
