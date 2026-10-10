import SwiftUI

/// The Vibe Five game screen.
///
/// Flow: **Start** reveals a category and starts the five second clock →
/// the clock hits zero and the buzzer sounds → **Next** deals a new category.
struct VibeFiveView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VibeFiveModel()
    @State private var isShowingSettings = false
    @State private var settingsDetent: PresentationDetent = .large
    @State private var flashOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: !model.isRunning)) { context in
                let remaining = model.remaining(at: context.date)
                let progress = remaining / VibeFiveModel.roundDuration
                screen(remaining: remaining,
                       progress: progress,
                       size: geometry.size)
            }
        }
        .vibeCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(false)
        .task {
            AppAnalytics.screen(.five)
            SoundEngine.shared.warmUp()
        }
        .onDisappear { model.endSession() }
        // Five has no winner, only whether the table beat the clock: stopping
        // the round yourself is the good ending, the buzzer is the other one.
        // Observed rather than logged in the model because a round can end from
        // a tap *or* from the ticker running out, and one place beats two.
        .onChange(of: model.phase) { _, newPhase in
            switch newPhase {
            case .stopped:
                AppAnalytics.gameFinish(.five, mode: .solo,
                                        outcome: .won, round: model.roundNumber)
            case .buzzed:
                AppAnalytics.gameFinish(.five, mode: .solo,
                                        outcome: .lost, round: model.roundNumber)
            default:
                break
            }
        }
        .sensoryFeedback(trigger: model.tickCount) { _, _ in
            model.hapticsEnabled ? .impact(weight: .light, intensity: 0.55) : nil
        }
        .sensoryFeedback(trigger: model.buzzCount) { _, _ in
            model.hapticsEnabled ? .impact(weight: .heavy, intensity: 1.0) : nil
        }
        .sensoryFeedback(trigger: model.phase) { _, newPhase in
            guard model.hapticsEnabled else { return nil }
            switch newPhase {
            case .revealed: return .impact(weight: .light, intensity: 0.5)
            case .running: return .impact(weight: .medium, intensity: 0.8)
            case .stopped: return .impact(weight: .heavy, intensity: 0.8)
            case .ready, .buzzed: return nil
            }
        }
        .onChange(of: model.buzzCount) { _, _ in
            flashOpacity = 0.45
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 30_000_000)
                withAnimation(.easeOut(duration: 0.6)) { flashOpacity = 0 }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            VibeFiveSettingsView(model: model)
                // Eleven packs need the tall sheet, so open there.
                .presentationDetents([.medium, .large], selection: $settingsDetent)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Layout

    private func screen(remaining: TimeInterval,
                        progress: Double,
                        size: CGSize) -> some View {
        ZStack {
            VStack(spacing: 0) {
                progressBar(progress: progress)
                header
                categoryCard(size: size)

                // No dial while the category is being read: nothing on screen
                // should read as a countdown, and the card gets the room
                // instead. The dial appearing is itself the signal that the
                // clock has started.
                if !model.isRevealed {
                    CountdownRing(state: ringState,
                                  remaining: remaining,
                                  progress: progress,
                                  diameter: ringDiameter(for: size))
                        .accessibilityIdentifier("vibeFive.ring")
                        .padding(.top, 10)
                        .padding(.bottom, 18)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                primaryButton
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85),
                       value: model.isRevealed)

            Color.red
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func ringDiameter(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.21, 132), 208)
    }

    /// Only consulted when the dial is on screen, which is never while the
    /// category is revealed but the clock is idle.
    private var ringState: CountdownRing.State {
        switch model.phase {
        case .running: return .running
        case .stopped: return .stopped
        case .buzzed: return .buzzed
        case .ready, .revealed: return .idle
        }
    }

    // MARK: - Pieces

    private func progressBar(progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(VibeTheme.hairline.opacity(0.6))
                Rectangle()
                    .fill(progressBarStyle(progress: progress))
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private func progressBarStyle(progress: Double) -> AnyShapeStyle {
        switch model.phase {
        case .buzzed: return AnyShapeStyle(VibeTheme.danger)
        case .ready, .revealed, .running, .stopped:
            // While the category is revealed but the clock is idle, `progress` is 1, so the bar
            // simply sits full until the clock actually starts.
            return AnyShapeStyle(VibeTheme.urgency(forProgress: progress))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(VibeIconButtonStyle())
            .accessibilityLabel("Back to games")

            VStack(spacing: 3) {
                Text("VIBE FIVE")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .kerning(3.5)
                    .foregroundStyle(VibeTheme.primaryText)
                Text(model.roundNumber == 0 ? "Ready to play" : "Round \(model.roundNumber)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(VibeTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                SupportButton(game: .five)

                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(VibeIconButtonStyle())
                .accessibilityLabel("Game settings")
                .accessibilityIdentifier("vibeFive.settings")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private func categoryCard(size: CGSize) -> some View {
        let fontSize = min(size.width * 0.118, 76)

        return ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(borderStyle, lineWidth: 2)
                }

            if model.phase == .ready {
                readyPlaceholder
            } else {
                Text(model.category?.text ?? "")
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.32)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .foregroundStyle(VibeTheme.primaryText)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 26)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Category: \(model.category?.text ?? "")")
                    .accessibilityIdentifier("vibeFive.category")
            }

            if let badge = statusBadge {
                Text(badge.title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(badge.tint))
                    .shadow(color: badge.tint.opacity(0.7), radius: 18)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(y: -16)
                    .accessibilityIdentifier(badge.identifier)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: model.phase)
    }

    /// Overlay badge announcing the current state, when it needs one.
    private var statusBadge: (title: String, tint: Color, identifier: String)? {
        switch model.phase {
        case .revealed:
            return ("GET READY", VibeTheme.arm, "vibeFive.getReady")
        case .buzzed:
            return ("TIME'S UP!", VibeTheme.danger, "vibeFive.timesUp")
        case .stopped:
            return ("STOPPED", VibeTheme.go, "vibeFive.stopped")
        case .ready, .running:
            return nil
        }
    }

    private var borderStyle: Color {
        switch model.phase {
        case .revealed: return VibeTheme.arm.opacity(0.7)
        case .buzzed: return VibeTheme.danger
        case .stopped: return VibeTheme.go.opacity(0.7)
        case .ready, .running: return VibeTheme.hairline
        }
    }

    private var readyPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "5.circle.fill")
                .font(.system(size: 62, weight: .bold))
                .foregroundStyle(VibeTheme.vibeFive)
                .shadow(color: Color(red: 1, green: 0.35, blue: 0.35).opacity(0.5), radius: 20)

            Text("Tap START to reveal a category")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
                .multilineTextAlignment(.center)

            Text("Read it out, then start the clock when you're ready")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 26)
        .accessibilityIdentifier("vibeFive.ready")
    }

    private var primaryButton: some View {
        Button {
            model.primaryAction()
        } label: {
            HStack(spacing: 10) {
                if let symbol = model.primaryButtonSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 25, weight: .black))
                }
                Text(model.primaryButtonTitle)
            }
        }
        .buttonStyle(VibePrimaryButtonStyle(gradient: primaryGradient))
        .accessibilityIdentifier("vibeFive.primary")
        .accessibilityLabel(model.primaryButtonTitle)
        .accessibilityHint(primaryHint)
        .animation(.easeInOut(duration: 0.22), value: model.phase)
    }

    private var primaryGradient: LinearGradient {
        switch model.phase {
        case .revealed: return VibeTheme.goGradient
        case .running: return VibeTheme.stop
        case .ready, .stopped, .buzzed: return VibeTheme.vibeFive
        }
    }

    private var primaryHint: String {
        switch model.phase {
        case .ready:
            return "Reveals a category"
        case .revealed:
            return "Starts the five second clock"
        case .running:
            return "Ends the round early"
        case .stopped:
            return "Deals the next category"
        case .buzzed:
            return "Reveals the next category"
        }
    }
}
