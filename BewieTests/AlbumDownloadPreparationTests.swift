import XCTest
import SwiftUI
@testable import Bewie

@MainActor
final class AlbumDownloadPreparationTests: XCTestCase {
    private enum TestError: Error { case deadline }

    private func eventually(_ predicate: @MainActor () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !(await predicate()) {
            guard ContinuousClock.now < deadline else { XCTFail("Download state did not settle"); throw TestError.deadline }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func testDownloadBarMovesInsideActualPlayerWithoutTransferUpdates() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client)
        let player = AlbumPlayer(library: library)
        defer { player.stop(); library.cancel() }
        player.prefetchMusic()
        try await eventually { await assets.requests[1] == 1 }
        player.select(AlbumTrack.all[0])
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        defer { previousWindow?.makeKeyAndVisible() }
        let controller = UIHostingController(rootView: CompactPlayerView(player: player, onNavigate: { _ in })
            .background(BewiePalette.paper).ignoresSafeArea())
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 250)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        defer { window.isHidden = true; window.rootViewController = nil }
        var frames: [Data] = []
        for index in 0...1 {
            try await Task.sleep(for: .milliseconds(index == 0 ? 300 : 2_000))
            controller.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            // Compare the hosted content at its actual display scale on iPad and Mac.
            frames.append(try XCTUnwrap(image.pngData()))
            let attachment = XCTAttachment(image: image)
            attachment.name = "quiet-loading-player-frame-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertNotEqual(frames[0], frames[1], "Loading strip must visibly move without transfer callbacks")
        XCTAssertEqual(player.loadingTrackID, 1)
        XCTAssertNil(player.errorMessage)
        await assets.finishAll()
    }

