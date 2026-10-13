import CoreHaptics
import UIKit

/// The games' feel cues: the buzz a phone gives when the clock runs out, or when
/// somebody buzzes you for holding the word.
///
/// Nothing here needs permission, and nothing here can be detected. iOS offers no
/// way to read the one setting that decides whether any of it is felt —
/// *Settings → Sounds & Haptics → System Haptics* — and no way to ask whether a
/// cue landed, so every call either buzzes or quietly does nothing and the games
/// behave the same either way. That is also why no test can cover the feeling
/// itself: the Simulator has no Taptic Engine at all, so there is nothing to
/// feel there even when the code is right.
///
/// This is deliberately separate from `SoundEngine`: the two are different
/// senses with different failure modes, and a phone on silent still buzzes.
@MainActor
final class Haptics {
    static let shared = Haptics()

    /// How long a buzz lasts.
    ///
    /// A single `UIImpactFeedbackGenerator` runs for something like 15ms, which
    /// in a hand reads as a click rather than as an alarm — which is exactly what
    /// the time-up buzz felt like. Half a second is the shortest thing that reads
    /// as a buzz while a phone is being passed around, and holding one event for
    /// that long is the thing `Core Haptics` can do and the older generators
    /// cannot.
    static let buzzDuration: TimeInterval = 0.5

    private var engine: CHHapticEngine?
    private var coreHapticsSupported: Bool?
    /// The fallback's generator, held so it stays primed.
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)

    private init() {}

    // MARK: - Public API

    /// Starts the engine ahead of time so the first buzz has no latency. A buzz
    /// that arrives late is a buzz that arrives after somebody has already
    /// started arguing about whether time was up.
    func prepare() {
        guard supportsCoreHaptics else {
            heavy.prepare()
            return
        }
        _ = try? startedEngine()
    }

    /// A sustained buzz, for the phone that has just been caught out.
    func buzz() {
        guard supportsCoreHaptics, let engine = try? startedEngine() else {
            buzzWithoutCoreHaptics()
            return
        }

        do {
            let player = try engine.makePlayer(with: Self.buzzPattern())
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // An engine that has been reset refuses players until it is started
            // again, so rebuild it and fall back rather than drop the cue.
            teardown()
            buzzWithoutCoreHaptics()
        }
    }

    // MARK: - Core Haptics

    private var supportsCoreHaptics: Bool {
        if let coreHapticsSupported { return coreHapticsSupported }
        let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        coreHapticsSupported = supported
        return supported
    }

    private func startedEngine() throws -> CHHapticEngine {
        if let engine { return engine }

        let made = try CHHapticEngine()
        made.playsHapticsOnly = true
        // The system stops the engine for reasons the app can neither cause nor
        // see: a phone call, a media-services reset. Without these handlers the
        // next buzz is the one that never happens, which is precisely the
        // failure this whole type exists to stop repeating.
        made.stoppedHandler = { [weak self] _ in
            Task { @MainActor in self?.teardown() }
        }
        made.resetHandler = { [weak self] in
            Task { @MainActor in
                self?.teardown()
                self?.prepare()
            }
        }
        try made.start()
        engine = made
        return made
    }

    private func teardown() {
        engine?.stop()
        engine = nil
    }

    /// One hit, then a held body that fades instead of stopping dead.
    private static func buzzPattern() throws -> CHHapticPattern {
        let hit = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1),
                .init(parameterID: .hapticSharpness, value: 0.7),
            ],
            relativeTime: 0)

        let body = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1),
                .init(parameterID: .hapticSharpness, value: 0.35),
            ],
            relativeTime: 0,
            duration: buzzDuration)

        let fade = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 1),
                .init(relativeTime: buzzDuration * 0.7, value: 1),
                .init(relativeTime: buzzDuration, value: 0.2),
            ],
            relativeTime: 0)

        return try CHHapticPattern(events: [hit, body], parameterCurves: [fade])
    }

    // MARK: - Fallback

    /// For hardware without Core Haptics, which after the iOS 17 deployment
    /// target means the Simulator — where this is silent too, because there is
    /// no Taptic Engine to drive.
    private func buzzWithoutCoreHaptics() {
        let taps = 18
        let gap = Self.buzzDuration / Double(taps)
        Task { @MainActor in
            for _ in 0..<taps {
                heavy.impactOccurred(intensity: 1)
                try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
            }
        }
    }
}
