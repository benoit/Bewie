import BackgroundAssets
import Foundation
import Observation
import OSLog
import System

/// UI-facing download state. Asset-manager and file mapping work lives in the
/// client actor; a tap only reads the prepared audio cache on the main actor.
@MainActor
@Observable
final class MusicLibrary {
    enum Phase: Equatable { case idle, checking, downloading, waiting, failed, ready }
    private(set) var phase: Phase = .idle
    private(set) var availableAssets: [Int: MusicAudioAsset] = [:]
    private(set) var fractions: [Int: Double] = [:]
    private(set) var failedTrackIDs: Set<Int> = []

    @ObservationIgnored private let client: MusicAssetClient
    @ObservationIgnored private let stallTimeout: Duration
    @ObservationIgnored private let retryDelays: [Duration]
    @ObservationIgnored private var requestTokens: [Int: UUID] = [:]
    @ObservationIgnored private let availabilityPollInterval: Duration
    @ObservationIgnored private let logger = Logger(subsystem: "bewie.atelierindustriel.be", category: "MusicDownloads")
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var checkTask: Task<Void, Never>?
    @ObservationIgnored private var watchdogTask: Task<Void, Never>?
    @ObservationIgnored private var availabilityTask: Task<Void, Never>?
    @ObservationIgnored private var jobs: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var waiters: [Int: [UUID: CheckedContinuation<MusicAudioAsset, Error>]] = [:]
    @ObservationIgnored private var lastProgress = ContinuousClock.now

