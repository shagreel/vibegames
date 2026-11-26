import Foundation

/// The draw the widget is showing.
///
/// The widget runs without the app, so it keeps its own copy of the current
/// question and seat in its extension's defaults. Tapping "Another" writes the
/// next draw there and asks WidgetKit to read it; a relaunch does not deal a new
/// one, because the point is to be able to read the card that is already up.
enum FirstPlayerWidgetStore {
    private static let questionKey = "firstPlayer.widget.question"
    private static let seatKey = "firstPlayer.widget.seat"

    static func current() -> FirstPlayer.Draw {
        let defaults = UserDefaults.standard
        if let question = defaults.string(forKey: questionKey),
           let rawSeat = defaults.string(forKey: seatKey),
           let seat = FirstPlayer.Seat(rawValue: rawSeat) {
            return FirstPlayer.Draw(question: question, seat: seat)
        }

        let draw = FirstPlayer.draw()
        save(draw)
        return draw
    }

    static func next() -> FirstPlayer.Draw {
        let draw = FirstPlayer.draw(avoiding: current())
        save(draw)
        return draw
    }

    private static func save(_ draw: FirstPlayer.Draw) {
        let defaults = UserDefaults.standard
        defaults.set(draw.question, forKey: questionKey)
        defaults.set(draw.seat.rawValue, forKey: seatKey)
    }
}
