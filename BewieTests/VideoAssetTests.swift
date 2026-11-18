import CryptoKit
import Foundation
import XCTest
@testable import Bewie

@MainActor
final class VideoAssetTests: XCTestCase {
    func testInstalledVideoWorksOfflineAndReusesItsAttachmentFile() async throws {
        let fixture = VideoFixture(available: Set(1...9))
        let store = VideoAssetStore(source: fixture.source)
        let first = try await store.video(for: 8)
        let second = try await store.video(for: 8)
        XCTAssertEqual(try Data(contentsOf: first), fixture.bytes)
        XCTAssertEqual(first, second)
        XCTAssertTrue(fixture.downloads.isEmpty)
    }

    func testMissingVideoDownloadsBeforeBecomingAnAttachment() async throws {
        let fixture = VideoFixture(available: [])
        let store = VideoAssetStore(source: fixture.source)
        let url = try await store.video(for: 8)
        XCTAssertEqual(try Data(contentsOf: url), fixture.bytes)
        XCTAssertEqual(fixture.downloads, [8])
    }

    func testPreparingAnUpgradeDownloadsOnlyMissingPacksOnce() async {
        let fixture = VideoFixture(available: [1, 3, 8])
        let store = VideoAssetStore(source: fixture.source)
        await store.prepareAll()
        await store.prepareAll()
        XCTAssertEqual(fixture.downloads, [2, 4, 5, 6, 7, 9])
    }

    func testUpdatedPackDoesNotReuseThePreviousVideoBytes() async throws {
        let fixture = VideoFixture(available: [8])
        let store = VideoAssetStore(source: fixture.source)
        let old = try await store.video(for: 8)
        let oldBytes = try Data(contentsOf: old)
        fixture.replaceVideo()
        let updated = try await store.video(for: 8)
        XCTAssertNotEqual(old, updated)
        XCTAssertNotEqual(try Data(contentsOf: updated), oldBytes)
        // An attachment already handed to Messages remains readable.
        XCTAssertEqual(try Data(contentsOf: old), oldBytes)
        XCTAssertTrue(fixture.downloads.isEmpty)
    }

    func testCorruptVideoIsNeverHandedToMessages() async {
        let fixture = VideoFixture(available: [8])
        fixture.corrupt = true
        let store = VideoAssetStore(source: fixture.source)
        do {
            _ = try await store.video(for: 8)
            XCTFail("A mismatched checksum must not become an attachment")
        } catch {
            XCTAssertEqual(fixture.downloads, [8])
        }
    }

    func testInvalidTrackDoesNotStartADownload() async {
        let fixture = VideoFixture(available: [])
        let store = VideoAssetStore(source: fixture.source)
        do { _ = try await store.video(for: 10); XCTFail("Unexpected track") }
        catch { XCTAssertTrue(fixture.downloads.isEmpty) }
    }
}

private final class VideoFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var available: Set<Int>
    private var stored = Data("Original video bytes".utf8)
    private var requests: [Int] = []
    private var corrupted = false
    init(available: Set<Int>) { self.available = available }
    var bytes: Data { lock.withLock { stored } }
    var downloads: [Int] { lock.withLock { requests } }
    var corrupt: Bool {
        get { lock.withLock { corrupted } }
        set { lock.withLock { corrupted = newValue } }
    }
    func replaceVideo() { lock.withLock { stored = Data("Updated independent asset version".utf8) } }
    var source: VideoAssetSource {
        VideoAssetSource(read: { [self] id in
            try lock.withLock {
                guard available.contains(id) else { throw CocoaError(.fileNoSuchFile) }
                let hash = SHA256.hash(data: stored).map { String(format: "%02x", $0) }.joined()
                let metadata = VideoAssetMetadata(schemaVersion: 1, trackID: id, bytes: stored.count,
                                                   sha256: corrupted ? String(repeating: "0", count: 64) : hash)
                return (try JSONEncoder().encode(metadata), stored)
            }
        }, isAvailable: { [self] id in lock.withLock { available.contains(id) } }, download: { [self] id, progress in
            try Task.checkCancellation()
            lock.withLock { requests.append(id); available.insert(id) }
            await progress(1)
        })
    }
}
