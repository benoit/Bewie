import SwiftUI

/// Transport controls share the existing player; presentation never sets a map camera.
struct CompactPlayerView: View {
    let player: AlbumPlayer
    let onNavigate: (TrackDirection) -> Void
    @State private var scrubTime: Double?

    private var track: AlbumTrack? {
        AlbumTrack.all.first { $0.id == player.controlTrackID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let track {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(track.id))
                                .foregroundStyle(BewiePalette.orange)
                                .font(.custom("HelveticaNeue-Bold", size: 22, relativeTo: .title2))
                            Text(track.title)
                                .font(.custom("HelveticaNeue-Medium", size: 22, relativeTo: .title2))
                                .foregroundStyle(.black)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        AirPlayButton().frame(width: 44, height: 44)
                    }
                    HStack(spacing: 12) {
                        Text(String(track.id))
                            .font(.custom("HelveticaNeue-Bold", size: 22, relativeTo: .title2))
                            .hidden()
                            .frame(height: 10)
                            .accessibilityHidden(true)
                        Text(Self.coordinates(track))
                            .font(.custom("PTMono-Regular", fixedSize: 10))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .accessibilityLabel(PublicText.coordinates.formatted(Self.coordinates(track)))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 6) {
                    ZStack {
                        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                            Slider(value: Binding(get: { scrubTime ?? (player.playingTrackID == track.id ? player.elapsedTime : 0) },
                                                  set: { scrubTime = $0 }),
                                   in: 0...max(1, player.playingTrackID == track.id ? player.duration : 0),
                                   onEditingChanged: { editing in
                                if !editing, let scrubTime {
                                    player.seek(to: scrubTime)
                                    self.scrubTime = nil
                                }
                            })
                            .tint(BewiePalette.orange)
                            .disabled(player.loadingTrackID != nil || player.playingTrackID != track.id)
                            .accessibilityLabel(PublicText.playbackPosition.text)
                            .accessibilityHidden(player.loadingTrackID == track.id)
                            .opacity(player.loadingTrackID == track.id ? 0 : 1)
                        }
                        if player.loadingTrackID == track.id {
                            MusicLoadingBar(actualProgress: player.downloadProgress ?? 0)
                                .id(track.id)
                                .allowsHitTesting(false)
                        }
                    }
                    TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                        HStack {
                            Text(Self.time(scrubTime ?? (player.playingTrackID == track.id ? player.elapsedTime : 0)))
                            Spacer()
                            Text(Self.time(player.playingTrackID == track.id ? player.duration : 0))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BewiePalette.ink.opacity(0.65))
                    }
                }
                HStack(spacing: 36) {
                    transport("backward.end.fill", label: PublicText.previousTrack.text) { onNavigate(.previous) }
                    transport(player.isControlTrackPlaying ? "pause.fill" : "play.fill",
                              label: player.isControlTrackPlaying ? PublicText.pause.text : PublicText.resume.text) { player.togglePlayback() }
                        .disabled(player.loadingTrackID != nil)
                    transport("forward.end.fill", label: PublicText.nextTrack.text) { onNavigate(.next) }
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 0) {
                    ForEach(AlbumService.allCases) { service in
                        Link(destination: service.url) {
                            Group {
                                if let asset = service.asset {
                                    Image(asset).resizable().scaledToFit()
                                } else {
                                    VinylServiceIcon()
                                }
                            }
                            .frame(width: 23, height: 23)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(service.title)
                    }
                }

            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(idealWidth: 480, idealHeight: 250,
               maxHeight: UIDevice.current.userInterfaceIdiom == .pad ? 250 : nil)
        .presentationSizing(.fitted)
        .foregroundStyle(BewiePalette.ink)
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(250)))
        // Let iOS keep the sheet curvature concentric with the device display.
        .presentationCornerRadius(nil)
        .presentationBackground(BewiePalette.paper)
        .onChange(of: player.controlTrackID) { _, _ in scrubTime = nil }
    }

    private func transport(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .regular))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private static func time(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    private static func coordinates(_ track: AlbumTrack) -> String {
        String(format: "%.6f° %@  %.6f° %@", locale: Locale(identifier: "en_US_POSIX"),
               abs(track.latitude), track.latitude < 0 ? "S" : "N",
               abs(track.longitude), track.longitude < 0 ? "W" : "E")
    }
}

/// Album destinations verified against the artist’s album page.
private enum AlbumService: String, CaseIterable, Identifiable {
    case vinyl, appleMusic, spotify, youtube, deezer
    var id: Self { self }
    var title: String {
        switch self {
        case .vinyl: PublicText.vinyl.text
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        case .youtube: "YouTube Music"
        case .deezer: "Deezer"
        }
    }
    var asset: String? {
        switch self {
        case .vinyl: nil
        case .appleMusic: "ServiceAppleMusic"
        case .spotify: "ServiceSpotify"
        case .youtube: "ServiceYouTube"
        case .deezer: "ServiceDeezer"
        }
    }
    var url: URL {
        let value: String
        switch self {
        case .vinyl: value = "https://elasticstage.com/bewie/releases/every-room-is-borrowed-album"
        case .appleMusic: value = "https://music.apple.com/fr/album/every-room-is-borrowed/6816621534"
        case .spotify: value = "https://open.spotify.com/album/5kA2CztZuN7QeHSinlscNO"
        case .youtube: value = "https://music.youtube.com/playlist?list=OLAK5uy_lliFS5uYMdOtzMjppx3KTk502-vOsnSTI"
        case .deezer: value = "https://www.deezer.com/album/1107834232"
        }
        return URL(string: value)!
    }
}

private struct VinylServiceIcon: View {
    var body: some View {
        ZStack {
            Circle().fill(BewiePalette.ink)
            Circle().stroke(BewiePalette.paper.opacity(0.65), lineWidth: 0.7).padding(3)
            Circle().stroke(BewiePalette.paper.opacity(0.65), lineWidth: 0.7).padding(5.5)
            Circle().fill(BewiePalette.paper).frame(width: 3.5, height: 3.5)
        }
    }
}