    func testDownloadBarRendersWithoutVisibleCopy() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client)
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        await assets.progress(1, 0.5)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        defer { previousWindow?.makeKeyAndVisible() }
        for (name, width, textSize) in [("phone", 390.0, DynamicTypeSize.large),
                                         ("tablet-large-text", 568.0, DynamicTypeSize.accessibility3)] {
            let controller = UIHostingController(rootView: MusicLoadingBar(actualProgress: library.progress)
                .frame(height: 96)
                .environment(\.dynamicTypeSize, textSize)
                .background(BewiePalette.paper))
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: width, height: 96)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.frame = window.bounds
            try await Task.sleep(for: .milliseconds(200))
            controller.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "album-download-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
            window.rootViewController = nil
        }
        await assets.finishOldest(1)
        try await eventually { library.isComplete }
    }

    func testSelectedTrackStartsAfterSharedAlbumDownloadResolves() async throws {
        let audioURL = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let assets = ControlledMusicAssets(available: Set(2...9), audioURL: audioURL)
        let library = MusicLibrary(client: assets.client)
        let player = AlbumPlayer(library: library)
        defer { player.stop(); library.cancel() }
        player.prefetchMusic()
        try await eventually { await assets.requests[1] == 1 }
        player.select(AlbumTrack.all[0])
        XCTAssertEqual(player.loadingTrackID, 1)
        XCTAssertFalse(player.isPlaying)
        await assets.finishOldest(1)
        try await eventually { player.isPlaying }
        XCTAssertEqual(player.playingTrackID, 1)
        XCTAssertNil(player.loadingTrackID)
        XCTAssertNil(player.errorMessage)
        XCTAssertTrue(library.isComplete)
        let requests = await assets.requests
        XCTAssertEqual(requests[1], 1)
    }

    func testOpaqueFailureAutomaticallyPerformsTheRetryThatWouldOtherwiseNeedATap() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[2]))
        let assets = ControlledMusicAssets(available: Set([1, 2] + Array(4...9)), audioURL: file)
        let library = MusicLibrary(client: assets.client, availabilityPollInterval: .milliseconds(25))
        let player = AlbumPlayer(library: library)
        defer { player.stop(); library.cancel() }
        player.prefetchMusic()
        try await eventually { await assets.requests[3] == 1 }
        player.select(AlbumTrack.all[2])
        await assets.failOldest(3, error: NSError(domain: "BackgroundAssets.AssetPackManagerError", code: 0))
        try await eventually { await assets.requests[3] == 2 }
        XCTAssertEqual(player.loadingTrackID, 3)
        XCTAssertNil(player.errorMessage)
        await assets.finishOldest(3)
        try await eventually { player.isPlaying && player.playingTrackID == 3 }
        XCTAssertNil(player.loadingTrackID)
        XCTAssertNil(player.errorMessage)
        let requests = await assets.requests
        XCTAssertEqual(requests, [3: 2])
    }

    func testPersistentUnclassifiedFailureStopsAfterOneConfirmationRetry() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, availabilityPollInterval: .milliseconds(25))
        defer { library.cancel() }
        library.prepareAlbum()
        for attempt in 1...2 {
            try await eventually { await assets.requests[1] == attempt }
            await assets.failOldest(1, error: NSError(domain: NSCocoaErrorDomain, code: 513))
        }
        try await eventually { library.phase == .failed }
        let requests = await assets.requests
        XCTAssertEqual(requests[1], 2)
        XCTAssertEqual(library.failedTrackIDs, [1])
    }

    func testTemporaryXPCErrorRetriesOnlyItsTrackAndKeepsSelectionWaiting() async throws {
        let assets = ControlledMusicAssets(available: Set(3...9))
        let library = MusicLibrary(client: assets.client, retryDelays: [.milliseconds(25)])
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests.count == 2 }
        let selection = Task { try await library.download(AlbumTrack.all[0]) }
        let error = NSError(domain: "XPC.XPCRichError", code: 1)
        await assets.setSnapshot(.init(stage: .failed, failure: MusicAssetFailure(error)))
        XCTAssertEqual(library.phase, .downloading)
        await assets.failOldest(1, error: error)
        try await eventually { await assets.requests[1] == 2 }
        let requests = await assets.requests
        XCTAssertEqual(requests[2], 1, "The healthy transfer must not restart")
        await assets.finishOldest(1)
        _ = try await selection.value
        XCTAssertEqual(library.readyCount, 8)
        await assets.finishOldest(2)
        try await eventually { library.isComplete }
    }

    func testRepeatedTransientFailuresStopAfterTheRetryBudget() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, retryDelays: [.milliseconds(5), .milliseconds(5)])
        defer { library.cancel() }
        library.prepareAlbum()
        for attempt in 1...3 {
            try await eventually { await assets.requests[1] == attempt }
            await assets.failOldest(1, error: NSError(domain: "XPC.XPCRichError", code: 1))
        }
        try await eventually { library.phase == .failed }
        let requests = await assets.requests
        XCTAssertEqual(requests[1], 3)
        XCTAssertEqual(library.failedTrackIDs, [1])
    }

    func testManualRetryLeavesOtherTransfersAndReadyTracksAlone() async throws {
        let assets = ControlledMusicAssets(available: Set(3...9))
        let library = MusicLibrary(client: assets.client, retryDelays: [])
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests.count == 2 }
        await assets.failOldest(1)
        try await eventually { library.phase == .failed }
        library.retry()
        try await eventually { await assets.requests[1] == 2 }
        let requests = await assets.requests
        XCTAssertEqual(requests[2], 1)
        XCTAssertEqual(library.readyCount, 7)
        await assets.finishOldest(1)
        await assets.finishOldest(2)
        try await eventually { library.isComplete }
    }

    func testPlayerRendersSelectedTrackWhileItsMusicIsStillMissing() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let assets = ControlledMusicAssets(available: Set([1] + Array(3...9)), audioURL: file)
        let library = MusicLibrary(client: assets.client)
        let player = AlbumPlayer(library: library)
        defer { player.stop(); library.cancel() }
        player.prefetchMusic()
        try await eventually { await assets.requests[2] == 1 }
        player.select(AlbumTrack.all[0])
        player.select(AlbumTrack.all[1])
        await assets.progress(2, 0.4)
        XCTAssertEqual(player.controlTrackID, 2)
        XCTAssertEqual(player.loadingTrackID, 2)
        XCTAssertEqual(player.playingTrackID, 1)
        XCTAssertFalse(player.isControlTrackPlaying)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        defer { previousWindow?.makeKeyAndVisible() }
        for state in ["loading", "ready"] {
            if state == "ready" {
                await assets.finishOldest(2)
                try await eventually { player.playingTrackID == 2 && player.isPlaying }
                player.pause()
                player.seek(to: 0)
            }
            for (name, width) in [("phone", 390.0), ("tablet", 480.0)] {
                let controller = UIHostingController(rootView: CompactPlayerView(player: player, onNavigate: { _ in })
                    .background(BewiePalette.paper)
                    .ignoresSafeArea())
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: width, height: 250)
                window.rootViewController = controller
                window.makeKeyAndVisible()
                controller.view.frame = window.bounds
                try await Task.sleep(for: .milliseconds(500))
                controller.view.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                    controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "track-player-\(state)-\(name)"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.isHidden = true
                window.rootViewController = nil
            }
        }
        XCTAssertNil(player.loadingTrackID)
        XCTAssertEqual(player.controlTrackID, 2)
    }

    func testDownloadedAlbumIsReadyWithoutRequestingAnyPacks() async throws {
        let assets = ControlledMusicAssets(available: Set(1...9))
        let library = MusicLibrary(client: assets.client)
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { library.phase == .ready }
        XCTAssertEqual(library.readyCount, 9)
        XCTAssertEqual(library.progress, 1)
        XCTAssertFalse(library.needsPreparation)
        let requests = await assets.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testSlowLocalChecksLeaveMainActorAvailable() async throws {
        let assets = ControlledMusicAssets(available: Set(1...9), checkDelay: .milliseconds(40))
        let library = MusicLibrary(client: assets.client)
        defer { library.cancel() }
        library.prepareAlbum()
        let heartbeat = expectation(description: "UI actor remains responsive while checking assets")
        Task { @MainActor in heartbeat.fulfill() }
        await fulfillment(of: [heartbeat], timeout: 0.3)
        XCTAssertEqual(library.phase, .checking)
        try await eventually { library.isComplete }
    }

    func testSelectionSharesPrefetchAndReportsPartialAlbumProgress() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client)
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        let selection = Task { try await library.download(AlbumTrack.all[0]) }
        try await Task.sleep(for: .milliseconds(20))
        await assets.progress(1, 0.5)
        XCTAssertEqual(library.readyCount, 8)
        XCTAssertEqual(library.progress, 8.5 / 9, accuracy: 0.001)
        let requests = await assets.requests
        XCTAssertEqual(requests, [1: 1])
        await assets.finishOldest(1)
        let asset = try await selection.value
        guard case .fileURL(let url) = asset else { return XCTFail("Expected test file") }
        XCTAssertEqual(url.lastPathComponent, "track-01.m4a")
        XCTAssertTrue(library.isComplete)
        XCTAssertEqual(library.phase, .ready)
    }

    func testTransferAt100PercentIsNotReadyUntilItsFileResolves() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client)
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        await assets.progress(1, 1)
        XCTAssertFalse(library.isComplete)
        XCTAssertNil(library.localAsset(for: AlbumTrack.all[0]))
        XCTAssertEqual(library.phase, .downloading)
        await assets.finishOldest(1)
        try await eventually { library.isComplete }
    }

    func testFailureIsVisibleAndRetryOnlyRequestsMissingMusic() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, retryDelays: [])
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        await assets.failOldest(1)
        try await eventually { library.phase == .failed }
        XCTAssertEqual(library.failedTrackIDs, [1])
        library.retry()
        try await eventually { await assets.requests[1] == 2 }
        await assets.finishOldest(1)
        try await eventually { library.phase == .ready }
        let requests = await assets.requests
        XCTAssertEqual(requests, [1: 2])
        XCTAssertTrue(library.failedTrackIDs.isEmpty)
    }

    func testQuietSystemDownloadWaitsInsteadOfFailingAndRecoversWithoutCallbacks() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, stallTimeout: .milliseconds(250),
                                   availabilityPollInterval: .milliseconds(25))
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        let selection = Task { try await library.download(AlbumTrack.all[0]) }
        try await eventually { library.phase == .waiting }
        XCTAssertEqual(library.readyCount, 8)
        XCTAssertTrue(library.failedTrackIDs.isEmpty)
        // The file arrives, but both the status stream and SDK waiter stay silent.
        await assets.makeAvailable([1])
        try await eventually { library.isComplete }
        let asset = try await selection.value
        guard case .fileURL(let url) = asset else { return XCTFail("Expected test file") }
        XCTAssertEqual(url.lastPathComponent, "track-01.m4a")
        XCTAssertEqual(library.phase, .ready)
        await assets.finishAll()
    }

    func testReadyCountUpdatesWithoutAnyDownloadCallbacks() async throws {
        let assets = ControlledMusicAssets(available: [1])
        let library = MusicLibrary(client: assets.client, availabilityPollInterval: .milliseconds(25))
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests.count == 8 }
        XCTAssertEqual(library.readyCount, 1)
        await assets.makeAvailable([2, 3])
        try await eventually { library.readyCount == 3 }
        await assets.makeAvailable(Set(4...9))
        try await eventually { library.isComplete }
        await assets.finishAll()
    }

    func testFailedStatusDoesNotRejectSelectedTrackWhenSDKTransferThenSucceeds() async throws {
        let file = try XCTUnwrap(TestAudio.url(AlbumTrack.all[0]))
        let assets = ControlledMusicAssets(available: Set(2...9), audioURL: file)
        let library = MusicLibrary(client: assets.client, availabilityPollInterval: .milliseconds(25))
        let player = AlbumPlayer(library: library)
        defer { player.stop(); library.cancel() }
        player.prefetchMusic()
        try await eventually { await assets.requests[1] == 1 }
        player.select(AlbumTrack.all[0])
        await assets.setSnapshot(.init(stage: .failed, failure: MusicAssetFailure(NSError(domain: NSCocoaErrorDomain, code: 513))))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(player.loadingTrackID, 1)
        XCTAssertNil(player.errorMessage)
        XCTAssertTrue(library.failedTrackIDs.isEmpty)
        await assets.finishOldest(1)
        try await eventually { player.isPlaying }
        XCTAssertEqual(player.playingTrackID, 1)
        XCTAssertNil(player.errorMessage)
    }

    func testTerminalSDKErrorRechecksAvailableFileBeforeRejectingSelection() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, availabilityPollInterval: .milliseconds(25), retryDelays: [])
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        let selection = Task { try await library.download(AlbumTrack.all[0]) }
        await assets.makeAvailable([1])
        await assets.failOldest(1, error: NSError(domain: NSCocoaErrorDomain, code: 513))
        _ = try await selection.value
        XCTAssertTrue(library.isComplete)
        XCTAssertTrue(library.failedTrackIDs.isEmpty)
    }

    func testFileArrivingJustAfterTerminalErrorResolvesSelectionWithoutAlert() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, availabilityPollInterval: .milliseconds(100), retryDelays: [])
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        let selection = Task { try await library.download(AlbumTrack.all[0]) }
        await assets.failOldest(1, error: NSError(domain: NSCocoaErrorDomain, code: 513))
        try await Task.sleep(for: .milliseconds(25))
        await assets.makeAvailable([1])
        _ = try await selection.value
        XCTAssertTrue(library.isComplete)
        XCTAssertTrue(library.failedTrackIDs.isEmpty)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(library.phase, .ready)
    }

    func testNewProgressResumesDownloadingStateAfterWaiting() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, stallTimeout: .milliseconds(250))
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { library.phase == .waiting }
        await assets.progress(1, 0.3)
        XCTAssertEqual(library.phase, .downloading)
        XCTAssertTrue(library.failedTrackIDs.isEmpty)
        await assets.finishOldest(1)
        try await eventually { library.isComplete }
    }

    func testGenuineFailureRemainsFailedWhileOtherDownloadsAreQuiet() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, stallTimeout: .milliseconds(250),
                                   availabilityPollInterval: .milliseconds(25), retryDelays: [])
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        await assets.failOldest(1)
        try await eventually { library.phase == .failed }
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(library.phase, .failed)
        XCTAssertEqual(library.failedTrackIDs, [1])
    }

    func testLateCompletionFromManuallyRetriedAttemptCannotCompleteRetry() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, stallTimeout: .milliseconds(250))
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { library.phase == .waiting }
        library.retry()
        try await eventually { await assets.requests[1] == 2 }
        await assets.finishOldest(1, markAvailable: false)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertFalse(library.isComplete)
        XCTAssertEqual(library.phase, .downloading)
        await assets.finishOldest(1)
        try await eventually { library.isComplete }
    }

    func testCancellingTrackSelectionDoesNotCancelAlbumPreparation() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client)
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        let selection = Task { try await library.download(AlbumTrack.all[0]) }
        try await Task.sleep(for: .milliseconds(20))
        selection.cancel()
        do { _ = try await selection.value; XCTFail("Selection should cancel") }
        catch is CancellationError { }
        XCTAssertEqual(library.phase, .downloading)
        await assets.finishOldest(1)
        try await eventually { library.isComplete }
    }

    func testSlowButProgressingDownloadsDoNotHitAnAbsoluteTimeLimit() async throws {
        let assets = ControlledMusicAssets(available: Set(2...9))
        let library = MusicLibrary(client: assets.client, stallTimeout: .seconds(1))
        defer { library.cancel() }
        library.prepareAlbum()
        try await eventually { await assets.requests[1] == 1 }
        for step in 1...8 {
            try await Task.sleep(for: .milliseconds(250))
            await assets.progress(1, Double(step) / 10)
            XCTAssertEqual(library.phase, .downloading)
        }
        await assets.finishOldest(1)
        try await eventually { library.isComplete }
    }
}

