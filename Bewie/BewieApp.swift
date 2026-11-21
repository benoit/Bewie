import SwiftUI

@main
struct BewieApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.environment["BEWIE_UNIT_TESTS"] == "1" {
                Color.clear
            } else {
                BewieExperienceView().preferredColorScheme(.light)
            }
            #else
            BewieExperienceView().preferredColorScheme(.light)
            #endif
        }
    }
}

struct BewieExperienceView: View {
    @State private var player = AlbumPlayer()
    #if os(iOS) && !targetEnvironment(macCatalyst)
    @State private var blessing = BewieBlessing()
    #endif
    @State private var showsOpeningSleeve = true
    @State private var isOpeningCameraReady = false
    @State private var mapSheet: MapSheet?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            let size = CGSize(width: geometry.size.width + insets.leading + insets.trailing,
                              height: geometry.size.height + insets.top + insets.bottom)
            #if os(iOS) && !targetEnvironment(macCatalyst)
            let pearlFrame = PearlReveal.isVisible(isBlessed: blessing.isBlessed, showsOpeningSleeve: showsOpeningSleeve, presentsPlayer: mapSheet != nil)
                ? SystemMapGeometry.guideButtonFrame(in: size, bottomSafeArea: insets.bottom) : nil
            #else
            let pearlFrame: CGRect? = nil
            #endif
            ZStack(alignment: .topLeading) {
                AlbumMapView(player: player, topClearance: insets.top,
                             bottomClearance: insets.bottom, leadingClearance: insets.leading,
                             trailingClearance: insets.trailing,
                             pinExclusions: SystemMapGeometry.pinExclusions(in: size,
                                 topSafeArea: insets.top, bottomSafeArea: insets.bottom,
                                 showsSystemIndicators: true, guideButton: pearlFrame),
                             onOpeningCameraReady: { isOpeningCameraReady = true },
                             presentedSheet: $mapSheet)
                    .allowsHitTesting(!showsOpeningSleeve)
                    .accessibilityHidden(showsOpeningSleeve)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                if let pearlFrame {
                    PerlePearl()
                        .position(x: pearlFrame.midX, y: pearlFrame.midY)
                }
                #endif
                if showsOpeningSleeve {
                    AlbumSleeveReveal(size: size, isPresented: $showsOpeningSleeve,
                                      reduceMotion: reduceMotion, isActive: scenePhase == .active,
                                      isMapReady: isOpeningCameraReady)
                        .transition(.identity)
                        .zIndex(1)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .offset(x: -insets.leading, y: -insets.top)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            player.prefetchMusic()
        }
        #if !targetEnvironment(macCatalyst)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await VideoAssetStore.shared.prepareAll()
        }
        #endif
        .onOpenURL { url in
            if BewieLink(url: url) != nil { showsOpeningSleeve = false; return }
            #if os(iOS) && !targetEnvironment(macCatalyst)
            Task { await blessing.open(url) }
            #endif
        }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .alert("Blessing", isPresented: Binding(
            get: { blessing.errorMessage != nil },
            set: { if !$0 { blessing.errorMessage = nil } })) {
                Button("OK", role: .cancel) { blessing.errorMessage = nil }
            } message: { Text(blessing.errorMessage ?? "") }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { showsOpeningSleeve = false }
        }
        .background(BewiePalette.paper.ignoresSafeArea())
        .statusBarHidden(false)
    }
}

enum BewiePalette {
    static let orange = Color(red: 1, green: 121.0 / 255, blue: 0)
    static let paper = Color(red: 217.0 / 255, green: 211.0 / 255, blue: 199.0 / 255)
    static let ink = Color(red: 11.0 / 255, green: 12.0 / 255, blue: 11.0 / 255)
}

/// Bewie owns song links; Perle retains its independent guide routes.
enum BewieLink: Equatable {
    case track(Int)

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "bewie",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/",
              let host = parts.host, host.utf8.count == 1,
              let number = Int(host), (1...9).contains(number) else { return nil }
        self = .track(number)
    }
}
