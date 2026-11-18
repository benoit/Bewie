import MapKit
import SwiftUI

struct TVAlbumView: View {
    let player: AlbumPlayer
    @State private var camera: MapCameraPosition = .camera(SystemMapGeometry.startCamera(at: MapStartLocation.fallbackCoordinate))
    @State private var currentCamera: MapCamera?
    @State private var revision = 0
    @State private var flight: SystemMapGeometry.TrackFlight?
    @State private var flightTrigger = 0
    @State private var flightTask: Task<Void, Never>?
    @State private var flightGeneration = 0
    @State private var showsPlayer = false
    @State private var showsCover = true
    @State private var location = MapStartLocation()
    @State private var acceptsOpeningLocation = true
    @State private var mapReady = false
    @FocusState private var focus: TVFocus?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var coordinates
    @Namespace private var focusScope

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 1024
            let viewport = CGSize(width: 1024, height: geometry.size.height / scale)
            MapReader { proxy in
                ZStack {
                    Map(position: $camera, interactionModes: [])
                        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
                        .mapControls { }
                        .saturation(0)
                        .focusable(false)
                        .mapCameraKeyframeAnimator(trigger: flightTrigger) { initial in
                            TrackFlightKeyframes.frames(from: initial, to: flight)
                        }
                        .onMapCameraChange(frequency: .continuous) { context in
                            currentCamera = context.camera
                            revision &+= 1
                            mapReady = true
                        }
                        .onMapCameraChange(frequency: .onEnd) { context in
                            currentCamera = context.camera
                            revision &+= 1
                        }
                    if showsPlayer, player.playingTrackID != nil {
                        MapLyricsView(player: player)
                            .frame(width: 600, height: max(0, viewport.height - 150))
                            .scaleEffect(scale)
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                            .allowsHitTesting(false)
                    }
                    pins(proxy: proxy, viewport: viewport, scale: scale)
                    if showsPlayer, player.controlTrackID != nil {
                        TVCompactPlayer(player: player, focus: $focus, onNavigate: { direction in
                            navigate(direction, viewport: viewport)
                        }, onDismiss: {
                            showsPlayer = false
                            focus = .pin(player.controlTrackID ?? 1)
                        })
                        .frame(width: 480, height: 168)
                        .scaleEffect(scale * 0.5)
                        .frame(width: 240 * scale, height: 84 * scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 12 * scale)
                    }
                    if showsCover {
                        AlbumSleeveReveal(size: geometry.size, isPresented: $showsCover,
                                          reduceMotion: reduceMotion, isActive: scenePhase == .active,
                                          isMapReady: mapReady && location.isResolved)
                            .zIndex(10)
                    }
                }
                .coordinateSpace(name: coordinates)
                .focusScope(focusScope)
                .onExitCommand(perform: showsPlayer ? {
                    showsPlayer = false
                    focus = .pin(player.controlTrackID ?? 1)
                } : nil)
                .onPlayPauseCommand {
                    if player.controlTrackID != nil { player.togglePlayback() }
                    else { select(AlbumTrack.all.first { .pin($0.id) == focus } ?? AlbumTrack.all[0], viewport: viewport) }
                }
                .onChange(of: player.automaticAdvanceCount) { _, _ in
                    if let track = AlbumTrack.all.first(where: { $0.id == player.controlTrackID }) {
                        travel(to: track, viewport: viewport)
                    }
                }
                .onChange(of: player.remoteNavigationCount) { _, _ in
                    if let track = AlbumTrack.all.first(where: { $0.id == player.remoteRequestedTrackID }) {
                        travel(to: track, viewport: viewport)
                    }
                }
                .onChange(of: location.isResolved) { _, resolved in
                    if resolved && acceptsOpeningLocation {
                        camera = .camera(SystemMapGeometry.startCamera(at: location.coordinate))
                    }
                }
                .onChange(of: showsCover) { _, visible in
                    if !visible { focus = .pin(player.controlTrackID ?? 1) }
                }
                .onOpenURL { url in
                    guard url.scheme == "bewie", url.host == "track", let id = Int(url.lastPathComponent),
                          let track = AlbumTrack.all.first(where: { $0.id == id }) else { return }
                    showsCover = false
                    if player.playingTrackID != track.id || !player.isPlaying { player.select(track) }
                    travel(to: track, viewport: viewport)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-player") {
                showsCover = false
                acceptsOpeningLocation = false
                let track = AlbumTrack.all[1]
                player.select(track)
                camera = .camera(SystemMapGeometry.centeredFocusCamera(for: track, in: CGSize(width: 1024, height: 576)))
                showsPlayer = true
                try? await Task.sleep(for: .milliseconds(350))
                focus = .play
                return
            }
            #endif
            location.start()
            player.prefetchMusic()
        }
        .alert(PublicText.musicUnavailable.text, isPresented: Binding(get: { player.errorMessage != nil }, set: { if !$0 { player.dismissError() } })) {
            Button(PublicText.retry.text) {
                if let track = AlbumTrack.all.first(where: { $0.id == player.controlTrackID }) { player.select(track) }
            }
            Button(PublicText.close.text, role: .cancel) { player.dismissError() }
        } message: { Text(player.errorMessage ?? "") }
        .onDisappear { flightTask?.cancel() }
    }

    private func pins(proxy: MapProxy, viewport: CGSize, scale: CGFloat) -> some View {
        let _ = revision
        let bounds = CGRect(origin: .zero, size: viewport)
        let anchors = AlbumTrack.all.map { track in
            let projected = proxy.convert(track.coordinate, to: .named(coordinates))
                .map { CGPoint(x: $0.x / scale, y: $0.y / scale) }
            return SystemMapGeometry.pinAnchor(for: track.coordinate, id: track.id, projectedPoint: projected,
                                               camera: currentCamera, in: bounds)
        }
        let playerExclusion = CGRect(x: viewport.width / 2 - 132, y: viewport.height - 108, width: 264, height: 108)
        let attribution = CGRect(x: 0, y: viewport.height - 32, width: 160, height: 32)
        let placed = PinPlacement.resolve(anchors, in: viewport, selectedID: player.playingTrackID,
                                         exclusions: showsPlayer ? [playerExclusion, attribution] : [attribution])
        return ZStack(alignment: .topLeading) {
            ForEach(placed) { pin in
                if let track = AlbumTrack.all.first(where: { $0.id == pin.id }) {
                    TVMapPin(track: track, pin: pin, player: player, focus: $focus, scale: scale) {
                        select(track, viewport: viewport)
                    }
                    .position(x: pin.center.x * scale, y: pin.center.y * scale)
                    .zIndex(player.playingTrackID == pin.id ? 1 : 0)
                }
            }
        }
        .frame(width: viewport.width * scale, height: viewport.height * scale, alignment: .topLeading)
        .clipped()
    }

    private func select(_ track: AlbumTrack, viewport: CGSize) {
        if player.playingTrackID == track.id && player.isPlaying {
            player.focusPlayingTrack()
            showsPlayer = true
            focus = .play
            return
        }
        player.select(track)
        travel(to: track, viewport: viewport)
    }

    private func navigate(_ direction: TrackDirection, viewport: CGSize) {
        if direction == .previous, player.restartCurrentTrackIfPastIntro() { return }
        guard let id = player.controlTrackID, let track = AlbumTrack.adjacent(to: id, direction: direction) else { return }
        if player.playingTrackID == track.id && player.isPlaying { player.seek(to: 0) }
        else { player.select(track) }
        travel(to: track, viewport: viewport)
    }

    private func travel(to track: AlbumTrack, viewport: CGSize) {
        acceptsOpeningLocation = false
        location.cancel()
        flightTask?.cancel()
        flightGeneration &+= 1
        let generation = flightGeneration
        let destination = SystemMapGeometry.centeredFocusCamera(for: track, in: viewport)
        if reduceMotion {
            camera = .camera(destination)
            showsPlayer = true
            focus = .pin(track.id)
            return
        }
        flight = SystemMapGeometry.trackFlight(for: track,
                                              from: currentCamera ?? SystemMapGeometry.startCamera(at: location.coordinate),
                                              in: viewport)
        flightTrigger &+= 1
        flightTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(TrackFlightKeyframes.duration)) } catch { return }
            guard generation == flightGeneration, !Task.isCancelled else { return }
            camera = .camera(destination)
            flight = nil
            showsPlayer = true
            focus = .pin(track.id)
        }
    }
}