    init(client: MusicAssetClient = .live(), stallTimeout: Duration = .seconds(90),
         availabilityPollInterval: Duration = .seconds(2),
         retryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(10)]) {
        self.retryDelays = retryDelays
        self.client = client
        self.stallTimeout = stallTimeout
        self.availabilityPollInterval = availabilityPollInterval
    }

    nonisolated static func packID(for track: AlbumTrack) -> String {
        String(format: "bewie-track-%02d", track.id)
    }

    var isComplete: Bool { availableAssets.count == AlbumTrack.all.count }
    var readyCount: Int { availableAssets.count }
    var needsPreparation: Bool { phase != .idle && phase != .ready }
    var progress: Double {
        AlbumTrack.all.reduce(0) { $0 + (availableAssets[$1.id] != nil ? 1 : fractions[$1.id] ?? 0) }
            / Double(AlbumTrack.all.count)
    }

    /// Cached audio has already passed the background local-availability check.
    func localAsset(for track: AlbumTrack) -> MusicAudioAsset? { availableAssets[track.id] }

    func prepareAlbum() {
        if phase == .idle { beginAttempt() }
        else if phase == .failed { retry() }
    }

    /// Retry missing music only. Healthy transfers and prepared files are retained.
    func retry() {
        guard !isComplete else { finishAlbum(); return }
        guard phase != .idle else { beginAttempt(); return }
        guard checkTask == nil else { return }
        if phase == .waiting {
            for track in AlbumTrack.all where availableAssets[track.id] == nil {
                jobs.removeValue(forKey: track.id)?.cancel()
                requestTokens[track.id] = nil
            }
        }
        failedTrackIDs = []
        lastProgress = .now
        phase = .downloading
        if watchdogTask == nil { startWatchdog(generation: generation) }
        if availabilityTask == nil { startAvailabilityChecks(generation: generation) }
        for track in AlbumTrack.all where availableAssets[track.id] == nil {
            startJob(track, generation: generation)
        }
    }

    /// Selection and album prefetch share one job per pack. Cancelling a selected
    /// track removes its waiter without cancelling the album's system downloads.
    func download(_ track: AlbumTrack) async throws -> MusicAudioAsset {
        try Task.checkCancellation()
        if let asset = availableAssets[track.id] { return asset }
        if phase == .idle { beginAttempt() }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                waiters[track.id, default: [:]][id] = continuation
                if checkTask == nil { startJob(track, generation: generation) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let continuation = self?.waiters[track.id]?.removeValue(forKey: id) else { return }
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    private func beginAttempt() {
        invalidateAttempt()
        let attempt = generation
        phase = .checking
        failedTrackIDs = []
        lastProgress = .now
        startWatchdog(generation: attempt)
        checkTask = Task { [weak self, client] in
            var local: [Int: MusicAudioAsset] = [:]
            for track in AlbumTrack.all {
                let asset = await client.localAsset(track)
                guard !Task.isCancelled, let self, self.generation == attempt else { return }
                if let asset { local[track.id] = asset }
            }
            guard let self, self.generation == attempt, !Task.isCancelled else { return }
            self.availableAssets = local
            for track in AlbumTrack.all {
                self.fractions[track.id] = local[track.id] == nil ? 0 : 1
                if let asset = local[track.id] { self.finishWaiters(track.id, result: .success(asset)) }
            }
            self.checkTask = nil
            if self.isComplete { self.finishAlbum(); return }
            self.phase = .downloading
            self.lastProgress = .now
            self.startAvailabilityChecks(generation: attempt)
            for track in AlbumTrack.all where local[track.id] == nil {
                self.startJob(track, generation: attempt)
            }
        }
    }

    private func startJob(_ track: AlbumTrack, generation attempt: Int) {
        guard jobs[track.id] == nil, availableAssets[track.id] == nil else { return }
        jobs[track.id] = Task { [weak self, client, retryDelays] in
            var retryIndex = 0
            var confirmedFailure = false
            while !Task.isCancelled {
                let token = UUID()
                guard self?.generation == attempt else { return }
                self?.requestTokens[track.id] = token
                do {
                    if retryIndex > 0, let cached = await client.localAsset(track) {
                        guard let self, self.generation == attempt,
                              self.requestTokens[track.id] == token, !Task.isCancelled else { return }
                        self.acceptAvailableAsset(cached, trackID: track.id)
                        return
                    }
                    let asset = try await client.download(track, { [weak self] fraction in
                        await self?.recordProgress(fraction, trackID: track.id, generation: attempt, token: token)
                    }, { [weak self] snapshot in
                        await self?.recordSnapshot(snapshot, trackID: track.id, generation: attempt, token: token)
                    })
                    guard let self, self.generation == attempt,
                          self.requestTokens[track.id] == token, !Task.isCancelled else { return }
                    self.acceptAvailableAsset(asset, trackID: track.id)
                    return
                } catch {
                    guard let self, self.generation == attempt,
                          self.requestTokens[track.id] == token, !Task.isCancelled else { return }
                    let failure = MusicAssetFailure(error)
                    if failure.isRecoverable, retryIndex < retryDelays.count {
                        self.failedTrackIDs.remove(track.id)
                        if self.failedTrackIDs.isEmpty { self.phase = .downloading }
                        let delay = retryDelays[retryIndex]
                        retryIndex += 1
                        do { try await Task.sleep(for: delay) } catch { return }
                        continue
                    }
                    // A failed SDK waiter can race the system finishing the pack.
                    // Reconcile actual availability before surfacing a terminal error.
                    if let cached = await client.localAsset(track) {
                        guard self.generation == attempt, self.requestTokens[track.id] == token,
                              !Task.isCancelled else { return }
                        self.acceptAvailableAsset(cached, trackID: track.id)
                        return
                    }
                    do { try await Task.sleep(for: self.availabilityPollInterval) } catch { return }
                    guard self.generation == attempt, self.requestTokens[track.id] == token,
                          !Task.isCancelled else { return }
                    if let cached = await client.localAsset(track) {
                        guard self.generation == attempt, self.requestTokens[track.id] == token,
                              !Task.isCancelled else { return }
                        self.acceptAvailableAsset(cached, trackID: track.id)
                        return
                    }
                    guard self.generation == attempt, self.requestTokens[track.id] == token,
                          !Task.isCancelled else { return }
                    // Retry once even when Apple returns an opaque/unclassified
                    // error. A fresh request can read a pack that became usable
                    // immediately after the old SDK request failed. Known transient
                    // errors already exhausted their own bounded retry budget.
                    if !failure.isRecoverable, !confirmedFailure, !retryDelays.isEmpty {
                        confirmedFailure = true
                        continue
                    }
                    self.jobs[track.id] = nil
                    self.requestTokens[track.id] = nil
                    self.failedTrackIDs.insert(track.id)
                    self.phase = .failed
                    self.logger.error("Track \(track.id) download failed: \(failure.domain, privacy: .public) code \(failure.code)")
                    self.finishWaiters(track.id, result: .failure(error))
                    return
                }
            }
        }
    }

    private func recordProgress(_ value: Double, trackID: Int, generation attempt: Int, token: UUID) {
        guard generation == attempt, requestTokens[trackID] == token, value.isFinite else { return }
        // A pack is ready only after ensureLocalAvailability and direct file access,
        // never merely because the transfer reports 100%.
        let value = min(1, max(0, value))
        if value > fractions[trackID, default: 0] {
            fractions[trackID] = value
            lastProgress = .now
            if phase == .waiting { phase = .downloading }
        }
    }

    /// System-owned downloads may finish without delivering progress or returning
    /// from the original waiter. Reconcile actual files independently of both.
    private func startAvailabilityChecks(generation attempt: Int) {
        availabilityTask = Task { [weak self, client, availabilityPollInterval] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: availabilityPollInterval) } catch { return }
                for track in AlbumTrack.all {
                    guard !Task.isCancelled, let self, self.generation == attempt else { return }
                    guard self.availableAssets[track.id] == nil else { continue }
                    let asset = await client.localAsset(track)
                    guard !Task.isCancelled, self.generation == attempt else { return }
                    if let asset { self.acceptAvailableAsset(asset, trackID: track.id) }
                }
            }
        }
    }

    private func recordSnapshot(_ snapshot: MusicAssetSnapshot, trackID: Int, generation attempt: Int, token: UUID) {
        guard generation == attempt, requestTokens[trackID] == token, availableAssets[trackID] == nil else { return }
        // Status streams describe transfer attempts, not the outcome of the
        // current ensureLocalAvailability request. It may still succeed after a
        // failed status event. Only startJob's reconciled result rejects waiters.
        if snapshot.failure == nil, [.requestingPack, .downloading, .openingFile].contains(snapshot.stage),
           failedTrackIDs.remove(trackID) != nil, failedTrackIDs.isEmpty {
            phase = .downloading
        }
    }

    private func acceptAvailableAsset(_ asset: MusicAudioAsset, trackID: Int) {
        // Stop observing the original request; do not cancel Apple's transfer.
        jobs.removeValue(forKey: trackID)?.cancel()
        requestTokens[trackID] = nil
        availableAssets[trackID] = asset
        fractions[trackID] = 1
        failedTrackIDs.remove(trackID)
        lastProgress = .now
        finishWaiters(trackID, result: .success(asset))
        if isComplete { finishAlbum() }
        else if failedTrackIDs.isEmpty { phase = .downloading }
    }

    private func startWatchdog(generation attempt: Int) {
        watchdogTask = Task { [weak self, stallTimeout] in
            let interval = min(stallTimeout, .seconds(1))
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) } catch { return }
                guard let self, self.generation == attempt else { return }
                if self.lastProgress.duration(to: .now) >= stallTimeout, self.phase != .failed {
                    // Silence is not evidence of failure. Keep observing Apple,
                    // checking files and waiting for selected music to arrive.
                    self.phase = .waiting
                }
            }
        }
    }

    private func finishAlbum() {
        phase = .ready
        watchdogTask?.cancel()
        watchdogTask = nil
        availabilityTask?.cancel()
        availabilityTask = nil
    }

    private func finishWaiters(_ trackID: Int, result: Result<MusicAudioAsset, Error>) {
        let pending = waiters.removeValue(forKey: trackID) ?? [:]
        for continuation in pending.values { continuation.resume(with: result) }
    }

    private func invalidateAttempt(error: Error = CancellationError()) {
        generation &+= 1
        checkTask?.cancel()
        checkTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        availabilityTask?.cancel()
        availabilityTask = nil
        for job in jobs.values { job.cancel() }
        jobs = [:]
        requestTokens = [:]
        let pending = waiters
        waiters = [:]
        for requests in pending.values {
            for continuation in requests.values { continuation.resume(throwing: error) }
        }
    }

    /// Ends UI observation only; Apple continues any system-owned pack transfers.
    func cancel() {
        invalidateAttempt()
        phase = .idle
    }
}

