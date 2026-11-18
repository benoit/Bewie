import XCTest
@testable import BewieWatch

@MainActor
final class WatchVolumeIndicatorTests: XCTestCase {
    func testVisibilityStartsHiddenAndExtendsUntilTwoSecondsAfterLatestChange() async throws {
        let indicator = WatchVolumeIndicatorVisibility()
        var changes = [Bool]()
        indicator.onChange = { changes.append($0) }
        XCTAssertFalse(indicator.isVisible)
        indicator.volumeDidChange()
        XCTAssertTrue(indicator.isVisible)
        try await Task.sleep(for: .milliseconds(1200))
        indicator.volumeDidChange()
        // The first deadline must not hide the indicator after another adjustment.
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertTrue(indicator.isVisible)
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertFalse(indicator.isVisible)
        XCTAssertEqual(changes, [true, false])
    }

    func testResetHidesAndAllowsNextAdjustment() {
        let indicator = WatchVolumeIndicatorVisibility()
        indicator.volumeDidChange()
        indicator.reset()
        XCTAssertFalse(indicator.isVisible)
        indicator.volumeDidChange()
        XCTAssertTrue(indicator.isVisible)
        indicator.reset()
    }
}
