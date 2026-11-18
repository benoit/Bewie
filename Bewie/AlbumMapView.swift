import MapKit
import SwiftUI

struct AlbumMapView: View {
    let player: AlbumPlayer
    var topClearance: CGFloat = 0
    var bottomClearance: CGFloat = 0
    var leadingClearance: CGFloat = 0
    var trailingClearance: CGFloat = 0
    var pinExclusions: [CGRect] = []
    var onOpeningCameraReady: () -> Void = { }
    @Binding var presentedSheet: MapSheet?
    @State private var pendingLink: BewieLink?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraPosition: MapCameraPosition = .camera(SystemMapGeometry.startCamera(at: MapStartLocation.fallbackCoordinate))
    @State private var startLocation = MapStartLocation()
    @State private var acceptsStartLocation = true
    @State private var cameraRevision = 0
    @State private var currentCamera: MapCamera?
    @State private var viewportSize: CGSize = .zero
    @State private var flightTask: Task<Void, Never>?
    @State private var flightGeneration = 0
    @State private var cameraFlight: SystemMapGeometry.TrackFlight?
    @State private var cameraFlightTrigger = 0
    @State private var trackArrivalPlayer = TrackArrivalPlayer()
    @Namespace private var mapCoordinateSpace

    // iPad and iOS-on-Mac sheets float in the centre. Keep the player anchored
    // to the window instead.
    private var usesBottomPlayer: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isiOSAppOnMac
        #endif
    }

    private var nativeSheet: Binding<MapSheet?> {
        Binding(get: {
            if usesBottomPlayer, case .player = presentedSheet { return nil }
            return presentedSheet
        }, set: { presentedSheet = $0 })
    }

    var body: some View {
        MapReader { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Map(position: $cameraPosition,
                        interactionModes: [.pan, .zoom])
                        .mapStyle(.standard(elevation: .flat,
                                            emphasis: .muted,
                                            pointsOfInterest: .excludingAll,
                                            showsTraffic: false))
                        .mapControls { }
                        // Keep MapKit’s own attribution inside the phone’s bottom safe area.
                        .safeAreaPadding(.bottom, bottomClearance)
                        .safeAreaPadding(.leading, leadingClearance)
                        .safeAreaPadding(.trailing, trailingClearance)
                        .mapFeatureSelectionDisabled { _ in true }
                        .saturation(0)
                        .mapCameraKeyframeAnimator(trigger: cameraFlightTrigger) { initial in
                            TrackFlightKeyframes.frames(from: initial, to: cameraFlight)
                        }
                        .onTapGesture {
                            if case .player = presentedSheet { presentedSheet = nil }
                        }
                        .onMapCameraChange(frequency: .continuous) { context in
                            currentCamera = context.camera
                            cameraRevision &+= 1
                        }
                        .onChange(of: cameraPosition.positionedByUser) { _, byUser in
                            if byUser {
                                beginExploring()
                                cancelFlight(cancelCameraAnimation: false)
                            }
                        }
                        .onMapCameraChange(frequency: .onEnd) { context in
                            // The last continuous callback can precede MapKit's
                            // final projection. Refresh once it has actually settled.
                            currentCamera = context.camera
                            cameraRevision &+= 1
                        }


                    if case .player = presentedSheet {
                        MapLyricsView(player: player)
                            .frame(maxWidth: 600)
                            .frame(height: max(0, geometry.size.height - topClearance - 250 - max(bottomClearance, 12) - 24))
                            .frame(maxWidth: .infinity)
                            .padding(.leading, leadingClearance)
                            .padding(.trailing, trailingClearance)
                            .padding(.top, topClearance + 12)
                    }

                    MapPins(proxy: proxy,
                            coordinateSpace: mapCoordinateSpace,
                            cameraRevision: cameraRevision,
                            size: geometry.size,
                            exclusions: pinExclusions,
                            topClearance: topClearance,
                            leadingClearance: leadingClearance,
                            trailingClearance: trailingClearance,
                            player: player,
                            currentCamera: currentCamera,
                            onSelect: select)
                        .clipped()
                        .transaction { $0.animation = nil }
                }
                .coordinateSpace(name: mapCoordinateSpace)
                .onGeometryChange(for: CGSize.self) { geometry in
                    geometry.size
                } action: {
                    viewportSize = $0
                    openPendingLink()
                }
            }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-player") {
                beginExploring()
                if let track = AlbumTrack.all.last {
                    player.select(track)
                    cameraPosition = .camera(SystemMapGeometry.centeredFocusCamera(for: track, in: viewportSize))
                    presentedSheet = .player
                }
                onOpeningCameraReady()
                return
            }
            #endif
            startLocation.start()
        }
        .onOpenURL { url in
            guard let link = BewieLink(url: url) else { return }
            beginExploring()
            pendingLink = link
            openPendingLink()
        }
        .overlay(alignment: .bottom) {
            if usesBottomPlayer, case .player = presentedSheet {
                ZStack(alignment: .bottom) {
                    CompactPlayerView(player: player, onNavigate: navigate)
                        .frame(maxWidth: 480)
                        .frame(height: 250)
                        .background(BewiePalette.paper, in: RoundedRectangle(cornerRadius: 28))
                        .overlay(alignment: .top) {
                            Button { presentedSheet = nil } label: {
                                Capsule().fill(BewiePalette.ink.opacity(0.25))
                                    .frame(width: 32, height: 4)
                                    .frame(width: 60, height: 20)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(PublicText.closePlayer.text)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 16, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(bottomClearance, 12))
                        .accessibilityAction(.escape) { presentedSheet = nil }
                }
            }
        }
        .sheet(item: nativeSheet) { destination in
            switch destination {
            case .player:
                CompactPlayerView(player: player, onNavigate: navigate)
            }
        }
        .alert(PublicText.musicUnavailable.text, isPresented: Binding(
            get: { player.errorMessage != nil },
            set: { if !$0 { player.dismissError() } })) {
                Button(PublicText.retry.text) {
                    let id = player.failedTrackID
                    player.dismissError()
                    if let track = AlbumTrack.all.first(where: { $0.id == id }) { player.select(track) }
                }
                Button(PublicText.close.text, role: .cancel) { player.dismissError() }
            } message: { Text(player.errorMessage ?? "") }
        .onChange(of: player.loadingTrackID) { _, _ in presentArrivalPlayerIfReady() }
        .onChange(of: player.playingTrackID) { _, _ in presentArrivalPlayerIfReady() }
        .onChange(of: player.failedTrackID) { _, _ in presentArrivalPlayerIfReady() }
        .onChange(of: player.remoteNavigationCount) { _, _ in
            guard let id = player.remoteRequestedTrackID,
                  let track = AlbumTrack.all.first(where: { $0.id == id }) else { return }
            beginExploring()
            travel(to: track, zoomOutFirst: true)
        }
        .onChange(of: player.automaticAdvanceCount) { _, _ in
            guard let id = player.playingTrackID,
                  let track = AlbumTrack.all.first(where: { $0.id == id }) else { return }
            beginExploring()
            travel(to: track, zoomOutFirst: true)
        }
        .onChange(of: startLocation.isResolved) { _, resolved in
            if resolved && acceptsStartLocation {
                acceptsStartLocation = false
                cameraPosition = .camera(SystemMapGeometry.startCamera(at: startLocation.coordinate))
                onOpeningCameraReady()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                beginExploring()
                cancelFlight()
            }
        }
        .onDisappear {
            beginExploring()
            cancelFlight()
        }
    }

    private func openPendingLink() {
        guard let link = pendingLink, viewportSize.width > 0, viewportSize.height > 0 else { return }
        switch link {
        case .track(let number):
            guard let track = AlbumTrack.all.first(where: { $0.id == number }) else { return }
            pendingLink = nil
            presentedSheet = nil
            beginExploring()
            // Opening a URL is idempotent: it must never toggle a playing track off.
            if player.playingTrackID == track.id && player.isPlaying { player.focusPlayingTrack() }
            else { player.select(track) }
            travel(to: track, zoomOutFirst: true)
        }
    }

    private func select(_ track: AlbumTrack, isCentered: Bool) {
        if player.playingTrackID == track.id && player.isPlaying {
            player.focusPlayingTrack()
            beginExploring()
            travel(to: track, zoomOutFirst: true, showsPlayerImmediately: true)
            presentedSheet = .player
            return
        }
        if player.loadingTrackID == track.id {
            if isCentered { cancelFlight(); presentedSheet = .player }
            else { beginExploring(); travel(to: track, zoomOutFirst: true) }
            return
        }
        beginExploring()
        let changingTrack = player.playingTrackID != track.id
        player.select(track)
        travel(to: track, zoomOutFirst: changingTrack)
    }

    private func navigate(_ direction: TrackDirection) {
        if direction == .previous, player.restartCurrentTrackIfPastIntro() { return }
        beginExploring()
        guard let selectedID = player.controlTrackID,
              let track = AlbumTrack.adjacent(to: selectedID, direction: direction) else { return }
        if track.id == player.playingTrackID && player.isPlaying {
            player.focusPlayingTrack()
            player.seek(to: 0)
        }
        else { player.select(track) }
        travel(to: track, zoomOutFirst: true)
    }


    private func beginExploring() {
        acceptsStartLocation = false
        startLocation.cancel()
    }

    private func cancelFlight(cancelCameraAnimation: Bool = true) {
        flightTask?.cancel()
        flightTask = nil
        flightGeneration &+= 1
        trackArrivalPlayer.cancel()
        if cameraFlight != nil {
            cameraFlight = nil
            // MapKit already removes keyframes for a user gesture. Do not
            // replace that gesture with a new freeze animation.
            if cancelCameraAnimation { cameraFlightTrigger &+= 1 }
        }
    }

    private func presentArrivalPlayerIfReady() {
        if trackArrivalPlayer.takePresentation(playingID: player.playingTrackID, failedID: player.failedTrackID, loadingID: player.loadingTrackID) {
            presentedSheet = .player
        }
    }

    private func travel(to track: AlbumTrack, zoomOutFirst: Bool, showsPlayerImmediately: Bool = false) {
        let source = currentCamera ?? SystemMapGeometry.startCamera(at: MapStartLocation.fallbackCoordinate)
        let plan = SystemMapGeometry.trackFlight(for: track, from: source, in: viewportSize)
        travel(to: .camera(plan.arrival), center: plan.arrival.centerCoordinate, zoomOutFirst: zoomOutFirst,
               arrivalDuration: zoomOutFirst ? TrackFlightKeyframes.zoomInDuration : 2.6,
               trackFlight: zoomOutFirst ? plan : nil, arrivalTrackID: track.id,
               showsPlayerImmediately: showsPlayerImmediately)
    }

    private func travel(to destination: MapCameraPosition, center: CLLocationCoordinate2D, zoomOutFirst: Bool,
                        arrivalDuration: TimeInterval = 2.6, trackFlight: SystemMapGeometry.TrackFlight? = nil,
                        arrivalTrackID: Int? = nil, showsPlayerImmediately: Bool = false) {
        cancelFlight()
        if let arrivalTrackID {
            if trackArrivalPlayer.begin(arrivalTrackID, showImmediately: showsPlayerImmediately) {
                // Already audible: reveal now, with no delayed reopening after
                // a subsequent map tap dismisses the player during this flight.
                presentedSheet = .player
            } else {
                if case .player = presentedSheet { presentedSheet = nil }
            }
        }
        guard !reduceMotion else {
            cameraPosition = destination
            if let arrivalTrackID {
                trackArrivalPlayer.arrive(arrivalTrackID)
                presentArrivalPlayerIfReady()
            }
            return
        }
        let generation = flightGeneration
        if let trackFlight {
            cameraFlight = trackFlight
            cameraFlightTrigger &+= 1
            flightTask = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(TrackFlightKeyframes.duration)) } catch { return }
                guard !Task.isCancelled, generation == flightGeneration else { return }
                cameraPosition = destination
                cameraFlight = nil
                flightTask = nil
                if let arrivalTrackID {
                    trackArrivalPlayer.arrive(arrivalTrackID)
                    presentArrivalPlayerIfReady()
                }
            }
            return
        }
        let departure = currentCamera ?? SystemMapGeometry.startCamera(at: MapStartLocation.fallbackCoordinate)
        flightTask = Task { @MainActor in
            guard !Task.isCancelled, generation == flightGeneration else { return }
            if zoomOutFirst {
                withAnimation(.easeInOut(duration: 1.6)) {
                    cameraPosition = .camera(SystemMapGeometry.travelCamera(from: departure, to: center))
                }
                do { try await Task.sleep(for: .milliseconds(1_700)) } catch { return }
                guard !Task.isCancelled, generation == flightGeneration else { return }
            }
            withAnimation(.easeInOut(duration: arrivalDuration)) {
                cameraPosition = destination
            }
            do { try await Task.sleep(for: .milliseconds(Int(arrivalDuration * 1_000) + 100)) } catch { return }
            guard !Task.isCancelled, generation == flightGeneration else { return }
            flightTask = nil
            if let arrivalTrackID {
                trackArrivalPlayer.arrive(arrivalTrackID)
                presentArrivalPlayerIfReady()
            }
        }
    }
}