/// Test/local providers may supply ordinary files; Apple packs provide mapped data.
/// AVAudioPlayer accepts both without re-encoding the original lossless audio.
enum MusicAudioAsset: Sendable {
    case fileURL(URL)
    case data(Data)
}

enum MusicDownloadError: Error { case missingFile }

/// The injected client permits slow, failing and stalled download tests without
/// depending on Simulator asset delivery or a warm on-device music cache.
struct MusicAssetClient: Sendable {
    var localAsset: @Sendable (AlbumTrack) async -> MusicAudioAsset?
    var download: @Sendable (AlbumTrack, @escaping @Sendable (Double) async -> Void,
                             @escaping @Sendable (MusicAssetSnapshot) async -> Void) async throws -> MusicAudioAsset

    static func live() -> Self {
        let worker = MusicAssetWorker()
        return Self(localAsset: { await worker.localAsset(for: $0) },
                    download: { try await worker.download($0, progress: $1, snapshot: $2) })
    }
}

enum MusicAssetStage: String, Sendable {
    case requestingPack = "requesting-pack", downloading, paused
    case openingFile = "opening-file", failed
}

struct MusicAssetFailure: Sendable {
    let domain: String
    let code: Int
    let underlying: [MusicAssetErrorCode]

    init(_ error: any Error) {
        let root = error as NSError
        domain = root.domain
        code = root.code
        var causes: [MusicAssetErrorCode] = []
        var next = root.userInfo[NSUnderlyingErrorKey] as? NSError
        var seen = Set([ObjectIdentifier(root)])
        while let cause = next, causes.count < 4, seen.insert(ObjectIdentifier(cause)).inserted {
            causes.append(.init(domain: cause.domain, code: cause.code))
            next = cause.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        underlying = causes
    }

    var isRecoverable: Bool {
        Self.isRecoverable(domain: domain, code: code) || underlying.contains {
            Self.isRecoverable(domain: $0.domain, code: $0.code)
        }
    }

    private static func isRecoverable(domain: String, code: Int) -> Bool {
        if domain == "XPC.XPCRichError" { return true }
        // Foundation XPC connection interrupted / invalidated.
        if domain == NSCocoaErrorDomain, [4097, 4099].contains(code) { return true }
        return domain == NSURLErrorDomain && [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost].contains(code)
    }
}

struct MusicAssetErrorCode: Sendable { let domain: String; let code: Int }

struct MusicAssetSnapshot: Sendable {
    let stage: MusicAssetStage
    var failure: MusicAssetFailure? = nil
}

/// Pack access and file mapping must not run on the UI thread. Read from the
/// explicit pack rather than asking Apple to materialize a shared virtual URL.
private actor MusicAssetWorker {
    private var requests: [Int: UUID] = [:]

    func localAsset(for track: AlbumTrack) async -> MusicAudioAsset? {
        let manager = AssetPackManager.shared
        let id = MusicLibrary.packID(for: track)
        let downloaded: Bool
        if #available(iOS 26.4, *) {
            downloaded = manager.assetPackIsAvailableLocally(withID: id)
        } else {
            downloaded = (try? await manager.status(ofAssetPackWithID: id).contains(.downloaded)) ?? false
        }
        guard downloaded else { return nil }
        return try? readAsset(for: track)
    }

