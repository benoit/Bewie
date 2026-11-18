import MapKit
import SwiftUI
import WatchKit

struct WatchPlayerView: View {
    let player: WatchAlbumPlayer
    var isRevealing = false
    @Environment(\.scenePhase) private var scenePhase
    private let paper = Color(red: 217.0 / 255, green: 211.0 / 255, blue: 199.0 / 255)
    private let ink = Color(red: 11.0 / 255, green: 12.0 / 255, blue: 11.0 / 255)
    private let orange = Color(red: 1, green: 121.0 / 255, blue: 0)

    private let mapBottomInset: CGFloat = 80
    @State private var volumeFocusRequest = 0
    @State private var isVolumeIndicatorVisible = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Map(initialPosition: .region(region), interactionModes: [])
                    .mapStyle(.standard(elevation: .flat, emphasis: .muted,
                                        pointsOfInterest: .excludingAll,
                                        showsTraffic: false))
                    .mapControlVisibility(.hidden)
                    // Leave MapKit's attribution above the lower control panel.
                    .safeAreaPadding(.bottom, mapBottomInset)
                    // Convert watchOS's dark map to the public app's pale gray.
                    .environment(\.colorScheme, .dark)
                    .saturation(0)
                    .colorInvert()
                    .contrast(0.85)
                    .brightness(0.14)
                    .id(player.track.id)
                    .accessibilityLabel(Text("Track location: \(player.track.title)"))
                trackPin
                    .position(x: geometry.size.width / 2,
                              y: max(0, geometry.size.height - mapBottomInset) / 2)
                playbackControls
                // Keep the native Crown receiver mounted. Its coordinator shows
                // the system UI on volume changes and hides it after two seconds.
                WatchCrownVolumeControl(wantsFocus: scenePhase == .active && !isRevealing,
                                        focusRequest: volumeFocusRequest,
                                        onVisibilityChange: { isVolumeIndicatorVisible = $0 })
                    .opacity(isVolumeIndicatorVisible ? 1 : 0)
                    .allowsHitTesting(isVolumeIndicatorVisible)
                    .accessibilityHidden(!isVolumeIndicatorVisible)
                    .frame(width: 50, height: 50)
                    .position(x: geometry.size.width - 25, y: 70)
                    .accessibilityIdentifier("watch.volumeControl")
            }
        }
        .ignoresSafeArea()
        .onChange(of: player.isPlaying) { _, _ in volumeFocusRequest &+= 1 }
        .onChange(of: player.isActivating) { _, _ in volumeFocusRequest &+= 1 }
        .alert("Playback unavailable", isPresented: Binding(
            get: { player.errorMessage != nil },
            set: { if !$0 { player.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { player.errorMessage = nil }
        } message: {
            Text(player.errorMessage ?? "")
        }
    }

    private var trackPin: some View {
        Circle()
            .fill(orange)
            .frame(width: 18, height: 18)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(player.track.title))
            .accessibilityValue(Text(player.track.id.formatted()))
            .accessibilityIdentifier("watch.trackPin")
    }

    private var playbackControls: some View {
        HStack(spacing: 0) {
            Button {
                controlTapped()
                player.previous()
            } label: {
                touchZone {
                    Image(systemName: "backward.end.fill")
                }
            }
            .accessibilityLabel(Text("Previous track"))
            .accessibilityValue(Text(player.track.title))
            .accessibilityIdentifier("watch.previous")

            Button {
                controlTapped()
                player.togglePlayback()
            } label: {
                touchZone {
                    if player.isActivating {
                        ProgressView().tint(ink)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }
                }
            }
            .disabled(player.isActivating)
            .accessibilityLabel(player.isActivating ? Text("Starting playback") :
                                player.isPlaying ? Text("Pause") : Text("Play"))
            .accessibilityIdentifier("watch.playPause")

            Button {
                controlTapped()
                player.next()
            } label: {
                touchZone {
                    Image(systemName: "forward.end.fill")
                }
            }
            .accessibilityLabel(Text("Next track"))
            .accessibilityValue(Text(player.track.title))
            .accessibilityIdentifier("watch.next")
        }
        .buttonStyle(WatchControlButtonStyle())
        .font(.headline)
        .foregroundStyle(ink)
        // Each label owns one complete third, including its blank padding.
        // The physical display clips the footer's lower outline.
        .background(paper)
        .overlay(alignment: .top) {
            HStack(spacing: 8) {
                Text(player.track.id.formatted())
                    .font(.custom("HelveticaNeue-Bold", size: 12))
                    .foregroundStyle(orange)
                    .accessibilityIdentifier("watch.trackNumber")
                Text(player.track.title)
                    .font(.custom("HelveticaNeue-Medium", size: 12))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("watch.trackTitle")
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .offset(y: 3)
            .allowsHitTesting(false)
        }
    }

    private func touchZone<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
    }

    private func controlTapped() {
        WKInterfaceDevice.current().play(.click)
        volumeFocusRequest &+= 1
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: player.track.coordinate,
                           latitudinalMeters: 2_000, longitudinalMeters: 2_000)
    }
}

private struct WatchControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Leave the label unchanged during a press; accepted taps use a short haptic.
        configuration.label
    }
}

#Preview {
    WatchPlayerView(player: WatchAlbumPlayer())
}
