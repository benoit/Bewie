import Foundation

/// A completed flight may reveal controls once, for that track only. If its
/// music is still downloading, reveal that track’s loading controls at arrival.
struct TrackArrivalPlayer {
    private var requestedID: Int?
    private var hasArrived = false

    @discardableResult
    mutating func begin(_ id: Int, showImmediately: Bool = false) -> Bool {
        // Immediate controls have no pending arrival presentation: dismissing
        // them during the flight must not cause them to reopen at its end.
        requestedID = showImmediately ? nil : id
        hasArrived = false
        return showImmediately
    }

    mutating func arrive(_ id: Int) {
        guard requestedID == id else { return }
        hasArrived = true
    }

    mutating func cancel() {
        requestedID = nil
        hasArrived = false
    }

    mutating func takePresentation(playingID: Int?, failedID: Int?, loadingID: Int? = nil) -> Bool {
        guard let requestedID else { return false }
        if failedID == requestedID { cancel(); return false }
        guard hasArrived, loadingID == requestedID || playingID == requestedID else { return false }
        cancel()
        return true
    }
}