    func download(_ track: AlbumTrack, progress: @escaping @Sendable (Double) async -> Void,
                  snapshot: @escaping @Sendable (MusicAssetSnapshot) async -> Void) async throws -> MusicAudioAsset {
        let manager = AssetPackManager.shared
        let request = UUID()
        requests[track.id] = request
        await snapshot(.init(stage: .requestingPack))
        let monitor = Task {
            for await update in manager.statusUpdates(forAssetPackWithID: MusicLibrary.packID(for: track)) {
                guard !Task.isCancelled, requests[track.id] == request else { return }
                switch update {
                case .began:
                    await snapshot(.init(stage: .downloading))
                case .paused:
                    await snapshot(.init(stage: .paused))
                case .downloading(_, let value):
                    await snapshot(.init(stage: .downloading))
                    await progress(value.fractionCompleted)
                case .failed(_, let error):
                    await snapshot(.init(stage: .failed, failure: MusicAssetFailure(error)))
                case .finished:
                    await snapshot(.init(stage: .openingFile))
                @unknown default: break
                }
            }
        }
        defer { monitor.cancel() }
        return try await withTaskCancellationHandler {
            do {
                let pack = try await manager.assetPack(withID: MusicLibrary.packID(for: track))
                try Task.checkCancellation()
                if requests[track.id] == request { await snapshot(.init(stage: .downloading)) }
                try await manager.ensureLocalAvailability(of: pack)
                try Task.checkCancellation()
                if requests[track.id] == request { await snapshot(.init(stage: .openingFile)) }
                let asset = try readAsset(for: track)
                return asset
            } catch {
                if !Task.isCancelled, requests[track.id] == request {
                    await snapshot(.init(stage: .failed, failure: MusicAssetFailure(error)))
                }
                throw error
            }
        } onCancel: {
            monitor.cancel()
        }
    }

    private func readAsset(for track: AlbumTrack) throws -> MusicAudioAsset {
        // Read this pack directly. No virtual URL or shared-directory materialization.
        // Mapping keeps lossless bytes in Apple's files, without a second disk cache.
        let data = try AssetPackManager.shared.contents(
            at: FilePath("Audio/\(track.filename)"),
            searchingInAssetPackWithID: MusicLibrary.packID(for: track),
            options: .alwaysMapped)
        guard !data.isEmpty else { throw MusicDownloadError.missingFile }
        return .data(data)
    }
}
