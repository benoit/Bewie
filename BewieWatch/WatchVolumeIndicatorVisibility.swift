import Foundation

/// Visibility only: the native WatchKit control still owns the actual volume UI.
@MainActor
final class WatchVolumeIndicatorVisibility {
    private(set) var isVisible = false
    var onChange: ((Bool) -> Void)?
    private var hideTask: Task<Void, Never>?

    func volumeDidChange() {
        hideTask?.cancel()
        setVisible(true)
        hideTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            self?.setVisible(false)
        }
    }

    func reset() {
        hideTask?.cancel()
        hideTask = nil
        setVisible(false)
    }

    private func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
        onChange?(visible)
    }

    deinit { hideTask?.cancel() }
}
