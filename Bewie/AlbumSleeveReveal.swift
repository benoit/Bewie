import SwiftUI

/// The same asset and left/bottom anchors used by the system launch storyboard.
enum AlbumSleeveLayout {
    static let artworkSize = CGSize(width: 2376, height: 2400)

    static func frame(in viewport: CGSize, progress: CGFloat) -> CGRect {
        let scale = max(viewport.width / artworkSize.width, viewport.height / artworkSize.height)
        let size = CGSize(width: artworkSize.width * scale, height: artworkSize.height * scale)
        return CGRect(x: -size.width * min(max(progress, 0), 1),
                      y: viewport.height - size.height, width: size.width, height: size.height)
    }
}

struct AlbumSleeveArtwork: View {
    let size: CGSize
    var progress: CGFloat = 0

    var body: some View {
        let frame = AlbumSleeveLayout.frame(in: size, progress: progress)
        Image("LaunchAlbumCover")
            .resizable()
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

struct AlbumSleeveReveal: View {
    let size: CGSize
    @Binding var isPresented: Bool
    var reduceMotion: Bool
    var isActive: Bool
    var isMapReady = true
    @State private var progress: CGFloat = 0

    var body: some View {
        AlbumSleeveArtwork(size: size, progress: progress)
            .task(id: isActive && isMapReady) {
                // Give SwiftUI its first frame at the exact system-launch crop.
                // Nothing here depends on map tiles, audio or enrollment downloads.
                guard isActive, isMapReady, isPresented else { return }
                guard !reduceMotion else {
                    isPresented = false
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(120))
                } catch { return }
                guard !Task.isCancelled, isPresented else { return }
                withAnimation(.easeInOut(duration: 3.5)) {
                    progress = 1
                }
                // Finish on a bounded clock even if rendering is interrupted by
                // backgrounding, rather than waiting on an animation callback.
                do {
                    try await Task.sleep(for: .seconds(3.5))
                } catch { return }
                guard !Task.isCancelled else { return }
                isPresented = false
            }
            .onChange(of: isActive) { _, active in
                if !active, progress > 0 {
                    isPresented = false
                }
            }
    }
}
