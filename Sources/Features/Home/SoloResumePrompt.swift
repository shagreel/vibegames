import SwiftUI

/// The question a solo game asks when there is already one on this device.
///
/// One alert, the same words in every game: what is waiting, and the two things
/// a player might want — carry on, or start again. Cancel is there because
/// tapping "Play on this device" by mistake should not discard anything.
struct SoloResumePrompt: ViewModifier {
    @Binding var pending: SoloProgress?
    let onContinue: () -> Void
    let onNewGame: () -> Void

    private var isPresented: Binding<Bool> {
        Binding(get: { pending != nil },
                set: { presented in if !presented { pending = nil } })
    }

    func body(content: Content) -> some View {
        content.alert("A game is in progress", isPresented: isPresented) {
            Button("Continue") {
                pending = nil
                onContinue()
            }
            Button("New game", role: .destructive) {
                pending = nil
                onNewGame()
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text(pending?.summary ?? "")
        }
    }
}

extension View {
    /// Asks whether to continue the solo game saved on this device, or start a
    /// new one. `pending` is set by the game's own "Play on this device" tap.
    func soloResumePrompt(_ pending: Binding<SoloProgress?>,
                          onContinue: @escaping () -> Void,
                          onNewGame: @escaping () -> Void) -> some View {
        modifier(SoloResumePrompt(pending: pending,
                                  onContinue: onContinue,
                                  onNewGame: onNewGame))
    }
}
