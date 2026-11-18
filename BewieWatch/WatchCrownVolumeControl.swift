import AVFAudio
import SwiftUI
import WatchKit

/// Use the system's local-output volume control, rather than changing audio gain.
struct WatchCrownVolumeControl: WKInterfaceObjectRepresentable {
    var wantsFocus: Bool
    var focusRequest: Int
    var onVisibilityChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        let control = WKInterfaceVolumeControl(origin: .local)
        control.setTintColor(.black)
        context.coordinator.observeVolume(for: control, onVisibilityChange: onVisibilityChange)
        return control
    }

    func updateWKInterfaceObject(_ control: WKInterfaceVolumeControl, context: Context) {
        let coordinator = context.coordinator
        coordinator.wantsFocus = wantsFocus
        coordinator.onVisibilityChange = onVisibilityChange
        guard wantsFocus else {
            coordinator.lastRequest = nil
            coordinator.generation &+= 1
            coordinator.visibility.reset()
            control.resignFocus()
            return
        }
        guard coordinator.lastRequest != focusRequest else { return }
        coordinator.lastRequest = focusRequest
        coordinator.generation &+= 1
        let generation = coordinator.generation
        // Focus after the native object has joined the visible interface hierarchy.
        DispatchQueue.main.async { [weak control, weak coordinator] in
            guard let coordinator, coordinator.generation == generation else { return }
            control?.focus()
        }
    }

    static func dismantleWKInterfaceObject(_ control: WKInterfaceVolumeControl, coordinator: Coordinator) {
        coordinator.generation &+= 1
        coordinator.stopObserving()
        control.resignFocus()
    }

    @MainActor
    final class Coordinator {
        var lastRequest: Int?
        var generation = 0
        var wantsFocus = false
        let visibility = WatchVolumeIndicatorVisibility()
        var onVisibilityChange: (Bool) -> Void = { _ in }
        private var observation: NSKeyValueObservation?

        func observeVolume(for control: WKInterfaceVolumeControl, onVisibilityChange: @escaping (Bool) -> Void) {
            self.onVisibilityChange = onVisibilityChange
            // Alpha preserves the mounted Crown receiver. Do not remove the
            // control, mark it hidden, or resign focus when the timer expires.
            control.setAlpha(0)
            visibility.onChange = { [weak self, weak control] visible in
                control?.setAlpha(visible ? 1 : 0)
                // Update the SwiftUI host's hit testing/accessibility next turn,
                // outside updateWKInterfaceObject's rendering transaction.
                DispatchQueue.main.async { [weak self] in
                    self?.onVisibilityChange(visible)
                }
            }
            observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.wantsFocus else { return }
                    self.visibility.volumeDidChange()
                }
            }
        }

        func stopObserving() {
            wantsFocus = false
            observation?.invalidate()
            observation = nil
            visibility.reset()
            visibility.onChange = nil
        }
    }
}
