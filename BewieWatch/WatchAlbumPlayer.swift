import AVFoundation
import MediaPlayer
import Observation

/// Local AAC playback belongs to the watch; no phone, guide or enrollment dependency.
@MainActor
@Observable
final class WatchAlbumPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var track: AlbumTrack
    private(set) var isPlaying = false
    private(set) var isActivating = false
    var errorMessage: String?

    @ObservationIgnored private var audio: AVAudioPlayer?
    typealias SessionActivation = (@escaping @Sendable (Bool, Error?) -> Void) throws -> Void

    @ObservationIgnored private let session = AVAudioSession.sharedInstance()
    @ObservationIgnored private let activateSession: SessionActivation
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var commands: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var resumesAfterInterruption = false

    init(defaults: UserDefaults = .standard,
         activateSession: @escaping SessionActivation = { completion in
             let session = AVAudioSession.sharedInstance()
             try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
             session.activate(options: [], completionHandler: completion)
         }) {
        self.defaults = defaults
        self.activateSession = activateSession
        let saved = defaults.integer(forKey: "watch.trackID")
        track = AlbumTrack.all.first { $0.id == saved } ?? AlbumTrack.all[0]
        super.init()
        observeAudioSession()
        registerCommands()
    }

    func togglePlayback() {
        // Repeated Play taps must not cancel the asynchronous route activation.
        // An explicit Pause command can still cancel a pending activation.
        guard !isActivating else { return }
        if isPlaying { pause() } else { play() }
    }

    func play() {
        guard !isPlaying, !isActivating else { return }
        errorMessage = nil
        do {
            if audio == nil { try prepareAudio() }
            generation += 1
            let request = generation
            isActivating = true
            try activateSession { [weak self] success, error in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == request else { return }
                    self.isActivating = false
                    guard success else {
                        self.fail(error?.localizedDescription ?? String(localized: "Connect an audio output and try again."))
                        return
                    }
                    guard self.audio?.play() == true else {
                        self.fail(String(localized: "The song could not be played. Please try again."))
                        return
                    }
                    self.isPlaying = true
                    self.updateNowPlaying()
                }
            }
        } catch { fail(error.localizedDescription) }
    }

    func pause() {
        generation += 1
        isActivating = false
        resumesAfterInterruption = false
        audio?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func previous() {
        // Match the public iPhone player's three-second Back rule.
        if let audio, audio.currentTime > 3 {
            audio.currentTime = 0
            updateNowPlaying()
        } else {
            navigate(.previous)
        }
    }

    func next() { navigate(.next) }

    private func navigate(_ direction: TrackDirection) {
        guard let destination = AlbumTrack.adjacent(to: track.id, direction: direction) else { return }
        pause()
        audio?.stop()
        audio = nil
        track = destination
        defaults.set(track.id, forKey: "watch.trackID")
        updateNowPlaying()
        play()
    }

    private func prepareAudio() throws {
        let name = (track.filename as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let prepared = try AVAudioPlayer(contentsOf: url)
        prepared.delegate = self
        audio = prepared
    }

    private func fail(_ message: String) {
        pause()
        errorMessage = message
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, player === self.audio else { return }
            if flag { self.next() }
            else { self.fail(String(localized: "The song could not be played. Please try again.")) }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, player === self.audio else { return }
            self.fail(error?.localizedDescription ?? String(localized: "The song could not be played. Please try again."))
        }
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: session, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    let resume = self.isPlaying
                    self.pause()
                    self.resumesAfterInterruption = resume
                } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                    let resume = self.resumesAfterInterruption &&
                        AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                    self.resumesAfterInterruption = false
                    if resume { self.play() }
                }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: session, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in self?.pause() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: session, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
                self?.audio = nil
            }
        })
    }

    private func registerCommands() {
        let remote = MPRemoteCommandCenter.shared()
        register(remote.playCommand) { $0.play() }
        register(remote.pauseCommand) { $0.pause() }
        register(remote.togglePlayPauseCommand) { $0.togglePlayback() }
        register(remote.previousTrackCommand) { $0.previous() }
        register(remote.nextTrackCommand) { $0.next() }
    }

    private func register(_ command: MPRemoteCommand, action: @escaping @MainActor (WatchAlbumPlayer) -> Void) {
        command.isEnabled = true
        let token = command.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                action(self)
            }
            return .success
        }
        commands.append((command, token))
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyAlbumTitle: "Every Room Is Borrowed",
            MPMediaItemPropertyAlbumTrackNumber: track.id,
            MPMediaItemPropertyAlbumTrackCount: AlbumTrack.all.count,
            MPMediaItemPropertyPlaybackDuration: audio?.duration ?? 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audio?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for (command, token) in commands { command.removeTarget(token) }
    }
}
