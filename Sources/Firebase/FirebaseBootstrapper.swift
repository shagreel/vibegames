import Foundation
import FirebaseAppCheck
import FirebaseCore
import FirebaseDatabase

/// Brings Firebase up once, and tolerates not being configured yet.
///
/// The app is deliberately usable before Firebase exists: solo play needs no
/// backend at all, and only the multiplayer lobby requires it. So a missing
/// `GoogleService-Info.plist` is a supported state, not a crash.
enum FirebaseBootstrapper {

    /// True once `FirebaseApp.configure()` has succeeded.
    private(set) static var isConfigured = false

    /// Realtime Database handle, or `nil` when running without a backend.
    private(set) static var database: Database?

    /// Why the backend is unavailable, for surfacing in the UI.
    enum UnavailableReason {
        case missingConfigurationFile
        case configurationFailed(String)

        var explanation: String {
            switch self {
            case .missingConfigurationFile:
                return "Add GoogleService-Info.plist to enable playing with friends."
            case .configurationFailed(let message):
                return "Could not reach the game service: \(message)"
            }
        }
    }

    private(set) static var unavailableReason: UnavailableReason?

    /// Call once, as early as possible.
    static func configure() {
        guard !isConfigured, unavailableReason == nil else { return }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            // Not an error: solo play works fine without it.
            unavailableReason = .missingConfigurationFile
            return
        }

        // App Check must be installed before FirebaseApp.configure().
        AppCheck.setAppCheckProviderFactory(VibeAppCheckProviderFactory())

        FirebaseApp.configure()

        guard FirebaseApp.app() != nil else {
            unavailableReason = .configurationFailed("Firebase did not initialise")
            return
        }

        database = Database.database()
        isConfigured = true
    }
}

/// Supplies the right App Check attestation provider for the platform.
///
/// The web client uses reCAPTCHA; a native client cannot, so this uses App
/// Attest on real hardware and Firebase's debug provider in the simulator.
/// Debug tokens must be registered in the Firebase console, or App Check
/// enforcement will reject them.
final class VibeAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
        #endif
    }
}
