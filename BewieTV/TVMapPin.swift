import SwiftUI

struct TVMapPin: View {
    let track: AlbumTrack
    let pin: PlacedPin
    let player: AlbumPlayer
    let focus: FocusState<TVFocus?>.Binding
    let scale: CGFloat
    let onSelect: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            TVPinButton(id: track.id, scale: scale,
                        selected: player.playingTrackID == track.id,
                        playing: player.playingTrackID == track.id && player.isPlaying,
                        progress: player.playbackProgress,
                        wantsFocus: focus.wrappedValue == .pin(track.id),
                        label: PublicText.trackLabel.formatted(track.id, track.title),
                        value: player.playingTrackID == track.id ? (player.isPlaying ? PublicText.playing.text : PublicText.paused.text) : PublicText.stopped.text,
                        onFocus: { focus.wrappedValue = .pin(track.id) }, onSelect: onSelect)
                .focused(focus, equals: .pin(track.id))
                .frame(width: 48 * scale, height: 48 * scale)
        }
        .frame(width: 48 * scale, height: 48 * scale)
        .background {
            Path { path in
                let centre = CGPoint(x: 24 * scale, y: 24 * scale)
                path.move(to: centre)
                path.addLine(to: CGPoint(x: centre.x + (pin.anchor.x - pin.center.x) * scale,
                                         y: centre.y + (pin.anchor.y - pin.center.y) * scale))
            }
            .stroke(BewiePalette.orange, style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))
            .allowsHitTesting(false)
            if !pin.isOffscreen {
                Circle().fill(BewiePalette.orange).frame(width: 4 * scale, height: 4 * scale)
                    .offset(x: (pin.anchor.x - pin.center.x) * scale, y: (pin.anchor.y - pin.center.y) * scale)
                    .allowsHitTesting(false)
            }
        }
    }
}