private struct MapPins: View {
    let proxy: MapProxy
    let coordinateSpace: Namespace.ID
    // MapProxy is a snapshot interface; reading this value refreshes projection while
    // the native map pans, zooms or decelerates without installing custom gestures.
    let cameraRevision: Int
    let size: CGSize
    let exclusions: [CGRect]
    let topClearance: CGFloat
    let leadingClearance: CGFloat
    let trailingClearance: CGFloat
    let player: AlbumPlayer
    let currentCamera: MapCamera?
    let onSelect: (AlbumTrack, Bool) -> Void

    var body: some View {
        let pins = projectedPins
        ZStack(alignment: .topLeading) {
            ForEach(pins) { pin in
                if let track = AlbumTrack.all.first(where: { $0.id == pin.id }) {
                    MapPin(track: track,
                           selected: player.playingTrackID == track.id,
                           playing: player.playingTrackID == track.id && player.isPlaying,
                           error: player.failedTrackID == track.id ? player.errorMessage : nil,
                           anchorOffset: CGSize(width: pin.anchor.x - pin.center.x,
                                                height: pin.anchor.y - pin.center.y),
                           showsAnchor: !pin.isOffscreen,
                           onSelect: { onSelect(track, SystemMapGeometry.isPinCentered(pin, in: size)) },
                           playbackProgress: { player.playbackProgress },
                           downloading: player.loadingTrackID == track.id)
                        .position(pin.center)
                        .zIndex(player.playingTrackID == track.id ? 1 : 0)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .mask {
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                context.blendMode = .destinationOut
                for area in exclusions { context.fill(Path(area), with: .color(.black)) }
            }
        }
    }

    private var projectedPins: [PlacedPin] {
        _ = cameraRevision
        let bounds = SystemMapGeometry.pinLayoutBounds(in: size, bottomClearance: 0)
            .inset(by: UIEdgeInsets(top: topClearance, left: leadingClearance, bottom: 0, right: trailingClearance))
        let anchors = AlbumTrack.all.map { track in
            let point = proxy.convert(track.coordinate, to: .named(coordinateSpace))
            return SystemMapGeometry.pinAnchor(for: track.coordinate, id: track.id,
                                               projectedPoint: point, camera: currentCamera, in: bounds)
        }
        return PinPlacement.resolve(anchors, in: bounds.size, selectedID: player.playingTrackID,
                                    origin: bounds.origin, exclusions: exclusions)
    }
}

#Preview {
    @Previewable @State var sheet: MapSheet?
    AlbumMapView(player: AlbumPlayer(), presentedSheet: $sheet)
}

enum MapSheet: Identifiable {
    case player

    var id: String {
        switch self {
        case .player: "player"
        }
    }
}
