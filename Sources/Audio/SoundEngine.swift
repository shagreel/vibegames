import AVFoundation

/// Generates the game's sound effects at runtime, so the app ships with no
/// audio assets and stays tiny.
///
/// The buzzer is a stack of detuned square waves with a slight downward pitch
/// bend and a low-pass pass, which reads as a classic game-show "time's up".
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    enum Cue: CaseIterable {
        case start
        case tick
        case buzzer
    }

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100

    private var players: [Cue: AVAudioPlayerNode] = [:]
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var isRunning = false
    /// Set when the audio stack is unavailable (e.g. a locked-down simulator).
    /// We stop retrying on every cue so failures stay cheap.
    private var hasFailed = false

    private init() {}

    // MARK: - Public API

    /// Builds buffers and starts the engine ahead of time so the first cue has
    /// no latency.
    func warmUp() {
        prepareIfNeeded()
    }

    func play(_ cue: Cue) {
        prepareIfNeeded()
        guard isRunning,
              let player = players[cue],
              let buffer = buffers[cue] else { return }

        if player.isPlaying {
            player.stop()
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    func stopAll() {
        for player in players.values where player.isPlaying {
            player.stop()
        }
    }

    /// Releases the audio session when the game screen goes away.
    func deactivate() {
        stopAll()
        guard isRunning else { return }
        engine.stop()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Engine lifecycle

    private func prepareIfNeeded() {
        guard !isRunning, !hasFailed else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                         channels: 1) else {
            hasFailed = true
            return
        }

        for cue in Cue.allCases {
            guard let buffer = makeBuffer(for: cue, format: format) else {
                hasFailed = true
                return
            }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            buffers[cue] = buffer
            players[cue] = player
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            hasFailed = true
            teardownNodes()
        }
    }

    private func teardownNodes() {
        for player in players.values {
            engine.detach(player)
        }
        players.removeAll()
        buffers.removeAll()
    }

    // MARK: - Synthesis

    private func makeBuffer(for cue: Cue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration: Double
        switch cue {
        case .start: duration = 0.30
        case .tick: duration = 0.08
        case .buzzer: duration = 1.05
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = frameCount
        let total = Int(frameCount)

        for index in 0..<total {
            let t = Double(index) / sampleRate
            let progress = Double(index) / Double(total)

            let value: Double
            switch cue {
            case .start: value = Self.startSample(t: t, progress: progress)
            case .tick: value = Self.tickSample(t: t, progress: progress)
            case .buzzer: value = Self.buzzerSample(t: t, progress: progress)
            }

            samples[index] = Float(max(-1, min(1, value)))
        }

        // Smooth the harsh digital edges. The buzzer gets more passes because
        // stacked square waves are especially brittle.
        Self.lowPass(samples, count: total, passes: cue == .buzzer ? 3 : 1)

        return buffer
    }

    /// Two quick rising notes: "ba-doop".
    private static func startSample(t: Double, progress: Double) -> Double {
        let split = 0.5
        let isSecondNote = progress >= split
        let frequency = isSecondNote ? 880.0 : 587.33
        let local = isSecondNote
            ? (progress - split) / (1 - split)
            : progress / split

        let wave = 0.6 * sin(2 * .pi * frequency * t)
            + 0.25 * sin(2 * .pi * frequency * 2 * t)
        return wave * envelope(local, attack: 0.04, release: 0.65) * 0.5
    }

    /// A short, dry click for the final seconds.
    private static func tickSample(t: Double, progress: Double) -> Double {
        let wave = sin(2 * .pi * 1_450 * t)
        let attack = progress < 0.02 ? progress / 0.02 : 1
        return wave * exp(-30 * progress) * attack * 0.45
    }

    /// Detuned square-wave buzzer with a pitch bend.
    private static func buzzerSample(t: Double, progress: Double) -> Double {
        let bend = 1.0 - 0.16 * progress
        let fundamental = 138.0 * bend

        let wave = 0.60 * square(t, fundamental)
            + 0.34 * square(t, fundamental * 1.013)
            + 0.26 * square(t, fundamental * 0.5)
            + 0.14 * square(t, fundamental * 2.02)
        let roughness = 1.0 + 0.07 * sin(2 * .pi * 24 * t)

        return wave * roughness * envelope(progress, attack: 0.008, release: 0.22) * 0.4
    }

    // MARK: - DSP helpers

    private static func square(_ t: Double, _ frequency: Double) -> Double {
        sin(2 * .pi * frequency * t) >= 0 ? 1 : -1
    }

    private static func envelope(_ progress: Double, attack: Double, release: Double) -> Double {
        if progress < attack { return progress / attack }
        if progress > 1 - release { return max(0, (1 - progress) / release) }
        return 1
    }

    /// Simple cascaded one-pole low-pass filter.
    private static func lowPass(_ samples: UnsafeMutablePointer<Float>,
                                count: Int,
                                passes: Int,
                                coefficient: Float = 0.5) {
        guard count > 1 else { return }
        for _ in 0..<passes {
            var previous: Float = 0
            for index in 0..<count {
                previous = coefficient * samples[index] + (1 - coefficient) * previous
                samples[index] = previous
            }
        }
    }
}
