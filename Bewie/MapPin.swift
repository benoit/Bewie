import SwiftUI

/// The stem, anchor, head and controls share one local coordinate system and
/// one map position. No separately rendered layer can drift away from the head.
struct MapPin: View {
    let track: AlbumTrack
    let selected: Bool
    let playing: Bool
    let error: String?
    let anchorOffset: CGSize
    let showsAnchor: Bool
    let onSelect: () -> Void
    let playbackProgress: () -> Double
    var downloading = false

    var body: some View {
        ZStack {
            Button(action: onSelect) {
                head
                .frame(width: 48, height: 48)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PublicText.trackLabel.formatted(track.id, track.title))
            .accessibilityValue(error ?? (downloading ? PublicText.downloadingTrack.text : playing ? PublicText.playing.text : selected ? PublicText.paused.text : PublicText.stopped.text))
            .accessibilityHint(playing ? PublicText.openControls.text : PublicText.playAndLocate.text)
            .accessibilityIdentifier("track-pin-\(track.id)")
            .sensoryFeedback(.selection, trigger: playing)


        }
        .frame(width: 48, height: 48)
        .background {
            ZStack {
                PinStem(anchorOffset: anchorOffset)
                    .stroke(BewiePalette.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                if showsAnchor {
                    Circle().fill(BewiePalette.orange)
                        .frame(width: 4, height: 4)
                        .offset(anchorOffset)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var head: some View {
        ZStack {
            if selected {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    Circle()
                        .trim(from: 0, to: playbackProgress())
                        .stroke(BewiePalette.orange.opacity(0.75), lineWidth: 1.5)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 42.5, height: 42.5)
                }
            }
            Circle().fill(BewiePalette.orange)
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            Text(String(track.id))
                .font(.custom("HelveticaNeue-Medium", fixedSize: 17))
                .foregroundStyle(BewiePalette.ink)
            if playing {
                Circle().fill(BewiePalette.ink)
                    .frame(width: 3, height: 3).offset(y: 12)
            }
        }
        .accessibilityHidden(true)
    }

}

struct PinStem: Shape {
    let anchorOffset: CGSize

    func path(in rect: CGRect) -> Path {
        Path { path in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + anchorOffset.width, y: center.y + anchorOffset.height))
        }
    }
}

