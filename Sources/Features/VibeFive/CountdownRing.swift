import SwiftUI

/// The big countdown dial beneath the category card.
struct CountdownRing: View {

    /// Mirrors the game phase, but kept local so this stays a dumb component.
    /// The dial is off screen entirely while the clock is idle, so there is
    enum State {
        case idle
        case running
        case stopped
        case buzzed
    }

    let state: State
    /// Seconds to display. The caller passes the round
    /// countdown, the frozen time or zero depending on the state.
    let remaining: TimeInterval
    let progress: Double
    var diameter: CGFloat = 176

    private var tint: Color {
        switch state {
        case .buzzed: return VibeTheme.danger
        case .stopped: return VibeTheme.go
        case .idle, .running: return VibeTheme.urgency(forProgress: progress)
        }
    }

    private var displaySeconds: Int {
        max(0, Int(ceil(remaining - 0.0001)))
    }

    /// Only a live clock is allowed to pulse.
    private var isUrgent: Bool {
        state == .running && progress > 0 && progress <= 0.4
    }

    private var caption: String {
        switch state {
        case .idle, .running: return "SECONDS"
        case .stopped: return "LEFT"
        case .buzzed: return "TIME"
        }
    }

    private var lineWidth: CGFloat { diameter * 0.085 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(VibeTheme.hairline, lineWidth: lineWidth)

            // Hidden at rest so the round line cap does not leave a stray dot
            // on the dial once the clock has run out.
            if progress > 0.004 {
                Circle()
                    .trim(from: 0, to: min(1, progress))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.6), radius: 16)
            }

            VStack(spacing: -4) {
                Text("\(displaySeconds)")
                    .font(.system(size: diameter * 0.40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VibeTheme.primaryText)
                    .contentTransition(.numericText(countsDown: true))
                Text(caption)
                    .font(.system(size: diameter * 0.072, weight: .bold, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(captionTint)
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isUrgent ? 1.05 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isUrgent)
        .animation(.easeInOut(duration: 0.25), value: state == .buzzed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var captionTint: Color {
        state == .buzzed ? VibeTheme.danger.opacity(0.9) : VibeTheme.tertiaryText
    }

    private var accessibilityDescription: String {
        switch state {
        case .buzzed: return "Time is up"
        case .stopped: return "Stopped with \(displaySeconds) seconds left"
        case .idle, .running: return "\(displaySeconds) seconds remaining"
        }
    }
}
