import AVFoundation
import XCTest
@testable import Bewie

@MainActor
final class DirectPackPlaybackTests: XCTestCase {
    private enum Failure: Error { case unexpectedDownload, deadline }

    private func eventually(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw Failure.deadline }
            try await Task.sleep(for: .milliseconds(15))
        }
    }

    private func mappedAlbum() throws -> [Int: Data] {
        try Dictionary(uniqueKeysWithValues: AlbumTrack.all.map { track in
            let url = try XCTUnwrap(TestAudio.url(track))
            return (track.id, try Data(contentsOf: url, options: .alwaysMapped))
        })
    }

    func testAllNineLosslessMastersDecodeFromMappedData() throws {
        for track in AlbumTrack.all {
            let url = try XCTUnwrap(TestAudio.url(track))
            let data = try Data(contentsOf: url, options: .alwaysMapped)
            let original = try AVAudioPlayer(contentsOf: url)
            let mapped = try AVAudioPlayer(data: data)
            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatAppleLossless)
            XCTAssertEqual(mapped.duration, original.duration, accuracy: 0.001)
            XCTAssertEqual(mapped.numberOfChannels, original.numberOfChannels)
            XCTAssertTrue(mapped.prepareToPlay(), track.title)
        }
    }

    func testMappedAlbumPlaysPausesSeeksAndLoopsThroughAllNineTracks() async throws {
        let data = try mappedAlbum()
        let client = MusicAssetClient(localAsset: { data[$0.id].map(MusicAudioAsset.data) },
                                      download: { _, _, _ in throw Failure.unexpectedDownload })
        let library = MusicLibrary(client: client)
        let player = AlbumPlayer(library: library)
        defer { player.stop(); library.cancel() }
        player.prefetchMusic()
        try await eventually { library.isComplete }
        player.select(AlbumTrack.all[0])
        XCTAssertTrue(player.isPlaying)
        player.pause()
        XCTAssertFalse(player.isPlaying)
        player.seek(to: 12)
        XCTAssertEqual(player.elapsedTime, 12, accuracy: 0.1)
        player.select(AlbumTrack.all[0])
        XCTAssertTrue(player.isPlaying)
        for track in AlbumTrack.all {
            XCTAssertEqual(player.playingTrackID, track.id)
            player.seek(to: player.duration - 0.1)
            let next = track.id == 9 ? 1 : track.id + 1
            try await eventually { player.playingTrackID == next }
            XCTAssertTrue(player.isPlaying)
            XCTAssertNil(player.errorMessage)
        }
        XCTAssertEqual(player.automaticAdvanceCount, 9)
    }

    func testPendingMappedTrackStartsWhenItsDownloadCompletes() async throws {
        let url = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        let client = MusicAssetClient(localAsset: { $0.id == 1 ? nil : .data(data) }, download: { _, progress, snapshot in
            await progress(1)
            await snapshot(.init(stage: .openingFile))
            try await Task.sleep(for: .milliseconds(40))
            return .data(data)
        })
        let library = MusicLibrary(client: client)
        let player = AlbumPlayer(library: library)
        defer { player.stop(); library.cancel() }
        player.select(AlbumTrack.all[0])
        XCTAssertEqual(player.loadingTrackID, 1)
        try await eventually { player.isPlaying }
        XCTAssertEqual(player.playingTrackID, 1)
        XCTAssertNil(player.loadingTrackID)
        XCTAssertNil(player.errorMessage)
        XCTAssertTrue(library.isComplete)
    }

    func testRetryClassificationKeepsPermissionErrorsPermanent() {
        let permission = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError,
                                 userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: 1)])
        XCTAssertFalse(MusicAssetFailure(permission).isRecoverable)
        let interrupted = NSError(domain: "AssetService", code: 0,
                                  userInfo: [NSUnderlyingErrorKey: NSError(domain: "XPC.XPCRichError", code: 1)])
        XCTAssertTrue(MusicAssetFailure(interrupted).isRecoverable)
    }
}
