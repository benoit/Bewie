import CoreLocation
import XCTest
@testable import Bewie

final class MapStartLocationTests: XCTestCase {
    @MainActor
    func testFirstLaunchPromptsOnceAndAuthorizationRequestsOnlyOneFix() async {
        let manager = FakeMapLocationManager(status: .notDetermined)
        let location = MapStartLocation(manager: manager)
        defer { location.cancel() }

        location.start()
        location.start()
        XCTAssertEqual(manager.permissionRequests, 1)
        XCTAssertEqual(manager.locationRequests, 0)
        XCTAssertFalse(location.isResolved)

        manager.sendAuthorization(.notDetermined)
        await drainCallbacks()
        XCTAssertEqual(manager.permissionRequests, 1)

        manager.sendAuthorization(.authorizedWhenInUse)
        await waitUntil { manager.locationRequests == 1 }
        manager.sendAuthorization(.authorizedWhenInUse)
        manager.sendAuthorization(.authorizedWhenInUse)
        location.start()
        await drainCallbacks()
        XCTAssertEqual(manager.permissionRequests, 1)
        XCTAssertEqual(manager.locationRequests, 1)
        XCTAssertFalse(location.isResolved)

        manager.sendLocations([fix(latitude: 51.5, longitude: -0.12, accuracy: 5_000)])
        await waitUntil { location.isResolved }
        assertCoordinate(location.coordinate, latitude: 51.5, longitude: -0.12)
        XCTAssertEqual(manager.stopRequests, 1)
        XCTAssertNil(manager.delegate)
    }

    @MainActor
    func testDeniedAndRestrictedAuthorizationUseNotreDameWithoutRequestingAFix() {
        // Core Location reports .denied when Location Services are disabled
        // globally as well as when permission for this app is denied.
        for status in [CLAuthorizationStatus.denied, .restricted] {
            let manager = FakeMapLocationManager(status: status)
            let location = MapStartLocation(manager: manager)

            location.start()
            location.start()

            XCTAssertTrue(location.isResolved)
            assertFallback(location.coordinate)
            XCTAssertEqual(manager.permissionRequests, 0)
            XCTAssertEqual(manager.locationRequests, 0)
            XCTAssertEqual(manager.stopRequests, 1)
            XCTAssertNil(manager.delegate)
        }
    }

    @MainActor
    func testExistingPermissionAcceptsApproximateLocationWithoutAnotherPrompt() async {
        for status in [CLAuthorizationStatus.authorizedWhenInUse, .authorizedAlways] {
            let manager = FakeMapLocationManager(status: status)
            let location = MapStartLocation(manager: manager)

            location.start()
            XCTAssertEqual(manager.permissionRequests, 0)
            XCTAssertEqual(manager.locationRequests, 1)
            manager.sendLocations([fix(latitude: -33.8688, longitude: 151.2093, accuracy: 10_000)])

            await waitUntil { location.isResolved }
            assertCoordinate(location.coordinate, latitude: -33.8688, longitude: 151.2093)
            XCTAssertEqual(manager.stopRequests, 1)
        }
    }

    @MainActor
    func testPermissionDeniedAfterThePromptResolvesToNotreDame() async {
        let manager = FakeMapLocationManager(status: .notDetermined)
        let location = MapStartLocation(manager: manager)
        location.start()

        manager.sendAuthorization(.denied)

        await waitUntil { location.isResolved }
        assertFallback(location.coordinate)
        XCTAssertEqual(manager.permissionRequests, 1)
        XCTAssertEqual(manager.locationRequests, 0)
        XCTAssertEqual(manager.stopRequests, 1)
    }

    @MainActor
    func testFailedLocationRequestResolvesToNotreDameAndStops() async {
        let manager = FakeMapLocationManager(status: .authorizedWhenInUse)
        let location = MapStartLocation(manager: manager)
        location.start()

        manager.sendFailure()

        await waitUntil { location.isResolved }
        assertFallback(location.coordinate)
        XCTAssertEqual(manager.locationRequests, 1)
        XCTAssertEqual(manager.stopRequests, 1)
        XCTAssertNil(manager.delegate)
    }

    @MainActor
    func testEmptyInvalidAndStaleLocationResultsUseNotreDame() async {
        let results: [[CLLocation]] = [
            [],
            [fix(latitude: 51.5, longitude: -0.12, accuracy: -1)],
            [fix(latitude: 51.5, longitude: -0.12, timestamp: Date(timeIntervalSinceNow: -600))],
            [fix(latitude: 51.5, longitude: -0.12, timestamp: Date(timeIntervalSinceNow: 600))]
        ]

        for result in results {
            let manager = FakeMapLocationManager(status: .authorizedWhenInUse)
            let location = MapStartLocation(manager: manager)
            location.start()
            manager.sendLocations(result)

            await waitUntil { location.isResolved }
            assertFallback(location.coordinate)
            XCTAssertEqual(manager.stopRequests, 1)
        }
    }

