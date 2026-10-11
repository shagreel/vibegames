import SwiftUI
import UIKit

/// Central palette + type ramp for the whole Vibe Games suite.
///
/// Each game gets its own accent gradient, but they share a canvas that
/// resolves per appearance, so the suite follows the system light/dark setting.
///
/// **A bare `.white` is almost always a bug here.** White text on the light
/// canvas is invisible. Use the semantic tokens, and reserve `.white` for text
/// that sits on a *coloured fill* — buttons, scored tiles, keyboard keys — where
/// it is correct in both appearances.
enum VibeTheme {

    /// Resolves to `light` or `dark` depending on the current appearance.
    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    // MARK: Canvas

    static let canvasTop = adaptive(light: Color(red: 0.973, green: 0.973, blue: 0.988),
                                    dark: Color(red: 0.071, green: 0.063, blue: 0.145))
    static let canvasBottom = adaptive(light: Color(red: 0.906, green: 0.906, blue: 0.945),
                                       dark: Color(red: 0.024, green: 0.020, blue: 0.055))

    static let surface = adaptive(light: Color.black.opacity(0.045),
                                  dark: Color.white.opacity(0.06))
    static let surfaceStrong = adaptive(light: Color.black.opacity(0.075),
                                        dark: Color.white.opacity(0.10))
    static let hairline = adaptive(light: Color.black.opacity(0.12),
                                   dark: Color.white.opacity(0.12))

    static let primaryText = adaptive(light: Color(red: 0.086, green: 0.078, blue: 0.153),
                                      dark: .white)
    static let secondaryText = adaptive(light: Color.black.opacity(0.62),
                                        dark: Color.white.opacity(0.62))
    static let tertiaryText = adaptive(light: Color.black.opacity(0.45),
                                       dark: Color.white.opacity(0.38))

    // MARK: Game accents

