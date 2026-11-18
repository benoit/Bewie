import Foundation
import SwiftUI

enum MessagesCatalog {
    static let tracks = AlbumTrack.all
    // Set this after Bewie has its own App Store record.
    static var appURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "BewieAppStoreURL") as? String,
              let url = URL(string: value), url.scheme == "https", url.host == "apps.apple.com" else { return nil }
        return url
    }

    static func video(for track: AlbumTrack,
                      progress: @escaping VideoAssetSource.ProgressHandler = { _ in }) async throws -> URL {
        try await VideoAssetStore.shared.video(for: track.id, progress: progress)
    }
}

enum MessagesStyle {
    static let paper = Color(red: 217 / 255, green: 211 / 255, blue: 199 / 255)
    static let ink = Color(red: 11 / 255, green: 12 / 255, blue: 11 / 255)
    static let orange = Color(red: 1, green: 121 / 255, blue: 0)
    static let controlFont = Font.custom("HelveticaNeue", size: 12, relativeTo: .caption)
}