private actor ControlledMusicAssets {
    var available: Set<Int>
    var requests: [Int: Int] = [:]
    let checkDelay: Duration
    let audioURL: URL?
    private var pending: [Int: [CheckedContinuation<URL, Error>]] = [:]
    private var updates: [Int: @Sendable (Double) async -> Void] = [:]
    private var snapshots: [Int: @Sendable (MusicAssetSnapshot) async -> Void] = [:]

    func setSnapshot(_ value: MusicAssetSnapshot) async {
        for handler in snapshots.values { await handler(value) }
    }

    init(available: Set<Int>, checkDelay: Duration = .zero, audioURL: URL? = nil) {
        self.available = available
        self.checkDelay = checkDelay
        self.audioURL = audioURL
    }

    nonisolated var client: MusicAssetClient {
        MusicAssetClient(localAsset: { await self.localURL($0).map(MusicAudioAsset.fileURL) },
                         download: { .fileURL(try await self.download($0, progress: $1, snapshot: $2)) })
    }

    private func url(_ id: Int) -> URL { audioURL ?? URL(fileURLWithPath: String(format: "/tmp/track-%02d.m4a", id)) }

    private func localURL(_ track: AlbumTrack) async -> URL? {
        if checkDelay > .zero { try? await Task.sleep(for: checkDelay) }
        return available.contains(track.id) ? url(track.id) : nil
    }

    private func download(_ track: AlbumTrack, progress: @escaping @Sendable (Double) async -> Void,
                          snapshot: @escaping @Sendable (MusicAssetSnapshot) async -> Void) async throws -> URL {
        requests[track.id, default: 0] += 1
        updates[track.id] = progress
        snapshots[track.id] = snapshot
        return try await withCheckedThrowingContinuation { pending[track.id, default: []].append($0) }
    }

    func progress(_ id: Int, _ fraction: Double) async { await updates[id]?(fraction) }

    func makeAvailable(_ ids: Set<Int>) { available.formUnion(ids) }

    func finishOldest(_ id: Int, markAvailable: Bool = true) {
        guard var requests = pending[id], !requests.isEmpty else { return }
        let continuation = requests.removeFirst()
        pending[id] = requests
        if markAvailable { available.insert(id) }
        continuation.resume(returning: url(id))
    }

    func failOldest(_ id: Int, error: any Error = URLError(.notConnectedToInternet)) {
        guard var requests = pending[id], !requests.isEmpty else { return }
        let continuation = requests.removeFirst()
        pending[id] = requests
        continuation.resume(throwing: error)
    }

    func finishAll() {
        for requests in pending.values {
            for continuation in requests { continuation.resume(throwing: CancellationError()) }
        }
        pending = [:]
    }
}
