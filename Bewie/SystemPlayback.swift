import MediaPlayer
import UIKit
import SwiftUI

/// One owner registers remote commands, avoiding duplicate handlers on view updates.
@MainActor
final class SystemPlayback {
    private weak var player: AlbumPlayer?
    private var handlers: [(MPRemoteCommand, Any)] = []

    init(player: AlbumPlayer) {
        self.player = player
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commands = MPRemoteCommandCenter.shared()
        register(commands.playCommand) { player in
            if !player.isPlaying { player.togglePlayback() }
        }
        register(commands.pauseCommand) { $0.pause() }
        register(commands.togglePlayPauseCommand) { $0.togglePlayback() }
        register(commands.stopCommand) { $0.stop() }
        register(commands.nextTrackCommand) { $0.navigateFromSystem(.next) }
        register(commands.previousTrackCommand) { $0.navigateFromSystem(.previous) }
        let token = commands.changePlaybackPositionCommand.addTarget { [weak player] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor [weak player] in player?.seek(to: position) }
            return .success
        }
        handlers.append((commands.changePlaybackPositionCommand, token))
        update()
    }

    private func register(_ command: MPRemoteCommand, action: @escaping @MainActor (AlbumPlayer) -> Void) {
        let token = command.addTarget { [weak player] _ in
            guard let player else { return .noSuchContent }
            Task { @MainActor in action(player) }
            return .success
        }
        handlers.append((command, token))
    }

    func update() {
        guard let player else { return }
        let commands = MPRemoteCommandCenter.shared()
        let selected = player.playingTrackID != nil
        commands.playCommand.isEnabled = selected && !player.isPlaying
        commands.pauseCommand.isEnabled = selected && player.isPlaying
        commands.togglePlayPauseCommand.isEnabled = selected
        commands.stopCommand.isEnabled = selected
        commands.nextTrackCommand.isEnabled = selected
        commands.previousTrackCommand.isEnabled = selected
        commands.changePlaybackPositionCommand.isEnabled = selected && player.duration > 0
        guard let track = AlbumTrack.all.first(where: { $0.id == player.playingTrackID }) else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyAlbumTitle: "Every Room Is Borrowed",
            MPMediaItemPropertyAlbumTrackNumber: track.id,
            MPMediaItemPropertyAlbumTrackCount: AlbumTrack.all.count,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false
        ]
        if let image = Self.artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Give the pearl a 14% margin on each side of the system artwork tile.
    private static let artworkImage: UIImage? = {
        guard let pearl = UIImage(named: "PearlPin") else { return nil }
        let size = CGSize(width: 600, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(BewiePalette.paper).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let scale = min(432 / pearl.size.width, 432 / pearl.size.height)
            let drawingSize = CGSize(width: pearl.size.width * scale, height: pearl.size.height * scale)
            pearl.draw(in: CGRect(x: (size.width - drawingSize.width) / 2,
                                  y: (size.height - drawingSize.height) / 2,
                                  width: drawingSize.width, height: drawingSize.height))
        }
    }()

    deinit {
        for (command, token) in handlers { command.removeTarget(token) }
    }
}
