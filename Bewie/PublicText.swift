import Foundation

/// Dedicated table: private guide strings never participate in public localization.
/// en.lproj contains US English; en-GB.lproj contains UK English.
/// iOS resolves app language preferences, with US English as the fallback.
enum PublicText: String, CaseIterable {
    case coordinates
    case playbackPosition
    case previousTrack
    case nextTrack
    case pause
    case resume
    case vinyl
    case closePlayer
    case musicUnavailable
    case retry
    case close
    case trackLabel
    case playing
    case paused
    case stopped
    case openControls
    case playAndLocate
    case downloadingTrack
    case airPlayOutput
    case audioUnavailable
    case trackStartFailed
    case downloadFailed
    case playbackUnavailable
    case playbackInterrupted
    case playbackStopped
    case trackReadFailed

    var text: String { localized() }

    func localized(in bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: rawValue, value: nil, table: "Public")
    }

    func formatted(_ arguments: CVarArg...) -> String {
        String(format: text, locale: Locale.current, arguments: arguments)
    }
}
