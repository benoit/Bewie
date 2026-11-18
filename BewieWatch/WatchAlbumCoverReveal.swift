import SwiftUI

/// A tap-gated Watch presentation of the same artwork and slide used on iPhone.
struct WatchAlbumCoverReveal: View {
    let size: CGSize
    @Binding var isPresented: Bool
    let reduceMotion: Bool
    let isActive: Bool
    @State private var isSliding = false
    @State private var progress: CGFloat = 0

    var body: some View {
        Button {
            guard isActive, !isSliding else { return }
            if reduceMotion {
                isPresented = false
            } else {
                isSliding = true
            }
        } label: {
            ZStack {
                artwork
                // The artwork ignores touches; this owns the full-screen tap.
                Color.clear
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(CoverButtonStyle())
        .disabled(isSliding)
        .accessibilityLabel(Text("Album cover"))
        .accessibilityHint(Text("Tap to reveal the player"))
        .accessibilityIdentifier("watch.openingSleeve")
        .task(id: isActive && isSliding) {
            guard isActive, isSliding else { return }
            withAnimation(.easeInOut(duration: 3.5)) {
                progress = 1
            }
            do { try await Task.sleep(for: .seconds(3.5)) }
            catch { return }
            guard !Task.isCancelled else { return }
            isPresented = false
        }
    }

    private var artwork: some View {
        let frame = AlbumSleeveLayout.frame(in: size, progress: progress)
        let topInset: CGFloat = 12
        let skyBlend: CGFloat = 4
        return ZStack(alignment: .topLeading) {
            // Keep the top edge covered with the same sky while lowering the
            // image (including its printed title) beneath the system clock.
            Image("LaunchAlbumCover")
                .resizable()
                .frame(width: frame.width, height: frame.height)
                .frame(height: topInset + skyBlend, alignment: .top)
                .clipped()
            Image("LaunchAlbumCover")
                .resizable()
                .frame(width: frame.width, height: frame.height)
                .mask {
                    VStack(spacing: 0) {
                        // Hide the image's thin original top border at the join.
                        Color.clear.frame(height: 1)
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: skyBlend - 1)
                        Color.black
                    }
                }
                .offset(y: topInset)
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .position(x: frame.midX, y: frame.midY)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

}

private struct CoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
