import SwiftUI
import WatchKit

@main
struct BewieWatchApp: App {
    @State private var player: WatchAlbumPlayer
    @State private var showsOpeningSleeve = true
    @State private var coverPresentationID = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
#if DEBUG
        // Keep touch-zone UI tests deterministic without opening an audio-route picker.
        if ProcessInfo.processInfo.arguments.contains("--watch-controls-ui-testing") {
            let defaults = UserDefaults(suiteName: "BewieWatchControlsUITests")!
            defaults.removePersistentDomain(forName: "BewieWatchControlsUITests")
            defaults.set(1, forKey: "watch.trackID")
            _showsOpeningSleeve = State(initialValue:
                ProcessInfo.processInfo.arguments.contains("--watch-launch-reveal-ui-testing"))
            _player = State(initialValue: WatchAlbumPlayer(defaults: defaults,
                                                           activateSession: { _ in }))
            return
        }
#endif
        _player = State(initialValue: WatchAlbumPlayer())
    }

    private var showsCoverOnActivation: Bool {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--watch-controls-ui-testing") {
            return ProcessInfo.processInfo.arguments.contains("--watch-launch-reveal-ui-testing")
        }
#endif
        return true
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationStack {
                    WatchPlayerView(player: player, isRevealing: showsOpeningSleeve)
                        .navigationTitle("")
                        .toolbarVisibility(.visible, for: .navigationBar)
                        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                        // Balanced toolbar slots keep watchOS's own clock centered.
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Color.clear.frame(width: 44, height: 1)
                                    .accessibilityHidden(true).allowsHitTesting(false)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Color.clear.frame(width: 44, height: 1)
                                    .accessibilityHidden(true).allowsHitTesting(false)
                            }
                        }
                        .toolbarForegroundStyle(.black, for: .navigationBar)
                        .toolbarColorScheme(.light, for: .navigationBar)
                }
                .allowsHitTesting(!showsOpeningSleeve)
                .accessibilityHidden(showsOpeningSleeve)

                if showsOpeningSleeve {
                    GeometryReader { geometry in
                        WatchAlbumCoverReveal(size: geometry.size, isPresented: $showsOpeningSleeve,
                                              reduceMotion: reduceMotion, isActive: scenePhase == .active)
                            .id(coverPresentationID)
                    }
                    .ignoresSafeArea()
                    .transition(.identity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, showsCoverOnActivation {
                    // A fresh view resets an interrupted slide as well as a completed one.
                    coverPresentationID &+= 1
                    showsOpeningSleeve = true
                }
            }
        }
    }
}
