import SwiftUI

/// Matches the native playback track while the selected audio is downloading.
struct MusicLoadingBar: View {
    let actualProgress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var highestReported: Double = 0

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: reduceMotion ? 0.5 : 1.0 / 30)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let fraction = max(highestReported, actualProgress.isFinite ? actualProgress : 0)
            let presentation = DownloadBarProgress.value(actual: fraction, elapsed: elapsed)
            GeometryReader { geometry in
                let width = geometry.size.width * presentation
                let segment = min(18, max(3, width * 0.08))
                let movement = reduceMotion ? 0 : (1 - cos(elapsed * .pi / 2)) / 2
                ZStack(alignment: .leading) {
                    Capsule().fill(BewiePalette.ink.opacity(0.10))
                    Capsule()
                        .fill(BewiePalette.orange.opacity(0.55))
                        .frame(width: width)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(BewiePalette.orange)
                                .frame(width: segment)
                                .offset(x: max(0, width - segment) * movement)
                        }
                        .clipShape(Capsule())
                }
            }
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PublicText.downloadingTrack.text)
        .accessibilityValue(min(0.99, actualProgress)
            .formatted(.percent.precision(.fractionLength(0))))
        .accessibilityIdentifier("track-download-progress")
        .onChange(of: actualProgress, initial: true) { _, value in
            if value.isFinite { highestReported = max(highestReported, value) }
        }
    }
}

/// Presentation only: gentle estimated advance never declares an asset ready.
/// The moving orange segment remains active even when the estimate reaches its cap.
struct DownloadBarProgress {
    private(set) var value: Double = 0.02

    static func value(actual: Double, elapsed: TimeInterval) -> Double {
        var progress = Self()
        progress.advance(actual: actual, elapsed: elapsed)
        return progress.value
    }

    mutating func advance(actual: Double, elapsed: TimeInterval) {
        let reported = actual.isFinite ? min(0.96, max(0, actual)) : 0
        let floor = max(value, reported)
        value = floor + (0.96 - floor) * (1 - exp(-max(0, elapsed) / 150))
    }
}
