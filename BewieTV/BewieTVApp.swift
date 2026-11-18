import SwiftUI

@main
struct BewieTVApp: App {
    @State private var player = Self.makePlayer()

    private static func makePlayer() -> AlbumPlayer {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-audio"), let url = try? TVPreviewAudio.makeURL() {
            let asset = MusicAudioAsset.fileURL(url)
            let client = MusicAssetClient(localAsset: { _ in asset }, download: { _, _, _ in asset })
            return AlbumPlayer(library: MusicLibrary(client: client))
        }
        #endif
        return AlbumPlayer()
    }

    var body: some Scene {
        WindowGroup {
            TVAlbumView(player: player)
                .preferredColorScheme(.light)
        }
    }
}

enum BewiePalette {
    static let orange = Color(red: 1, green: 121.0 / 255, blue: 0)
    static let paper = Color(red: 217.0 / 255, green: 211.0 / 255, blue: 199.0 / 255)
    static let ink = Color(red: 11.0 / 255, green: 12.0 / 255, blue: 11.0 / 255)
}

enum TVFocus: Hashable {
    case pin(Int), previous, play, next, seek
}
