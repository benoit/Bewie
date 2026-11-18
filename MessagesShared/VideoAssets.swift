import BackgroundAssets
import CryptoKit
import Foundation
import System

enum VideoAssetNames {
    static let trackIDs = Array(1...9)
    static func packID(_ id: Int) -> String { String(format: "bewie-video-%02d", id) }
    static func filename(_ id: Int) -> String { String(format: "track-%02d.mp4", id) }
    static func videoPath(_ id: Int) -> String { "MessagesVideos/" + filename(id) }
    static func metadataPath(_ id: Int) -> String { String(format: "MessagesVideos/track-%02d.json", id) }
}

struct VideoAssetMetadata: Codable, Sendable {
    let schemaVersion: Int
    let trackID: Int
    let bytes: Int
    let sha256: String
}

enum VideoAssetError: LocalizedError {
    case invalidTrack, invalidContents
    var errorDescription: String? {
        switch self {
        case .invalidTrack: "This song is unavailable."
        case .invalidContents: "The video could not be prepared. Please retry the download."
        }
    }
}

struct VideoAssetSource: Sendable {
    typealias ProgressHandler = @Sendable (Double) async -> Void
    var read: @Sendable (Int) throws -> (metadata: Data, video: Data)
    var isAvailable: @Sendable (Int) async -> Bool
    var download: @Sendable (Int, @escaping ProgressHandler) async throws -> Void

    static var live: Self {
        Self(read: { id in
            let manager = AssetPackManager.shared
            let pack = VideoAssetNames.packID(id)
            let metadata = try manager.contents(at: FilePath(VideoAssetNames.metadataPath(id)),
                                                searchingInAssetPackWithID: pack, options: .mappedIfSafe)
            let video = try manager.contents(at: FilePath(VideoAssetNames.videoPath(id)),
                                             searchingInAssetPackWithID: pack, options: .alwaysMapped)
            return (metadata, video)
        }, isAvailable: { id in
            let manager = AssetPackManager.shared
            if #available(iOS 26.4, macOS 26.4, *) {
                return manager.assetPackIsAvailableLocally(withID: VideoAssetNames.packID(id))
            }
            // This is an offline check on older supported systems too.
            return (try? manager.contents(at: FilePath(VideoAssetNames.metadataPath(id)),
                                           searchingInAssetPackWithID: VideoAssetNames.packID(id),
                                           options: .mappedIfSafe)) != nil
        }, download: { id, progress in
            let manager = AssetPackManager.shared
            let packID = VideoAssetNames.packID(id)
            let monitor = Task {
                for await update in manager.statusUpdates(forAssetPackWithID: packID) {
                    guard !Task.isCancelled else { return }
                    if case .downloading(_, let value) = update {
                        await progress(min(1, max(0, value.fractionCompleted)))
                    }
                }
            }
            defer { monitor.cancel() }
            let pack = try await manager.assetPack(withID: packID)
            try Task.checkCancellation()
            try await manager.ensureLocalAvailability(of: pack)
            try Task.checkCancellation()
        })
    }
}

/// Both the containing app and Messages use the same managed asset namespace.
/// Only a selected video is materialized as an ordinary, process-owned file:
/// Messages needs a stable local attachment URL, not a managed virtual URL.
actor VideoAssetStore {
    static let shared = VideoAssetStore()
    private let source: VideoAssetSource
    private let directory: URL
    private var prepared: [Int: (sha256: String, url: URL)] = [:]

    init(source: VideoAssetSource = .live, directory: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("BewieMessageVideos-" + UUID().uuidString, isDirectory: true)) {
        self.source = source
        self.directory = directory
    }

    /// Covers upgrades from the bundled-video app and interrupted installations.
    /// Existing video packs are retained; this does not create nine disk copies.
    func prepareAll() async {
        for id in VideoAssetNames.trackIDs {
            guard !Task.isCancelled else { return }
            if await source.isAvailable(id) { continue }
            do { try await source.download(id, { _ in }) }
            catch is CancellationError { return }
            catch { continue } // A later app activation or song selection retries.
        }
    }

    func video(for id: Int, progress: @escaping VideoAssetSource.ProgressHandler = { _ in }) async throws -> URL {
        guard VideoAssetNames.trackIDs.contains(id) else { throw VideoAssetError.invalidTrack }
        try Task.checkCancellation()
        // Read already-installed assets before asking the server anything. This
        // path is fully offline and also handles managed pack version updates.
        do {
            let url = try materialize(id)
            try Task.checkCancellation()
            await progress(1)
            return url
        } catch is CancellationError { throw CancellationError() }
        catch { /* The missing pack is requested below. */ }
        await progress(0)
        try await source.download(id, progress)
        try Task.checkCancellation()
        let url = try materialize(id)
        await progress(1)
        return url
    }

    private func materialize(_ id: Int) throws -> URL {
        let contents = try source.read(id)
        let metadata = try JSONDecoder().decode(VideoAssetMetadata.self, from: contents.metadata)
        guard metadata.schemaVersion == 1, metadata.trackID == id,
              metadata.bytes > 0, metadata.bytes == contents.video.count else { throw VideoAssetError.invalidContents }
        let hash = SHA256.hash(data: contents.video).map { String(format: "%02x", $0) }.joined()
        guard hash == metadata.sha256 else { throw VideoAssetError.invalidContents }
        if let old = prepared[id], old.sha256 == hash,
           FileManager.default.fileExists(atPath: old.url.path) { return old.url }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(UUID().uuidString + "-" + VideoAssetNames.filename(id))
        try contents.video.write(to: url, options: .atomic)
        prepared[id] = (hash, url)
        return url
    }
}
