import Foundation

/// Plays the hurry at the end of a Blurt round.
///
/// The ticks are laid out as absolute offsets from the round's start rather than
/// as a chain of waits, which matters for two reasons. A phone that arrives
/// mid-round falls in with the rhythm the table is already hearing instead of
/// starting one of its own — several phones drifting a beat apart would sound
/// like a fault. And the whole schedule becomes a value that can be checked
/// against the browser's without playing a round to hear it.
///
/// The first 85% of a round is one tick a second. After that the ticks close in
/// on each other and get louder, which is the only thing telling the table that
/// time is nearly up — there is no number on screen by design.
@MainActor
final class BlurtTicker {

    private var task: Task<Void, Never>?

    /// Ticks through a round that is already running, then stops on its own when
    /// the round's time is up.
    func start(startedAt: Date, total: TimeInterval) {
        stop()

        let schedule = BlurtTiming.tickSchedule(total: total)
        guard !schedule.isEmpty else { return }

        task = Task { [weak self] in
            for tick in schedule {
                guard self != nil else { return }

                let when = startedAt.addingTimeInterval(tick.at)
                let wait = when.timeIntervalSinceNow

                // A tick that has already gone by belongs to the table. Firing
                // the ones a late arrival missed would make a burst of them.
                if wait < -0.05 { continue }
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                }
                if Task.isCancelled { return }

                SoundEngine.shared.play(.tick, volume: Float(tick.volume))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
