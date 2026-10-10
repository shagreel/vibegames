import Combine
import Foundation
import UIKit

/// Drives one game of Vibe Five.
///
/// The clock is derived from a wall-clock `startedAt` rather than accumulated
/// ticks, so the countdown stays accurate even if the run loop hiccups. A light
/// 20 Hz task only exists to fire the tick/buzzer cues and end the round; the
/// smooth animated ring reads ``remaining(at:)`` directly from the render loop.
///
/// Uses `ObservableObject` rather than the `@Observable` macro so the project
/// builds in environments that cannot run Swift macro plugins.
@MainActor
final class VibeFiveModel: ObservableObject {

    enum Phase: Equatable {
        /// Waiting for the player to press Start. The category is hidden.
        case ready
        /// Category revealed, clock not running. Stays here indefinitely —
        /// the table reads and talks at its own pace until someone starts
        /// the clock.
        case revealed
        /// Category revealed, clock counting down.
        case running
        /// The player ended the round early. Clock cancelled, no buzzer.
        case stopped
        /// The clock ran out and the buzzer sounded.
        case buzzed
    }

    // MARK: Tuning

    static let roundDuration: TimeInterval = 5
    /// How many of the final whole seconds get an audible tick.
    static let tickWindow = 3

    // MARK: Observable state

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var category: VibeCategory?
    @Published private(set) var roundNumber = 0
    @Published private(set) var startedAt: Date?
    /// Seconds that were left on the clock when the player pressed Stop.
    @Published private(set) var frozenRemaining: TimeInterval = 0

    /// Bumped every time the buzzer fires — used as a `sensoryFeedback` trigger.
    @Published private(set) var buzzCount = 0
    /// Bumped on each audible tick — used as a `sensoryFeedback` trigger.
    @Published private(set) var tickCount = 0

    @Published private(set) var soundEnabled = true
    @Published private(set) var hapticsEnabled = true
    @Published private(set) var enabledPacks: Set<CategoryPack> = Set(CategoryPack.allCases)

    // MARK: Private

    private enum Key {
        static let sound = "vibefive.sound"
        static let haptics = "vibefive.haptics"
        static let packs = "vibefive.packs"
    }

    private let defaults = UserDefaults.standard
    private var deck: [VibeCategory] = []
    private var deckIndex = 0
    private var ticker: Task<Void, Never>?
    private var lastWholeSecond: Int?

    init() {
        loadSettings()
        rebuildDeck()
    }

    // MARK: Derived values

    /// Seconds left, evaluated at an arbitrary instant so the view can animate
    /// between model updates.
    func remaining(at date: Date) -> TimeInterval {
        switch phase {
        case .ready, .revealed:
            return Self.roundDuration
        case .running:
            guard let startedAt else { return Self.roundDuration }
            return max(0, Self.roundDuration - date.timeIntervalSince(startedAt))
        case .stopped:
            return frozenRemaining
        case .buzzed:
            return 0
        }
    }

    /// 1.0 at the moment of pressing Start, falling to 0.0 at the buzzer.
    func progress(at date: Date) -> Double {
        remaining(at: date) / Self.roundDuration
    }

    var isRunning: Bool { phase == .running }
    /// Category on screen, clock not started — waiting on the table.
    var isRevealed: Bool { phase == .revealed }

    var primaryButtonTitle: String {
        switch phase {
        case .ready: return "START"
        case .revealed: return "START"
        case .running: return "Done!"
        case .stopped, .buzzed: return "NEXT"
        }
    }

    /// SF Symbol shown alongside the title, when the action benefits from one.
    var primaryButtonSymbol: String? {
        switch phase {
        case .revealed: return "play.fill"
        case .running: return "checkmark"
        case .ready, .stopped, .buzzed: return nil
        }
    }

    var activePromptCount: Int {
        CategoryLibrary.count(in: enabledPacks)
    }

    var allPacksEnabled: Bool {
        enabledPacks.count == CategoryPack.allCases.count
    }

    // MARK: Game flow

    /// The single button: Start, Start (again, for the clock), Done!, or Next.
    func primaryAction() {
        switch phase {
        case .ready, .stopped, .buzzed:
            revealCategory()
        case .revealed:
            beginCountdown()
        case .running:
            stopRound()
        }
    }

    /// Ends the round early at the player's request.
    ///
    /// Deliberately silent — the buzzer means the clock beat you, this does not.
    private func stopRound() {
        guard phase == .running, let startedAt else { return }

        frozenRemaining = max(0, Self.roundDuration - Date().timeIntervalSince(startedAt))
        stopTicker()
        self.startedAt = nil
        phase = .stopped
        releaseIdleTimer()
    }

