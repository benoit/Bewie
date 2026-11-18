import XCTest
@testable import Bewie

final class DownloadBarProgressTests: XCTestCase {
    func testQuietDownloadStillAdvancesVisually() {
        var bar = DownloadBarProgress()
        let initial = bar.value
        for _ in 0..<60 { bar.advance(actual: 0, elapsed: 0.5) }
        XCTAssertGreaterThan(bar.value, initial)
        XCTAssertLessThan(bar.value, 1)
    }

    func testRealProgressMovesForwardAndNeverPullsTheBarBack() {
        var bar = DownloadBarProgress()
        bar.advance(actual: 0.7, elapsed: 0)
        XCTAssertGreaterThanOrEqual(bar.value, 0.7)
        let previous = bar.value
        bar.advance(actual: 0.1, elapsed: 0.5)
        XCTAssertGreaterThanOrEqual(bar.value, previous)
    }

    func testEstimatedProgressNeverFillsTheBar() {
        var bar = DownloadBarProgress()
        bar.advance(actual: 1, elapsed: 1_000_000)
        XCTAssertLessThan(bar.value, 1)
    }
}
