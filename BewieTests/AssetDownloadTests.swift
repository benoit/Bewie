import XCTest
@testable import Bewie

@MainActor
final class AssetDownloadTests: XCTestCase {
    func testReturningToAudibleTrackCancelsPendingSelectionWithoutStoppingMusic() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let player = AlbumPlayer(audioURLProvider: { $0.id == 1 ? file : nil }, audioDownloadProvider: { _ in
            try await Task.sleep(for: .milliseconds(60))
            return file
        })
        defer { player.stop() }
        player.select(AlbumTrack.all[0])
        player.select(AlbumTrack.all[1])
        XCTAssertEqual(player.controlTrackID, 2)
        player.focusPlayingTrack()
        XCTAssertEqual(player.controlTrackID, 1)
        XCTAssertNil(player.loadingTrackID)
        XCTAssertTrue(player.isPlaying)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(player.playingTrackID, 1)
        XCTAssertEqual(player.controlTrackID, 1)
    }

    func testLateDownloadCannotReplaceMoreRecentSelection() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let player = AlbumPlayer(audioURLProvider: { _ in nil }, audioDownloadProvider: { track in
            try await Task.sleep(for: .milliseconds(track.id == 1 ? 250 : 10))
            return file
        })
        defer { player.stop() }
        player.select(AlbumTrack.all[0])
        player.select(AlbumTrack.all[1])
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(player.playingTrackID, 2)
        XCTAssertTrue(player.isPlaying)
        XCTAssertNil(player.loadingTrackID)
    }

    func testStopCancelsPendingPlayback() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let player = AlbumPlayer(audioURLProvider: { _ in nil }, audioDownloadProvider: { _ in
            try await Task.sleep(for: .milliseconds(50))
            return file
        })
        player.select(AlbumTrack.all[0])
        XCTAssertEqual(player.loadingTrackID, 1)
        player.stop()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(player.playingTrackID)
        XCTAssertNil(player.loadingTrackID)
        XCTAssertFalse(player.isPlaying)
    }

    func testCompletionDownloadsMissingNextTrackAndAdvancesOnce() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let player = AlbumPlayer(audioURLProvider: { $0.id == 1 ? file : nil }, audioDownloadProvider: { _ in
            try await Task.sleep(for: .milliseconds(50))
            return file
        })
        defer { player.stop() }
        player.select(AlbumTrack.all[0])
        player.seek(to: player.duration - 0.08)
        let deadline = Date().addingTimeInterval(4)
        while player.playingTrackID != 2, Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(player.playingTrackID, 2)
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.automaticAdvanceCount, 1)
    }

    func testPauseCancelsPendingTrackChange() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let player = AlbumPlayer(audioURLProvider: { $0.id == 1 ? file : nil }, audioDownloadProvider: { _ in
            try await Task.sleep(for: .milliseconds(100))
            return file
        })
        defer { player.stop() }
        player.select(AlbumTrack.all[0])
        player.select(AlbumTrack.all[1])
        player.pause()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(player.playingTrackID, 1)
        XCTAssertNil(player.loadingTrackID)
        XCTAssertFalse(player.isPlaying)
    }

    func testDownloadFailureCanBeRetried() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        var fails = true
        let player = AlbumPlayer(audioURLProvider: { _ in nil }, audioDownloadProvider: { _ in
            if fails { throw URLError(.notConnectedToInternet) }
            return file
        })
        defer { player.stop() }
        player.select(AlbumTrack.all[0])
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(player.failedTrackID, 1)
        XCTAssertNotNil(player.errorMessage)
        player.dismissError()
        XCTAssertEqual(player.failedTrackID, 1)
        fails = false
        player.select(AlbumTrack.all[0])
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(player.isPlaying)
        XCTAssertNil(player.errorMessage)
    }
}
