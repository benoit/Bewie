import XCTest
@testable import Bewie

@MainActor
final class BackButtonTests: XCTestCase {
    func testBackRestartsAfterThreeSecondsWithoutNavigationOrChangingPauseState() {
        let player = AlbumPlayer(audioURLProvider: TestAudio.url)
        defer { player.stop() }
        player.select(AlbumTrack.all[1])
        player.pause()
        player.seek(to: 12)
        player.navigateFromSystem(.previous)
        XCTAssertEqual(player.playingTrackID, 2)
        XCTAssertEqual(player.controlTrackID, 2)
        XCTAssertEqual(player.elapsedTime, 0, accuracy: 0.01)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.remoteNavigationCount, 0)
    }

    func testFirstThreeSecondsIncludingBoundaryGoToPreviousTrack() {
        for position in [0.0, 1.5, 3.0] {
            let player = AlbumPlayer(audioURLProvider: TestAudio.url)
            defer { player.stop() }
            player.select(AlbumTrack.all[1])
            player.pause()
            player.seek(to: position)
            player.navigateFromSystem(.previous)
            XCTAssertEqual(player.controlTrackID, 1, "Back at \\(position)s")
            XCTAssertEqual(player.playingTrackID, 1)
            XCTAssertEqual(player.remoteRequestedTrackID, 1)
            XCTAssertEqual(player.remoteNavigationCount, 1)
        }
    }

    func testBackWhilePlayingRestartsAndASecondPressGoesToPrevious() {
        let player = AlbumPlayer(audioURLProvider: TestAudio.url)
        defer { player.stop() }
        player.select(AlbumTrack.all[1])
        player.seek(to: 3.1)
        player.navigateFromSystem(.previous)
        XCTAssertEqual(player.playingTrackID, 2)
        XCTAssertLessThan(player.elapsedTime, 0.2)
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.remoteNavigationCount, 0)
        player.navigateFromSystem(.previous)
        XCTAssertEqual(player.playingTrackID, 1)
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.remoteNavigationCount, 1)
    }

    func testBackFromLoadingTrackDoesNotUseOldAudioTimeOrStopAudiblePreviousTrack() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let player = AlbumPlayer(audioURLProvider: { $0.id == 1 ? file : nil }, audioDownloadProvider: { _ in
            try await Task.sleep(for: .milliseconds(80))
            return file
        })
        defer { player.stop() }
        player.select(AlbumTrack.all[0])
        player.seek(to: 10)
        player.select(AlbumTrack.all[1])
        XCTAssertEqual(player.loadingTrackID, 2)
        player.navigateFromSystem(.previous)
        XCTAssertEqual(player.controlTrackID, 1)
        XCTAssertNil(player.loadingTrackID)
        XCTAssertTrue(player.isPlaying)
        XCTAssertLessThan(player.elapsedTime, 0.2)
        XCTAssertEqual(player.remoteNavigationCount, 1)
        try await Task.sleep(for: .milliseconds(160))
        XCTAssertEqual(player.playingTrackID, 1)
    }
}