    /// Deals a category and shows it. The clock does **not** start — the table
    /// reads it, talks it over, and starts the clock when it is ready.
    private func revealCategory() {
        category = drawCategory()
        roundNumber += 1
        startedAt = nil
        lastWholeSecond = nil
        phase = .revealed

        // No ticker: nothing is counting until the clock is started.
        stopTicker()
        releaseIdleTimer()
    }

    /// Starts the five second clock for the category already on screen.
    private func beginCountdown() {
        guard phase == .revealed else { return }

        startedAt = Date()
        lastWholeSecond = nil
        phase = .running

        // A round is the unit of play here, so it is what gets counted. Five is
        // single-device by nature and has no second mode.
        AppAnalytics.gameStart(.five, mode: .solo, round: roundNumber)

        if soundEnabled { SoundEngine.shared.play(.start) }
        UIApplication.shared.isIdleTimerDisabled = true
        startTicker()
    }

    /// Back to the opening state, keeping the deck position and round count.
    func resetToReady() {
        stopTicker()
        phase = .ready
        category = nil
        startedAt = nil
        frozenRemaining = 0
        lastWholeSecond = nil
        releaseIdleTimer()
        SoundEngine.shared.stopAll()
    }

    /// Full reset including round counter and a fresh shuffled deck.
    func restartSession() {
        resetToReady()
        roundNumber = 0
        deck = []
        deckIndex = 0
        rebuildDeck()
    }

    /// Frees the audio session and screen lock. Call when leaving the screen.
    func endSession() {
        stopTicker()
        releaseIdleTimer()
        SoundEngine.shared.deactivate()
    }

    // MARK: Settings

    func setSound(_ isOn: Bool) {
        soundEnabled = isOn
        defaults.set(isOn, forKey: Key.sound)
        if !isOn { SoundEngine.shared.stopAll() }
    }

    func setHaptics(_ isOn: Bool) {
        hapticsEnabled = isOn
        defaults.set(isOn, forKey: Key.haptics)
    }

    func togglePack(_ pack: CategoryPack) {
        if enabledPacks.contains(pack) {
            // Never let the player strand themselves with zero prompts.
            guard enabledPacks.count > 1 else { return }
            enabledPacks.remove(pack)
        } else {
            enabledPacks.insert(pack)
        }
        persistPacks()
    }

    func toggleAllPacks() {
        if allPacksEnabled {
            enabledPacks = [CategoryPack.allCases[0]]
        } else {
            enabledPacks = Set(CategoryPack.allCases)
        }
        persistPacks()
    }

    // MARK: Deck

    private func drawCategory() -> VibeCategory {
        if deckIndex >= deck.count {
            rebuildDeck()
        }
        guard deckIndex < deck.count else {
            // Only reachable if every pack were somehow empty.
            return VibeCategory(text: "Anything you like", pack: .random)
        }
        let drawn = deck[deckIndex]
        deckIndex += 1
        return drawn
    }

    /// Reshuffles the pool of enabled prompts, avoiding an immediate repeat of
    /// the category currently on screen.
    func rebuildDeck() {
        var pool = CategoryLibrary.categories(in: enabledPacks)
        pool.shuffle()

        if pool.count > 1,
           let current = category,
           let first = pool.first,
           first == current {
            pool.swapAt(0, pool.count - 1)
        }

        deck = pool
        deckIndex = 0
    }

    // MARK: Clock

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000)
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard phase == .running else { return }
        tickRunning()
    }

    private func tickRunning() {
        guard let startedAt else { return }

        let remaining = Self.roundDuration - Date().timeIntervalSince(startedAt)
        let whole = Int(ceil(remaining))

        if whole != lastWholeSecond {
            lastWholeSecond = whole
            if whole >= 1, whole <= Self.tickWindow {
                tickCount += 1
                if soundEnabled { SoundEngine.shared.play(.tick) }
            }
        }

        if remaining <= 0 {
            finishRound()
        }
    }

    private func finishRound() {
        stopTicker()
        startedAt = nil
        frozenRemaining = 0
        phase = .buzzed
        buzzCount += 1
        releaseIdleTimer()
        if soundEnabled { SoundEngine.shared.play(.buzzer) }
    }

    private func releaseIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: Persistence

    private func loadSettings() {
        if defaults.object(forKey: Key.sound) != nil {
            soundEnabled = defaults.bool(forKey: Key.sound)
        }
        if defaults.object(forKey: Key.haptics) != nil {
            hapticsEnabled = defaults.bool(forKey: Key.haptics)
        }

        if let raw = defaults.array(forKey: Key.packs) as? [String] {
            let restored = raw.compactMap(CategoryPack.init(rawValue:))
            if !restored.isEmpty {
                enabledPacks = Set(restored)
            }
        }
    }

    private func persistPacks() {
        defaults.set(enabledPacks.map(\.rawValue).sorted(), forKey: Key.packs)
        rebuildDeck()
    }
}