    @MainActor
    func testLocationTimeoutUsesNotreDameAndCancelsThePendingRequest() async {
        let manager = FakeMapLocationManager(status: .authorizedWhenInUse)
        let location = MapStartLocation(manager: manager, timeout: .milliseconds(10))
        location.start()

        await waitUntil { location.isResolved }

        assertFallback(location.coordinate)
        XCTAssertEqual(manager.locationRequests, 1)
        XCTAssertEqual(manager.stopRequests, 1)
        XCTAssertNil(manager.delegate)
    }

    @MainActor
    func testManualNavigationBeforeAuthorizationPreventsALateFixOrRecenter() async {
        let manager = FakeMapLocationManager(status: .notDetermined)
        let location = MapStartLocation(manager: manager)
        location.start()
        let queuedDelegate = manager.delegate

        location.cancel()
        location.start()
        manager.sendAuthorization(.authorizedWhenInUse, to: queuedDelegate)
        manager.sendLocations([fix(latitude: 51.5, longitude: -0.12)], to: queuedDelegate)
        manager.sendFailure(to: queuedDelegate)
        await drainCallbacks()

        XCTAssertFalse(location.isResolved, "Cancelling must not trigger the view's recenter observer.")
        assertFallback(location.coordinate)
        XCTAssertEqual(manager.permissionRequests, 1)
        XCTAssertEqual(manager.locationRequests, 0)
        XCTAssertEqual(manager.stopRequests, 1)
        XCTAssertNil(manager.delegate)
    }

    @MainActor
    func testManualNavigationDuringAFixIgnoresLateResultsAndCancelsTimeout() async throws {
        let manager = FakeMapLocationManager(status: .authorizedWhenInUse)
        let location = MapStartLocation(manager: manager, timeout: .milliseconds(10))
        location.start()
        let queuedDelegate = manager.delegate

        location.cancel()
        manager.sendLocations([fix(latitude: 51.5, longitude: -0.12)], to: queuedDelegate)
        manager.sendFailure(to: queuedDelegate)
        manager.sendAuthorization(.authorizedWhenInUse, to: queuedDelegate)
        location.start()
        // Outlive the requested timeout: neither its task nor queued delegate
        // callbacks may turn a cancelled request into a resolved camera change.
        try await Task.sleep(for: .milliseconds(30))

        XCTAssertFalse(location.isResolved)
        assertFallback(location.coordinate)
        XCTAssertEqual(manager.locationRequests, 1)
        XCTAssertEqual(manager.stopRequests, 1)
        XCTAssertNil(manager.delegate)
    }

    @MainActor
    func testCompletedRequestIgnoresDuplicateAndLateDelegateCallbacks() async {
        let manager = FakeMapLocationManager(status: .authorizedWhenInUse)
        let location = MapStartLocation(manager: manager)
        location.start()
        let queuedDelegate = manager.delegate
        manager.sendLocations([fix(latitude: 51.5, longitude: -0.12)])
        await waitUntil { location.isResolved }

        manager.sendLocations([fix(latitude: -33.8688, longitude: 151.2093)], to: queuedDelegate)
        manager.sendFailure(to: queuedDelegate)
        manager.sendAuthorization(.denied, to: queuedDelegate)
        location.start()
        location.cancel()
        await drainCallbacks()

        XCTAssertTrue(location.isResolved)
        assertCoordinate(location.coordinate, latitude: 51.5, longitude: -0.12)
        XCTAssertEqual(manager.locationRequests, 1)
        XCTAssertEqual(manager.stopRequests, 1)
    }

    @MainActor
    func testCancellationBeforeStartPreventsPermissionAndLocationRequests() {
        let manager = FakeMapLocationManager(status: .notDetermined)
        let location = MapStartLocation(manager: manager)

        location.cancel()
        location.start()

        XCTAssertFalse(location.isResolved)
        XCTAssertEqual(manager.permissionRequests, 0)
        XCTAssertEqual(manager.locationRequests, 0)
        XCTAssertNil(manager.delegate)
    }

