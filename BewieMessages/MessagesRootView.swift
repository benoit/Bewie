import AVFoundation
import Combine
import SwiftUI

struct MessagesRootView: View {
    let expand: () -> Void
    let insertSong: (AlbumTrack, String) async throws -> Void
    let insertLink: () async throws -> Void
    @State private var selectedTrack: AlbumTrack?
    @State private var isAddingLink = false
    @State private var error: String?
    @State private var status: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let selectedTrack {
                MessagesSongView(track: selectedTrack, insert: insertSong) {
                    self.selectedTrack = nil
                    status = "Added to message"
                }
                .id(selectedTrack.id)
            } else {
                picker
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(MessagesStyle.paper.ignoresSafeArea())
        .foregroundStyle(MessagesStyle.ink)
        .preferredColorScheme(.light)
        .alert("Bewie", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var header: some View {
        HStack {
            if selectedTrack != nil {
                Button {
                    selectedTrack = nil
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back to songs")
            } else { Color.clear.frame(width: 44, height: 44) }
            Spacer()
            HStack(spacing: 7) {
                Image("PearlPin").resizable().scaledToFit().frame(width: 25, height: 25)
                Text("Bewie").font(.custom("HelveticaNeue-Medium", size: 18))
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .buttonStyle(.plain)
    }

    private var picker: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(MessagesCatalog.tracks) { track in
                    Button {
                        status = nil
                        selectedTrack = track
                        expand()
                    } label: {
                        HStack(spacing: 14) {
                            Text(String(track.id))
                                .font(.custom("HelveticaNeue-Medium", size: 13))
                                .frame(width: 28, height: 28)
                                .background(MessagesStyle.orange, in: Circle())
                            Text(track.title).font(MessagesStyle.controlFont)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.system(size: 11))
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("\(track.id). \(track.title)")
                    Divider().overlay(MessagesStyle.ink.opacity(0.08))
                }
                if MessagesCatalog.appURL != nil {
                    Button {
                        isAddingLink = true
                        Task { @MainActor in
                            defer { isAddingLink = false }
                            do { try await insertLink(); status = "App link added to message" }
                            catch { self.error = error.localizedDescription }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "link").frame(width: 28)
                            Text("Send app link").font(MessagesStyle.controlFont)
                            Spacer()
                            if isAddingLink { ProgressView() }
                            else { Image(systemName: "arrow.up.right").font(.system(size: 11)) }
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .disabled(isAddingLink)
                }
                if let status {
                    Text(status).font(MessagesStyle.controlFont).foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(.horizontal, 22)
        }
        .buttonStyle(.plain)
    }
}

private struct MessagesSongView: View {
    let track: AlbumTrack
    let insert: (AlbumTrack, String) async throws -> Void
    let added: () -> Void
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var note = ""
    @State private var isInserting = false
    @State private var error: String?
    @State private var isLoading = true
    @State private var downloadProgress = 0.0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                preview
                HStack(spacing: 12) {
                    TextField("Add a note…", text: $note, axis: .vertical)
                        .font(MessagesStyle.controlFont)
                        .lineLimit(1...3)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) { Rectangle().fill(MessagesStyle.ink.opacity(0.12)).frame(height: 1) }
                        .onChange(of: note) { _, value in
                            if value.count > 200 { note = String(value.prefix(200)) }
                        }
                        .accessibilityLabel("Optional note")
                    Button {
                        player?.pause()
                        isPlaying = false
                        isInserting = true
                        Task { @MainActor in
                            defer { isInserting = false }
                            do { try await insert(track, note); added() }
                            catch { self.error = error.localizedDescription }
                        }
                    } label: {
                        Group {
                            if isInserting { ProgressView().tint(MessagesStyle.ink) }
                            else { Image(systemName: "arrow.up").font(.system(size: 20, weight: .medium)) }
                        }
                        .frame(width: 44, height: 44)
                        .background(MessagesStyle.orange, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isInserting || player == nil)
                    .accessibilityLabel("Add \(track.title) and note to message")
                }
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
        }
        .task { await loadPreview() }
        .onDisappear { player?.pause() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { player?.pause(); isPlaying = false } }
        .onReceive(NotificationCenter.default.publisher(for: .bewieMessagesBecameInactive)) { _ in
            player?.pause(); isPlaying = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem, item === player?.currentItem else { return }
            isPlaying = false
            player?.seek(to: .zero)
        }
        .alert("Bewie", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var preview: some View {
        ZStack(alignment: .bottomTrailing) {
            if let player {
                MessagesVideoSurface(player: player)
                    .accessibilityLabel("\(track.title), square video with synchronized lyrics")
                Button {
                    if isPlaying { player.pause() } else { player.play() }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .frame(width: 29, height: 29)
                        .background(MessagesStyle.paper, in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(4)
                .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")
            } else {
                MessagesStyle.paper
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView(value: downloadProgress)
                            .tint(MessagesStyle.orange)
                            .frame(maxWidth: 180)
                        Text(downloadProgress >= 1 ? "Preparing video…" : "Downloading video…")
                            .font(MessagesStyle.controlFont)
                    }
                    else {
                        Text("Video unavailable").font(MessagesStyle.controlFont)
                        Button("Retry") { Task { await loadPreview() } }.font(MessagesStyle.controlFont)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    @MainActor private func loadPreview() async {
        isLoading = true
        downloadProgress = 0
        defer { isLoading = false }
        do {
            let url = try await MessagesCatalog.video(for: track) { value in
                await MainActor.run { downloadProgress = value }
            }
            let asset = AVURLAsset(url: url)
            guard try await asset.load(.isPlayable) else { throw MessagesError.missingVideo }
            try Task.checkCancellation()
            player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        } catch is CancellationError { return }
        catch { self.error = error.localizedDescription }
    }
}

private struct MessagesVideoSurface: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerView { PlayerView() }
    func updateUIView(_ view: PlayerView, context: Context) {
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
    }
    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

#Preview("Ten choices") {
    MessagesRootView(expand: {}, insertSong: { _, _ in }, insertLink: {})
}
