import SwiftUI

/// A passive layer: map gestures and numbered pins retain their existing actions.
struct MapLyricsView: View {
    let player: AlbumPlayer

    var body: some View {
        if let id = player.playingTrackID, player.controlTrackID == id, let lyrics = SynchronizedLyrics.album[id], !lyrics.cues.isEmpty {
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                LyricsLinesView(lyrics: lyrics, time: player.elapsedTime)
            }
            .id(id)
            .allowsHitTesting(false)
        }
    }
}

private struct LyricsLinesView: View {
    let lyrics: SynchronizedLyrics
    let time: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .largeTitle) private var lyricRowHeight = 72.0

    private var current: Int? { lyrics.cueIndex(at: time) }
    private let highlightedColor = Color(red: 128 / 255, green: 128 / 255, blue: 128 / 255)
    private let surroundingColor = Color.white

    var body: some View {
        GeometryReader { geometry in
            let lyricAnchor = UnitPoint(x: 0.5, y: max(0.15, 0.5 - lyricRowHeight / max(1, geometry.size.height)))
            ScrollViewReader { scroll in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(lyrics.cues) { cue in
                            let active = cue.id == current
                            Text(cue.text.isEmpty ? "…" : cue.text)
                                .font(.custom("HelveticaNeue-Bold", size: 32, relativeTo: .largeTitle))
                                .foregroundStyle(active && !cue.text.isEmpty ? highlightedColor : surroundingColor)
                                .blur(radius: active || reduceTransparency ? 0 : 1.2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 4)
                                .id(cue.id)
                                .accessibilityHidden(!active || cue.text.isEmpty)
                        }
                    }
                    .padding(.vertical, geometry.size.height / 2)
                    // Clear the full 48-point side-pin hit area plus a breathing gap.
                    .padding(.horizontal, 64)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(true)
                .onChange(of: current, initial: true) { _, index in
                    guard let index else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
                        scroll.scrollTo(index, anchor: lyricAnchor)
                    }
                }
                .onChange(of: geometry.size) { _, _ in
                    if let current { scroll.scrollTo(current, anchor: lyricAnchor) }
                }
            }
        }
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                  .init(color: .black, location: 0.18),
                                  .init(color: .black, location: 0.82),
                                  .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .clipped()
    }
}
