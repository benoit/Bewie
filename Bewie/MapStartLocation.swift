import CoreLocation
import Foundation
import Observation

/// The small Core Location surface used by the one-time opening camera request.
/// A fake manager can exercise permission changes and delayed fixes in tests.
@MainActor
protocol MapLocationManaging: AnyObject {
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var desiredAccuracy: CLLocationAccuracy { get set }
    func requestWhenInUseAuthorization()
    func requestLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: MapLocationManaging { }

/// Resolves one location request. It never follows the user or saves their fix.
@MainActor
@Observable
final class MapStartLocation: NSObject, CLLocationManagerDelegate {
    nonisolated static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 48.8530, longitude: 2.3499)

    private(set) var coordinate = fallbackCoordinate
    private(set) var isResolved = false
    private(set) var resolvedFix: CLLocation?

    @ObservationIgnored private let manager: any MapLocationManaging
    @ObservationIgnored private let timeout: Duration
    @ObservationIgnored private let fallbackOnFailure: Bool
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var state = State.idle

    private enum State {
        case idle, authorizing, locating, finished, cancelled
    }

    init(manager: any MapLocationManaging = CLLocationManager(), timeout: Duration = .seconds(12),
         fallbackOnFailure: Bool = true,
         desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters) {
        self.manager = manager
        self.timeout = timeout
        self.fallbackOnFailure = fallbackOnFailure
        super.init()
        manager.desiredAccuracy = desiredAccuracy
        manager.delegate = self
    }

    /// Call when the map first appears. Repeated calls never prompt or locate again.
    func start() {
        guard state == .idle else { return }
        state = .authorizing
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            authorizationChanged(manager.authorizationStatus)
        }
    }

    /// Foreground refreshes never ask for new permission.
    @discardableResult
    func startIfAuthorized() -> Bool {
        guard state == .idle,
              manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else { return false }
        start()
        return true
    }

    /// Manual navigation wins over any pending permission response or location fix.
    func cancel() {
        guard state != .finished, state != .cancelled else { return }
        state = .cancelled
        stopRequest()
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        guard state == .authorizing || state == .locating else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            guard state == .authorizing else { return }
            state = .locating
            timeoutTask = Task { @MainActor [weak self, timeout] in
                do { try await Task.sleep(for: timeout) } catch { return }
                self?.fail()
            }
            manager.requestLocation()
        case .denied, .restricted:
            // Core Location also reports .denied when services are disabled globally.
            fail()
        case .notDetermined:
            break
        @unknown default:
            fail()
        }
    }

    private func fail() {
        guard state == .authorizing || state == .locating else { return }
        if fallbackOnFailure {
            finish(at: Self.fallbackCoordinate)
        } else {
            state = .finished
            stopRequest()
        }
    }

    private func finish(at coordinate: CLLocationCoordinate2D) {
        guard state == .authorizing || state == .locating else { return }
        state = .finished
        stopRequest()
        self.coordinate = coordinate
        isResolved = true
    }

    private func stopRequest() {
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        manager.delegate = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationChanged(self.manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Approximate Location is sufficient. Reject invalid or stale cached fixes,
        // but do not ask for temporary Precise Location access.
        let now = Date()
        let location = locations.reversed().first {
            let age = now.timeIntervalSince($0.timestamp)
            return $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy.isFinite
                && CLLocationCoordinate2DIsValid($0.coordinate)
                && age >= -60 && age <= 300
        }
        let latitude = location?.coordinate.latitude
        let longitude = location?.coordinate.longitude
        let accuracy = location?.horizontalAccuracy
        let timestamp = location?.timestamp
        Task { @MainActor [weak self] in
            guard let self, self.state == .locating else { return }
            if let latitude, let longitude, let accuracy, let timestamp {
                self.resolvedFix = CLLocation(coordinate: .init(latitude: latitude, longitude: longitude),
                                              altitude: 0, horizontalAccuracy: accuracy,
                                              verticalAccuracy: -1, timestamp: timestamp)
                self.finish(at: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            } else {
                self.fail()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor [weak self] in
            self?.fail()
        }
    }
}
