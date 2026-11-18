import AVFoundation
import Foundation
import Observation
import MediaPlayer

@MainActor
@Observable
final class AlbumPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingTrackID: Int?
    private(set) var isPlaying = false
    private(set) var errorMessage: String?
    private(set) var failedTrackID: Int?
    private(set) var automaticAdvanceCount = 0
    private(set) var remoteNavigationCount = 0
    private(set) var remoteRequestedTrackID: Int?
    private(set) var selectedTrackID: Int?
    var controlTrackID: Int? { selectedTrackID ?? loadingTrackID ?? playingTrackID }
    var isControlTrackPlaying: Bool { isPlaying && controlTrackID == playingTrackID }
    private(set) var loadingTrackID: Int?
    var downloadProgress: Double? {
        guard let loadingTrackID else { return nil }
        return library.fractions[loadingTrackID]
    }
    @ObservationIgnored let library: MusicLibrary
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var downloadGeneration = 0
    @ObservationIgnored private var nowPlaying: SystemPlayback?


    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored private var preparedNext: (id: Int, player: AVAudioPlayer)?
    @ObservationIgnored private let audioDownloadProvider: ((AlbumTrack) async throws -> URL)?
    @ObservationIgnored private var pendingAutomaticTrackID: Int?
    @ObservationIgnored private let audioURLProvider: ((AlbumTrack) -> URL?)?
    @ObservationIgnored private var resumeAfterInterruption = false
    @ObservationIgnored private let notifications = AudioNotificationBag()

    init(audioURLProvider: ((AlbumTrack) -> URL?)? = nil,
         audioDownloadProvider: ((AlbumTrack) async throws -> URL)? = nil,
         library: MusicLibrary? = nil) {
        self.library = library ?? MusicLibrary()
        self.audioURLProvider = audioURLProvider
        self.audioDownloadProvider = audioDownloadProvider
        super.init()
        observeAudioSession()
        // Test audio providers never take ownership of system playback controls.
        if audioURLProvider == nil {
            nowPlaying = SystemPlayback(player: self)
        }
    }

    /// Select or toggle a track; the map handles taps on the playing pin separately.
    func select(_ track: AlbumTrack) {
        selectedTrackID = track.id
        cancelPendingDownload()
        pendingAutomaticTrackID = nil
        errorMessage = nil
        failedTrackID = nil
        resumeAfterInterruption = false

        if playingTrackID == track.id, let audioPlayer {
            if isPlaying {
                stop()
            } else {
                start(audioPlayer)
            }
            return
        }

        guard let asset = audioAsset(for: track) else {
            if audioURLProvider != nil && audioDownloadProvider == nil {
                errorMessage = PublicText.audioUnavailable.formatted(track.title)
                failedTrackID = track.id
            } else {
                requestDownload(track)
            }
            return
        }
        play(track, asset: asset)
    }

    private func play(_ track: AlbumTrack, asset: MusicAudioAsset) {
        errorMessage = nil
        failedTrackID = nil
        defer { refreshSystemPlayback() }
        do {
            let nextPlayer: AVAudioPlayer
            if let preparedNext, preparedNext.id == track.id {
                nextPlayer = preparedNext.player
            } else {
                nextPlayer = try Self.makeAudioPlayer(asset)
            }
            preparedNext = nil
            nextPlayer.delegate = self
            nextPlayer.prepareToPlay()
            try activateAudioSession()

            audioPlayer?.stop()
            audioPlayer = nextPlayer
            playingTrackID = track.id
            isPlaying = nextPlayer.play()
            if !isPlaying {
                errorMessage = PublicText.trackStartFailed.text
                failedTrackID = track.id
            } else {
                prepareNextTrack(after: track)
                if pendingAutomaticTrackID == track.id {
                    pendingAutomaticTrackID = nil
                    automaticAdvanceCount &+= 1
                }
            }
        } catch {
            errorMessage = PublicText.trackStartFailed.text
            failedTrackID = track.id
        }
    }

    private func cancelPendingDownload() {
        downloadGeneration &+= 1
        downloadTask?.cancel()
        downloadTask = nil
        loadingTrackID = nil
    }

    private func requestDownload(_ track: AlbumTrack) {
        loadingTrackID = track.id
        let generation = downloadGeneration
        downloadTask = Task { [weak self, library, audioDownloadProvider] in
            do {
                let asset: MusicAudioAsset
                if let audioDownloadProvider { asset = .fileURL(try await audioDownloadProvider(track)) }
                else { asset = try await library.download(track) }
                guard let self, !Task.isCancelled, self.downloadGeneration == generation else { return }
                self.cancelPendingDownload()
                self.play(track, asset: asset)
            } catch {
                guard let self, !Task.isCancelled, self.downloadGeneration == generation else { return }
                self.cancelPendingDownload()
                self.errorMessage = PublicText.downloadFailed.formatted(track.title)
                self.failedTrackID = track.id
            }
        }
    }

    func prefetchMusic() {
        guard audioURLProvider == nil else { return }
        library.prepareAlbum()
    }

    func dismissError() { errorMessage = nil }

    /// Return the controls to the audible track without toggling it off.
    func focusPlayingTrack() {
        guard isPlaying, let playingTrackID else { return }
        cancelPendingDownload()
        selectedTrackID = playingTrackID
        pendingAutomaticTrackID = nil
        failedTrackID = nil
        errorMessage = nil
    }

    /// Standard back-button behavior; seeking keeps the current playback state.
    @discardableResult
    func restartCurrentTrackIfPastIntro() -> Bool {
        guard loadingTrackID == nil, controlTrackID == playingTrackID,
              audioPlayer != nil, elapsedTime > 3 else { return false }
        seek(to: 0)
        return true
    }

    func navigateFromSystem(_ direction: TrackDirection) {
        if direction == .previous, restartCurrentTrackIfPastIntro() { return }
        guard let id = controlTrackID,
              let track = AlbumTrack.adjacent(to: id, direction: direction) else { return }
        if track.id == playingTrackID && isPlaying {
            focusPlayingTrack()
            seek(to: 0)
        }
        else { select(track) }
        remoteRequestedTrackID = track.id
        remoteNavigationCount &+= 1
    }

    func refreshSystemPlayback() { nowPlaying?.update() }

    var elapsedTime: TimeInterval { audioPlayer?.currentTime ?? 0 }
    var duration: TimeInterval { audioPlayer?.duration ?? 0 }
    var playbackProgress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsedTime / duration))
    }

    func togglePlayback() {
        guard loadingTrackID == nil, let id = controlTrackID,
              let track = AlbumTrack.all.first(where: { $0.id == id }) else { return }
        if isControlTrackPlaying { pause() } else { select(track) }
    }

    func seek(to time: TimeInterval) {
        guard time.isFinite, let audioPlayer else { return }
        audioPlayer.currentTime = min(max(0, time), max(0, audioPlayer.duration - 0.01))
        refreshSystemPlayback()
    }

    func stop() {
        defer { refreshSystemPlayback() }
        pendingAutomaticTrackID = nil
        cancelPendingDownload()
        audioPlayer?.stop()
        audioPlayer = nil
        preparedNext = nil
        playingTrackID = nil
        selectedTrackID = nil
        isPlaying = false
        resumeAfterInterruption = false
        errorMessage = nil
        failedTrackID = nil
        deactivateAudioSession()
    }

    func pause() {
        defer { refreshSystemPlayback() }
        cancelPendingDownload()
        pendingAutomaticTrackID = nil
        audioPlayer?.pause()
        isPlaying = false
        resumeAfterInterruption = false
        deactivateAudioSession()
    }

    private func start(_ player: AVAudioPlayer) {
        defer { refreshSystemPlayback() }
        do {
            try activateAudioSession()
            isPlaying = player.play()
            if !isPlaying {
                errorMessage = PublicText.trackStartFailed.text
                failedTrackID = playingTrackID
            }
        } catch {
            isPlaying = false
            errorMessage = PublicText.playbackUnavailable.text
            failedTrackID = playingTrackID
        }
    }

    private func audioAsset(for track: AlbumTrack) -> MusicAudioAsset? {
        if let audioURLProvider { return audioURLProvider(track).map(MusicAudioAsset.fileURL) }
        return library.localAsset(for: track)
    }

    private static func makeAudioPlayer(_ asset: MusicAudioAsset) throws -> AVAudioPlayer {
        switch asset {
        case .fileURL(let url): return try AVAudioPlayer(contentsOf: url)
        case .data(let data): return try AVAudioPlayer(data: data)
        }
    }

    /// Decode the next local file while this one plays; keep the audio session
    /// active across the album boundary as well as between individual tracks.
    private func prepareNextTrack(after track: AlbumTrack) {
        guard let next = AlbumTrack.adjacent(to: track.id, direction: .next),
              let asset = audioAsset(for: next),
              let player = try? Self.makeAudioPlayer(asset) else { return }
        player.delegate = self
        if player.prepareToPlay() { preparedNext = (next.id, player) }
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
        try session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        notifications.tokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                self?.handleInterruption(type: type, options: options)
            }
        })

        notifications.tokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in
                self?.pause()
            }
        })

        notifications.tokens.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.failedTrackID = self.playingTrackID
                self.audioPlayer = nil
                self.preparedNext = nil
                self.playingTrackID = nil
                self.isPlaying = false
                self.resumeAfterInterruption = false
                self.errorMessage = PublicText.playbackInterrupted.text
                self.refreshSystemPlayback()
            }
        })
    }

    private func handleInterruption(type: UInt?, options: UInt) {
        defer { refreshSystemPlayback() }
        guard let type, let interruption = AVAudioSession.InterruptionType(rawValue: type) else { return }
        switch interruption {
        case .began:
            cancelPendingDownload()
            pendingAutomaticTrackID = nil
            resumeAfterInterruption = isPlaying
            audioPlayer?.pause()
            isPlaying = false
        case .ended:
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            if resumeAfterInterruption, shouldResume, let audioPlayer {
                start(audioPlayer)
            }
            resumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPlayer = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let currentPlayer = self.audioPlayer,
                  ObjectIdentifier(currentPlayer) == finishedPlayer,
                  self.isPlaying, !currentPlayer.isPlaying else { return }
            defer { self.refreshSystemPlayback() }
            self.isPlaying = false
            currentPlayer.currentTime = 0
            self.resumeAfterInterruption = false
            if flag, let trackID = self.playingTrackID,
               let next = AlbumTrack.adjacent(to: trackID, direction: .next) {
                self.select(next)
                if self.isPlaying, self.playingTrackID == next.id {
                    self.automaticAdvanceCount &+= 1
                    return
                }
                if self.loadingTrackID == next.id { self.pendingAutomaticTrackID = next.id }
            }
            if !flag {
                self.errorMessage = PublicText.playbackStopped.text
                self.failedTrackID = self.playingTrackID
            }
            self.deactivateAudioSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let failedPlayer = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let currentPlayer = self.audioPlayer,
                  ObjectIdentifier(currentPlayer) == failedPlayer else { return }
            currentPlayer.stop()
            self.failedTrackID = self.playingTrackID
            self.audioPlayer = nil
            self.preparedNext = nil
            self.playingTrackID = nil
            self.isPlaying = false
            self.resumeAfterInterruption = false
            self.errorMessage = PublicText.trackReadFailed.text
            self.deactivateAudioSession()
            self.refreshSystemPlayback()
        }
    }
}

/// Owns the observer tokens and unregisters them when the player is released.
/// Tokens are created on the main actor; deinit only passes them to NotificationCenter.
private final class AudioNotificationBag: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []

    deinit {
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
