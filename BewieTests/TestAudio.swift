import Foundation
@testable import Bewie

final class TestAudio {
    static func url(_ track: AlbumTrack) -> URL? {
        #if targetEnvironment(macCatalyst)
        // Read the existing masters during local Mac tests without duplicating 500 MB.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("MusicAssets/Audio").appendingPathComponent(track.filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
        #else
        return Bundle(for: TestAudio.self).url(forResource: track.filename, withExtension: nil, subdirectory: "Audio")
        #endif
    }
}
