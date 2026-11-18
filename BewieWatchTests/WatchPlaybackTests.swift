import AVFoundation
import CoreText
import MediaPlayer
import XCTest
@testable import BewieWatch

@MainActor
final class WatchPlaybackTests: XCTestCase {
    func testHelveticaNeueWeightsResolveOnWatch() {
        for name in ["HelveticaNeue-Bold", "HelveticaNeue-Medium"] {
            let font = CTFontCreateWithName(name as CFString, 12, nil)
            XCTAssertEqual(CTFontCopyPostScriptName(font) as String, name,
                           "The Watch must render Helvetica Neue rather than a fallback font")
        }
    }

    private func defaults(trackID: Int = 1) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "BewieWatchTests.\(UUID().uuidString)")!
        defaults.set(trackID, forKey: "watch.trackID")
        return defaults
    }

    func testEveryBundledSongIsFullLengthStereoAAC() throws {
        let resources = try XCTUnwrap(Bundle.main.resourceURL)
        let contents = try XCTUnwrap(FileManager.default.enumerator(at: resources,
            includingPropertiesForKeys: nil))
        let audioFiles = contents.compactMap { $0 as? URL }.filter { $0.pathExtension == "m4a" }
        XCTAssertEqual(audioFiles.count, AlbumTrack.all.count,
                       "Each song must be bundled exactly once, in the Audio folder")
        let albumBytes = try audioFiles.reduce(0) { total, url in
            total + (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        XCTAssertLessThan(albumBytes, 64_000_000,
                          "Leave room for the executable and assets below watchOS's 75 MB limit")
        for track in AlbumTrack.all {
            let name = (track.filename as NSString).deletingPathExtension
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio"))
            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatMPEG4AAC)
            XCTAssertEqual(file.fileFormat.channelCount, 2)
            XCTAssertEqual(file.fileFormat.sampleRate, 48_000)
            let audio = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(audio.duration, 200)
            XCTAssertTrue(audio.prepareToPlay())
        }
    }

    func testNavigationWrapsAndPersistsTheSelectedSong() {
        let store = defaults()
        let player = WatchAlbumPlayer(defaults: store, activateSession: { _ in })
        player.previous()
        XCTAssertEqual(player.track.id, 9)
        XCTAssertTrue(player.isActivating)
        player.next()
        XCTAssertEqual(player.track.id, 1)
        for _ in 0..<8 { player.next() }
        XCTAssertEqual(player.track.id, 9)
        player.next()
        XCTAssertEqual(player.track.id, 1)
        XCTAssertEqual(store.integer(forKey: "watch.trackID"), 1)
        player.pause()
    }

    func testRepeatedPlayTapsDoNotCancelPendingActivation() async throws {
        var calls = 0
        var completion: (@Sendable (Bool, Error?) -> Void)?
        let player = WatchAlbumPlayer(defaults: defaults(), activateSession: {
            calls += 1
            completion = $0
        })
        for _ in 0..<5 { player.togglePlayback() }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(player.isActivating)
        XCTAssertFalse(player.isPlaying)
        completion?(true, nil)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(player.isPlaying)
        XCTAssertFalse(player.isActivating)
        player.togglePlayback()
        XCTAssertFalse(player.isPlaying)
    }

    func testPauseCancelsPendingActivation() async {
        var completion: (@Sendable (Bool, Error?) -> Void)?
        let player = WatchAlbumPlayer(defaults: defaults(), activateSession: { completion = $0 })
        player.play()
        XCTAssertTrue(player.isActivating)
        player.pause()
        completion?(true, nil)
        await Task.yield()
        XCTAssertFalse(player.isActivating)
        XCTAssertFalse(player.isPlaying)
        XCTAssertNil(player.errorMessage)
    }

    func testOldActivationCannotStartNewSelection() async {
        var completions: [@Sendable (Bool, Error?) -> Void] = []
        let player = WatchAlbumPlayer(defaults: defaults(), activateSession: { completions.append($0) })
        player.play()
        player.next()
        XCTAssertEqual(completions.count, 2)
        completions[0](true, nil)
        await Task.yield()
        XCTAssertEqual(player.track.id, 2)
        XCTAssertFalse(player.isPlaying)
        XCTAssertTrue(player.isActivating)
        player.pause()
    }

    func testActivationErrorIsRecoverable() async {
        let player = WatchAlbumPlayer(defaults: defaults(), activateSession: { _ in
            throw CocoaError(.fileReadNoPermission)
        })
        player.play()
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isActivating)
        XCTAssertNotNil(player.errorMessage)
        player.errorMessage = nil
        player.play()
        XCTAssertNotNil(player.errorMessage)
    }

    func testPlaybackPauseResumeAndThreeSecondBackRule() async throws {
        let player = WatchAlbumPlayer(defaults: defaults(), activateSession: { completion in
            completion(true, nil)
        })
        player.togglePlayback()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(player.isPlaying)
        XCTAssertNil(player.errorMessage)
        try await Task.sleep(for: .milliseconds(3_200))
        player.pause()
        let elapsed = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double
        XCTAssertGreaterThan(try XCTUnwrap(elapsed), 3)
        player.previous()
        XCTAssertEqual(player.track.id, 1)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 0)
        XCTAssertFalse(player.isPlaying)
        player.togglePlayback()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(player.isPlaying)
        player.pause()
    }

    func testLostAudioOutputPausesPlayback() async throws {
        let player = WatchAlbumPlayer(defaults: defaults(), activateSession: { $0(true, nil) })
        player.play()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(player.isPlaying)
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isActivating)
    }

    func testInvalidSavedSelectionFallsBackToFirstTrackWithoutAutoplay() {
        let player = WatchAlbumPlayer(defaults: defaults(trackID: 100), activateSession: { _ in
            XCTFail("Opening the app must not activate audio")
        })
        XCTAssertEqual(player.track.id, 1)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isActivating)
    }
}
