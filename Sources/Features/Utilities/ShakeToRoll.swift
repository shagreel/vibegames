import CoreMotion
import Foundation

/// Works out whether the phone has been shaken back and forth.
///
/// The rule is the shape of the movement rather than its size: a shake swings the
/// acceleration one way and then the other several times in about a second. One
/// big jolt — a bump, a step, dropping the phone onto a sofa — is not a shake,
/// and neither is a slow sway. Keeping the rule here, away from Core Motion, is
/// what makes it testable: the tests feed it numbers and never touch a sensor.
struct ShakeRecogniser {

    /// How hard a swing has to be before it counts, in g.
    var threshold: Double = 1.4
    /// How many swings, and how close together.
    var swings = 3
    var window: TimeInterval = 1.2
    /// After a roll, the phone has to settle for this long before it can shake
    /// another one — a shake is a couple of seconds of movement.
    var quietAfterTrigger: TimeInterval = 1.0

    private var lastSign = 0
    private var swingTimes: [TimeInterval] = []
    private var lastTrigger: TimeInterval = -.greatestFiniteMagnitude

    /// Feeds one accelerometer reading in, and says whether it completed a shake.
    mutating func ingest(x: Double, y: Double, z: Double, at time: TimeInterval) -> Bool {
        guard time - lastTrigger > quietAfterTrigger else { return false }

        let magnitude = (x * x + y * y + z * z).squareRoot()
        guard magnitude > threshold else { return false }

        // Whichever way the phone is being pushed, it is one direction of a
        // swing; a change of direction is a new swing.
        let dominant = [x, y, z].max { abs($0) < abs($1) } ?? 0
        let sign = dominant >= 0 ? 1 : -1
        defer { lastSign = sign }

        guard sign != lastSign else { return false }
        swingTimes.append(time)
        swingTimes.removeAll { time - $0 > window }

        guard swingTimes.count >= swings else { return false }
        swingTimes.removeAll()
        lastTrigger = time
        return true
    }
}

/// The sensor side of it: keeps the phone's acceleration coming while the dice
/// are on screen and calls back when there has been a shake.
@MainActor
final class ShakeMonitor {
    private let motion = CMMotionManager()
    private var recogniser = ShakeRecogniser()
    private var onShake: (() -> Void)?

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    func start(onShake: @escaping () -> Void) {
        guard isAvailable, !motion.isDeviceMotionActive else { return }
        self.onShake = onShake
        motion.deviceMotionUpdateInterval = 0.02

        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let acceleration = data.userAcceleration
            if recogniser.ingest(x: acceleration.x,
                                 y: acceleration.y,
                                 z: acceleration.z,
                                 at: data.timestamp) {
                onShake()
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        onShake = nil
        recogniser = ShakeRecogniser()
    }
}
