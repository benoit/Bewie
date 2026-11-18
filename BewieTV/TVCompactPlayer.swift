import SwiftUI

struct TVCompactPlayer: View {
    let player: AlbumPlayer
    let focus: FocusState<TVFocus?>.Binding
    let onNavigate: (TrackDirection) -> Void
    let onDismiss: () -> Void

    private var track: AlbumTrack? { AlbumTrack.all.first { $0.id == player.controlTrackID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let track {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(track.id)).foregroundStyle(BewiePalette.orange)
                        .font(.custom("HelveticaNeue-Bold", size: 22))
                    Text(track.title).font(.custom("HelveticaNeue-Medium", size: 22))
                        .lineLimit(2)
                }
                Text(Self.coordinates(track))
                    .font(.custom("PTMono-Regular", fixedSize: 11))
                    .padding(.leading, 27)
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    VStack(spacing: 4) {
                        seekBar
                        HStack {
                            Text(Self.time(player.elapsedTime))
                            Spacer()
                            Text(Self.time(player.duration))
                        }
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(BewiePalette.ink.opacity(0.65))
                    }
                }
                HStack(spacing: 36) {
                    transport("backward.end.fill", label: PublicText.previousTrack.text, target: .previous) { onNavigate(.previous) }
                    transport(player.isControlTrackPlaying ? "pause.fill" : "play.fill",
                              label: player.isControlTrackPlaying ? PublicText.pause.text : PublicText.resume.text,
                              target: .play) { player.togglePlayback() }
                    transport("forward.end.fill", label: PublicText.nextTrack.text, target: .next) { onNavigate(.next) }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .foregroundStyle(BewiePalette.ink)
        .background(BewiePalette.paper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(alignment: .top) {
            Capsule().fill(BewiePalette.ink.opacity(0.25)).frame(width: 32, height: 4).padding(.top, 7)
        }
        .shadow(color: .black.opacity(0.15), radius: 16, y: 4)
        .accessibilityAction(.escape, onDismiss)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tv-compact-player")
    }

    private var seekBar: some View {
        Button { } label: {
            ZStack(alignment: .leading) {
                Capsule().fill(BewiePalette.ink.opacity(0.1)).frame(height: 3)
                GeometryReader { geometry in
                    Capsule().fill(BewiePalette.orange)
                        .frame(width: geometry.size.width * player.playbackProgress, height: 3)
                        .frame(maxHeight: .infinity)
                    Circle().fill(BewiePalette.orange).frame(width: 12, height: 12)
                        .position(x: geometry.size.width * player.playbackProgress, y: geometry.size.height / 2)
                }
                if player.loadingTrackID != nil {
                    MusicLoadingBar(actualProgress: player.downloadProgress ?? 0)
                }
            }
            .frame(height: 24)
            .padding(.vertical, 4)
            .overlay {
                if focus.wrappedValue == .seek { RoundedRectangle(cornerRadius: 8).stroke(BewiePalette.orange.opacity(0.5), lineWidth: 2) }
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused(focus, equals: .seek)
        .onMoveCommand { direction in
            switch direction {
            case .left: player.seek(to: player.elapsedTime - 10)
            case .right: player.seek(to: player.elapsedTime + 10)
            case .down: focus.wrappedValue = .play
            case .up: focus.wrappedValue = .pin(player.controlTrackID ?? 1)
            @unknown default: break
            }
        }
        .accessibilityLabel(PublicText.playbackPosition.text)
        .accessibilityValue(Self.time(player.elapsedTime))
        .accessibilityAdjustableAction { direction in
            if direction == .increment { player.seek(to: player.elapsedTime + 10) }
            else if direction == .decrement { player.seek(to: player.elapsedTime - 10) }
        }
    }

    private func transport(_ symbol: String, label: String, target: TVFocus, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 24))
                .frame(width: 48, height: 44)
                .foregroundStyle(focus.wrappedValue == target ? BewiePalette.orange : BewiePalette.ink)
                .scaleEffect(focus.wrappedValue == target ? 1.12 : 1)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused(focus, equals: target)
        .accessibilityLabel(label)
    }

    static func time(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds.isFinite ? seconds : 0))
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    static func coordinates(_ track: AlbumTrack) -> String {
        String(format: "%.6f° %@  %.6f° %@", locale: Locale(identifier: "en_US_POSIX"),
               abs(track.latitude), track.latitude < 0 ? "S" : "N",
               abs(track.longitude), track.longitude < 0 ? "W" : "E")
    }
}
