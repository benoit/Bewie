import MediaPlayer
import XCTest
@testable import Bewie

@MainActor
final class SystemPlaybackTests: XCTestCase {
    func testSystemMetadataTracksTitlePositionPauseAndStop() throws {
        let player = AlbumPlayer(audioURLProvider: TestAudio.url)
        let system = SystemPlayback(player: player)
        defer { player.stop(); system.update() }
        player.select(AlbumTrack.all[8])
        system.update()
        let center = MPNowPlayingInfoCenter.default()
        XCTAssertEqual(center.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "I Stayed")
        XCTAssertEqual(center.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1)
        if let artwork = center.nowPlayingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork,
           let image = artwork.image(at: CGSize(width: 600, height: 600)) {
            let attachment = XCTAttachment(image: image)
            attachment.name = "Inset pearl system artwork"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        player.pause()
        player.seek(to: 20)
        system.update()
        XCTAssertEqual(center.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? -1, 20, accuracy: 0.1)
        XCTAssertEqual(center.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 0)
        XCTAssertTrue(MPRemoteCommandCenter.shared().playCommand.isEnabled)
        XCTAssertFalse(MPRemoteCommandCenter.shared().pauseCommand.isEnabled)
        player.stop()
        system.update()
        XCTAssertNil(center.nowPlayingInfo)
        XCTAssertFalse(MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled)
    }
}
