import XCTest
@testable import Bewie

final class TrackArrivalPlayerTests: XCTestCase {
    func testPlayingPinOpensImmediatelyAndNeverReopensAtArrivalAfterDismissal() {
        var presentation = TrackArrivalPlayer()
        for id in 1...9 {
            presentation.begin(id == 9 ? 1 : id + 1)
            XCTAssertTrue(presentation.begin(id, showImmediately: true))
            XCTAssertFalse(presentation.takePresentation(playingID: id, failedID: nil))
            presentation.arrive(id)
            XCTAssertFalse(presentation.takePresentation(playingID: id, failedID: nil))
        }
    }

    func testPlayingTrackDoesNotOpenUntilArrivalAndOnlyOpensOnce() {
        var presentation = TrackArrivalPlayer()
        presentation.begin(2)
        XCTAssertFalse(presentation.takePresentation(playingID: 2, failedID: nil))
        presentation.arrive(2)
        XCTAssertTrue(presentation.takePresentation(playingID: 2, failedID: nil))
        XCTAssertFalse(presentation.takePresentation(playingID: 2, failedID: nil))
    }

    func testLateDownloadWaitsForTheArrivedTrackInsteadOfOpeningOldTrack() {
        var presentation = TrackArrivalPlayer()
        presentation.begin(2)
        presentation.arrive(2)
        XCTAssertFalse(presentation.takePresentation(playingID: 1, failedID: nil))
        XCTAssertTrue(presentation.takePresentation(playingID: 2, failedID: nil))
    }

    func testPendingDownloadOpensItsPlayerAtArrivalWithoutWaitingForAudio() {
        var presentation = TrackArrivalPlayer()
        presentation.begin(2)
        XCTAssertFalse(presentation.takePresentation(playingID: 1, failedID: nil, loadingID: 2))
        presentation.arrive(2)
        XCTAssertTrue(presentation.takePresentation(playingID: 1, failedID: nil, loadingID: 2))
        XCTAssertFalse(presentation.takePresentation(playingID: 2, failedID: nil))
    }

    func testOldDownloadingTrackCannotOpenAfterNavigationToAnotherTrack() {
        var presentation = TrackArrivalPlayer()
        presentation.begin(2)
        presentation.begin(3)
        presentation.arrive(2)
        XCTAssertFalse(presentation.takePresentation(playingID: 1, failedID: nil, loadingID: 3))
        presentation.arrive(3)
        XCTAssertTrue(presentation.takePresentation(playingID: 1, failedID: nil, loadingID: 3))
    }

    func testRapidNavigationIgnoresOldFlightAndOpensOnlyLatestArrival() {
        var presentation = TrackArrivalPlayer()
        presentation.begin(1)
        presentation.begin(9)
        presentation.arrive(1)
        XCTAssertFalse(presentation.takePresentation(playingID: 9, failedID: nil))
        presentation.arrive(9)
        XCTAssertFalse(presentation.takePresentation(playingID: 1, failedID: nil))
        XCTAssertTrue(presentation.takePresentation(playingID: 9, failedID: nil))
    }

    func testUserCancellationPreventsPendingPlayerFromReappearing() {
        for alreadyArrived in [false, true] {
            var presentation = TrackArrivalPlayer()
            presentation.begin(3)
            if alreadyArrived { presentation.arrive(3) }
            presentation.cancel()
            presentation.arrive(3)
            XCTAssertFalse(presentation.takePresentation(playingID: 3, failedID: nil))
        }
    }

    func testFailedArrivalNeverShowsOldOrLaterRetriedTrackWithoutANewFlight() {
        var presentation = TrackArrivalPlayer()
        presentation.begin(4)
        presentation.arrive(4)
        XCTAssertFalse(presentation.takePresentation(playingID: 1, failedID: 4))
        XCTAssertFalse(presentation.takePresentation(playingID: 4, failedID: nil))
        presentation.begin(4)
        presentation.arrive(4)
        XCTAssertTrue(presentation.takePresentation(playingID: 4, failedID: nil))
    }
}