    @MainActor
    func testForegroundRefreshDoesNotPromptWithoutAuthorization() {
        for status in [CLAuthorizationStatus.notDetermined, .denied, .restricted] {
            let manager = FakeMapLocationManager(status: status)
            let location = MapStartLocation(manager: manager, fallbackOnFailure: false)
            XCTAssertFalse(location.startIfAuthorized())
            XCTAssertEqual(manager.permissionRequests, 0)
            XCTAssertEqual(manager.locationRequests, 0)
            XCTAssertFalse(location.isResolved)
            location.cancel()
        }
    }

    @MainActor
    func testForegroundRefreshResolvesWithExistingPermission() async {
        for status in [CLAuthorizationStatus.authorizedWhenInUse, .authorizedAlways] {
            let manager = FakeMapLocationManager(status: status)
            let location = MapStartLocation(manager: manager, fallbackOnFailure: false)
            XCTAssertTrue(location.startIfAuthorized())
            XCTAssertFalse(location.startIfAuthorized())
            manager.sendLocations([fix(latitude: 43.5, longitude: 11.2)])
            await waitUntil { location.isResolved }
            assertCoordinate(location.coordinate, latitude: 43.5, longitude: 11.2)
            XCTAssertEqual(manager.permissionRequests, 0)
            XCTAssertEqual(manager.locationRequests, 1)
        }
    }

    @MainActor
    func testForegroundFailureAndTimeoutNeverResolveToFallback() async throws {
        for failure in 0..<4 {
            let manager = FakeMapLocationManager(status: .authorizedWhenInUse)
            let location = MapStartLocation(manager: manager, timeout: .milliseconds(10), fallbackOnFailure: false)
            XCTAssertTrue(location.startIfAuthorized())
            switch failure {
            case 0: manager.sendFailure()
            case 1: manager.sendLocations([])
            case 2: manager.sendAuthorization(.denied)
            default: break
            }
            await waitUntil { manager.stopRequests == 1 }
            XCTAssertFalse(location.isResolved)
            XCTAssertNil(manager.delegate)
            XCTAssertEqual(manager.stopRequests, 1)
        }
    }

    private func fix(latitude: Double, longitude: Double, accuracy: Double = 100,
                     timestamp: Date = Date()) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                   altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
                   timestamp: timestamp)
    }

    private func assertFallback(_ coordinate: CLLocationCoordinate2D,
                                file: StaticString = #filePath, line: UInt = #line) {
        assertCoordinate(coordinate, latitude: 48.8530, longitude: 2.3499, file: file, line: line)
    }

    private func assertCoordinate(_ coordinate: CLLocationCoordinate2D,
                                  latitude: Double, longitude: Double,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(coordinate.latitude, latitude, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(coordinate.longitude, longitude, accuracy: 0.000001, file: file, line: line)
    }

    @MainActor
    private func waitUntil(_ condition: @MainActor () -> Bool,
                           file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now + .seconds(1)
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(condition(), "The opening location did not resolve as expected.", file: file, line: line)
    }

    @MainActor
    private func drainCallbacks() async {
        for _ in 0..<10 { await Task.yield() }
    }
}

@MainActor
private final class FakeMapLocationManager: MapLocationManaging {
    weak var delegate: (any CLLocationManagerDelegate)?
    var authorizationStatus: CLAuthorizationStatus
    var desiredAccuracy: CLLocationAccuracy = 0
    private(set) var permissionRequests = 0
    private(set) var locationRequests = 0
    private(set) var stopRequests = 0

    // The delegate signature requires a concrete CLLocationManager. This object
    // never requests permission or location; the service reads the fake's state.
    private let callbackManager = CLLocationManager()

    init(status: CLAuthorizationStatus) {
        authorizationStatus = status
    }

    func requestWhenInUseAuthorization() { permissionRequests += 1 }
    func requestLocation() { locationRequests += 1 }
    func stopUpdatingLocation() { stopRequests += 1 }

    func sendAuthorization(_ status: CLAuthorizationStatus,
                           to queuedDelegate: (any CLLocationManagerDelegate)? = nil) {
        authorizationStatus = status
        (queuedDelegate ?? delegate)?.locationManagerDidChangeAuthorization?(callbackManager)
    }

    func sendLocations(_ locations: [CLLocation],
                       to queuedDelegate: (any CLLocationManagerDelegate)? = nil) {
        (queuedDelegate ?? delegate)?.locationManager?(callbackManager, didUpdateLocations: locations)
    }

    func sendFailure(to queuedDelegate: (any CLLocationManagerDelegate)? = nil) {
        let error = NSError(domain: kCLErrorDomain, code: CLError.Code.locationUnknown.rawValue)
        (queuedDelegate ?? delegate)?.locationManager?(callbackManager, didFailWithError: error)
    }
}