    static let vibeFive = LinearGradient(
        colors: [Color(red: 1.00, green: 0.28, blue: 0.38),
                 Color(red: 1.00, green: 0.55, blue: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Used for the STOP action while the clock is live, so it reads as a
    /// deliberate "end this round" rather than another Start/Next.
    static let stop = LinearGradient(
        colors: [Color(red: 0.86, green: 0.14, blue: 0.30),
                 Color(red: 0.55, green: 0.08, blue: 0.32)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Used for the GO action that starts the clock once the category has been
    /// read out.
    static let goGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.76, blue: 0.46),
                 Color(red: 0.38, green: 0.91, blue: 0.62)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let calm = Color(red: 0.36, green: 0.85, blue: 0.98)
    /// The support heart. Warm enough to read as affection rather than an alert,
    /// and deliberately outside the red used for time running out.
    static let heart = Color(red: 1.00, green: 0.42, blue: 0.52)
    static let warn = Color(red: 1.00, green: 0.78, blue: 0.28)
    static let danger = Color(red: 1.00, green: 0.32, blue: 0.36)
    static let go = Color(red: 0.38, green: 0.92, blue: 0.60)
    /// Used while the category is being read, before the clock starts. Kept
    /// clearly outside the urgency ramp so it never reads as time pressure.
    static let arm = Color(red: 0.62, green: 0.52, blue: 1.00)

    // MARK: Vibe Words

    /// Accent for the word game, deliberately distinct from Vibe Five's warmth.
    static let vibeWords = LinearGradient(
        colors: [Color(red: 0.13, green: 0.72, blue: 0.66),
                 Color(red: 0.27, green: 0.52, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Vibe Sudoku

    /// Third accent, distinct from Vibe Five's warmth and Vibe Words' teal.
    static let vibeSudoku = LinearGradient(
        colors: [Color(red: 0.52, green: 0.29, blue: 0.94),
                 Color(red: 0.86, green: 0.33, blue: 0.76)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Player-entered digits, as opposed to the puzzle's givens.
    static let sudokuEntry = Color(red: 0.62, green: 0.52, blue: 1.00)
    static let sudokuSelection = Color(red: 0.52, green: 0.29, blue: 0.94)
    static let sudokuClash = Color(red: 1.00, green: 0.32, blue: 0.36)

    // MARK: Vibe Trio

    /// Fourth accent, distinct from the other three.
    static let vibeTrio = LinearGradient(
        colors: [Color(red: 0.98, green: 0.72, blue: 0.16),
                 Color(red: 0.52, green: 0.84, blue: 0.28)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The three card colours live on `TrioColor` itself, because they are game
    /// content rather than theme — chosen by measurement for colour-blind
    /// players, and pinned by `TrioColorVisionTests`. Cards are near-white, like
    /// real Set cards, so those colours stay identical in light and dark mode.
    static let trioCardFace = adaptive(light: .white,
                                       dark: Color(red: 0.95, green: 0.95, blue: 0.97))
    /// Selection ring on a card. Mid-tone so it reads against the pale face.
    static let vibeTrioBorder = Color(red: 0.98, green: 0.60, blue: 0.08)
    static let trioCardEdge = adaptive(light: Color.black.opacity(0.14),
                                       dark: Color.black.opacity(0.35))

    // MARK: Vibe Blurt

    /// Fifth accent. Warm and loud on purpose — this is the game where somebody
    /// is talking over everybody else.
    static let vibeBlurt = LinearGradient(
        colors: [Color(red: 0.96, green: 0.30, blue: 0.42),
                 Color(red: 0.99, green: 0.55, blue: 0.24)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The clock running out, as it gets close. Between `vibeBlurt`'s warmth and
    /// the danger red, so a turn in its last seconds reads as urgent rather than
    /// broken.
    static let blurtUrgent = Color(red: 1.00, green: 0.42, blue: 0.32)

    /// The two teams. They have to be tellable apart at a glance across a room,
    /// and they are deliberately not the game's own accent: the accent is the
    /// game, the team colour is you.
    static let blurtTeamOne = Color(red: 0.29, green: 0.55, blue: 0.98)
    static let blurtTeamTwo = Color(red: 0.98, green: 0.45, blue: 0.30)

    static func blurtTeam(_ team: BlurtTeam) -> Color {
        team == .one ? blurtTeamOne : blurtTeamTwo
    }

    /// Letter is in the right place.
    static let tileCorrect = Color(red: 0.24, green: 0.70, blue: 0.44)
    /// Letter is in the word, but in the wrong place.
    static let tilePresent = Color(red: 0.89, green: 0.69, blue: 0.24)
    /// Letter is not in the word.
    static let tileAbsent = adaptive(light: Color(red: 0.416, green: 0.435, blue: 0.486),
                                     dark: Color(red: 0.19, green: 0.20, blue: 0.27))
    static let tileIdle = adaptive(light: Color.black.opacity(0.04),
                                   dark: Color.white.opacity(0.04))
    static let tileBorder = adaptive(light: Color.black.opacity(0.16),
                                     dark: Color.white.opacity(0.16))

    /// A keyboard key that has not been guessed yet. Must stay clearly *lighter*
    /// than `tileAbsent` in both appearances, or a ruled-out letter is
    /// indistinguishable from an untried one. Labels on these use
    /// `primaryText`, which flips with the appearance.
    static let keyUntried = adaptive(light: Color(red: 0.874, green: 0.882, blue: 0.910),
                                     dark: Color.white.opacity(0.32))

    /// Background used behind every screen.
    static var canvas: LinearGradient {
        LinearGradient(colors: [canvasTop, canvasBottom],
                       startPoint: .top,
                       endPoint: .bottom)
    }

    /// Colour ramp for the countdown, keyed on remaining progress (1 ... 0).
    static func urgency(forProgress progress: Double) -> Color {
        switch progress {
        case 0.6...: return calm
        case 0.3..<0.6: return warn
        default: return danger
        }
    }
}

// MARK: - Reusable button styles

/// Big, thumb-friendly primary action used for Start / Stop / Next.
struct VibePrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = VibeTheme.vibeFive

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .kerning(1.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(gradient)
                    .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// Small translucent circular button used in toolbars.
struct VibeIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(VibeTheme.primaryText)
            .frame(width: 44, height: 44)
            .background(Circle().fill(VibeTheme.surfaceStrong))
            .overlay(Circle().stroke(VibeTheme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

extension View {
    /// Standard dark canvas applied to a whole screen.
    ///
    /// Implemented as a `ZStack` sibling rather than `.background` so the
    /// gradient always fills the full screen, including under the safe areas,
    /// regardless of how greedy the wrapped view is.
    func vibeCanvas() -> some View {
        ZStack {
            VibeTheme.canvas.ignoresSafeArea()
            self
        }
    }
}
