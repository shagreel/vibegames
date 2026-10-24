import SwiftUI

/// How the suite should appear. `system` follows the device setting.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Match System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// For the segmented control in Preferences, where "Match System" does not
    /// fit in a third of the width.
    var shortTitle: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// `nil` hands the decision back to the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct VibeGamesApp: App {
    init() {
        // Tolerant of a missing GoogleService-Info.plist: solo play still works.
        FirebaseBootstrapper.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Tips that arrive outside a purchase — Ask to Buy approving
                // later, or one interrupted before it finished — are finished
                // here, once, rather than waiting for somebody to reopen the
                // panel they bought from.
                .task { await AppStoreTreat.finishOutstanding() }
        }
    }
}

/// Navigation root for the whole suite. New games are wired in here.
struct RootView: View {
    @AppStorage("vibegames.appearance") private var appearance = AppearancePreference.system.rawValue

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: GameRoute.self) { route in
                    switch route {
                    case .vibeFive:
                        VibeFiveView()
                    case .vibeWords:
                        VibeWordsView()
                    case .vibeSudoku:
                        VibeSudokuView()
                    case .vibeTrio:
                        VibeTrioView()
                    case .vibeBlurt:
                        VibeBlurtView()
                    case .vibeTen:
                        VibeTenView()
                    }
                }
                .navigationDestination(for: UtilityRoute.self) { route in
                    switch route {
                    case .list:
                        UtilitiesView()
                    case .dice:
                        DiceView()
                    }
                }
        }
        // Not forced: the palette resolves per appearance, so the suite follows
        // the device unless the player overrides it from the hub.
        .preferredColorScheme(AppearancePreference(rawValue: appearance)?.colorScheme)
        .tint(.accentColor)
    }
}
