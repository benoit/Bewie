import AVFoundation
import XCTest
@testable import Bewie

final class ContinuousPlaybackTests: XCTestCase {
    @MainActor
    func testRealAudioCompletionPlaysTwoAlbumLoopsInOrder() async throws {
        let url = try shortAudio()
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AlbumPlayer(audioURLProvider: { _ in url })
        defer { player.pause() }
        player.select(AlbumTrack.all[0])
        var heard = [try XCTUnwrap(player.playingTrackID)]
        let deadline = Date().addingTimeInterval(15)
        while heard.count < 19, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
            if let id = player.playingTrackID, heard.last != id { heard.append(id) }
        }
        XCTAssertEqual(heard, Array(1...9) + Array(1...9) + [1])
        XCTAssertEqual(player.automaticAdvanceCount, 18)
        XCTAssertTrue(player.isPlaying)
        XCTAssertNil(player.errorMessage)
    }

    @MainActor
    func testPauseStopsAutomaticAdvancementAndResumeContinues() async throws {
        let url = try shortAudio()
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AlbumPlayer(audioURLProvider: { _ in url })
        defer { player.pause() }
        player.select(AlbumTrack.all[8])
        player.pause()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(player.playingTrackID, 9)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.automaticAdvanceCount, 0)

        player.select(AlbumTrack.all[8])
        let deadline = Date().addingTimeInterval(3)
        while player.automaticAdvanceCount == 0, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(player.playingTrackID, 1)
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.automaticAdvanceCount, 1)
    }

    @MainActor
    func testUnavailableNextTrackReportsFailureWithoutAnEndlessRetryLoop() async throws {
        let url = try shortAudio()
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AlbumPlayer(audioURLProvider: { $0.id == 1 ? url : nil })
        defer { player.pause() }
        player.select(AlbumTrack.all[0])
        let deadline = Date().addingTimeInterval(3)
        while player.isPlaying, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.failedTrackID, 2)
        XCTAssertNotNil(player.errorMessage)
        XCTAssertEqual(player.automaticAdvanceCount, 0)
    }

    @MainActor
    func testDirectTrackSelectionToggleStopsAutomaticAdvance() async throws {
        let url = try shortAudio()
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AlbumPlayer(audioURLProvider: { _ in url })
        defer { player.stop() }
        player.select(AlbumTrack.all[8])
        XCTAssertTrue(player.isPlaying)
        player.select(AlbumTrack.all[8])
        XCTAssertNil(player.playingTrackID)
        XCTAssertFalse(player.isPlaying)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(player.automaticAdvanceCount, 0)
        XCTAssertNil(player.playingTrackID)
        player.select(AlbumTrack.all[8])
        XCTAssertEqual(player.playingTrackID, 9)
        XCTAssertTrue(player.isPlaying)
    }

    @MainActor
    func testPanelPauseResumeAndSeekKeepCurrentTrackSelected() throws {
        let player = AlbumPlayer(audioURLProvider: TestAudio.url)
        defer { player.stop() }
        player.select(AlbumTrack.all[8])
        player.togglePlayback()
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.playingTrackID, 9)
        XCTAssertGreaterThan(player.duration, 10)
        player.seek(to: 5)
        XCTAssertEqual(player.elapsedTime, 5, accuracy: 0.1)
        XCTAssertEqual(player.playbackProgress, 5 / player.duration, accuracy: 0.001)
        player.seek(to: -100)
        XCTAssertEqual(player.elapsedTime, 0, accuracy: 0.1)
        XCTAssertEqual(player.playbackProgress, 0, accuracy: 0.001)
        player.seek(to: player.duration * 0.75)
        XCTAssertEqual(player.playbackProgress, 0.75, accuracy: 0.001)
        player.togglePlayback()
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.playingTrackID, 9)
    }

    private func shortAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 960))
        buffer.frameLength = 960
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<960 { channel[frame] = 0 }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
