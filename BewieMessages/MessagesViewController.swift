import Messages
import SwiftUI

@MainActor
final class MessagesViewController: MSMessagesAppViewController {
    private var host: UIHostingController<MessagesRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(MessagesStyle.paper)
        let root = MessagesRootView(
            expand: { [weak self] in self?.requestPresentationStyle(.expanded) },
            insertSong: { [weak self] track, note in
                guard let self else { throw MessagesError.noConversation }
                try await self.insertSong(track, note: note)
            },
            insertLink: { [weak self] in
                guard let self else { throw MessagesError.noConversation }
                try await self.insertLink()
            }
        )
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        self.host = host
    }

    override func willResignActive(with conversation: MSConversation) {
        NotificationCenter.default.post(name: .bewieMessagesBecameInactive, object: nil)
        super.willResignActive(with: conversation)
    }

    private func insertSong(_ track: AlbumTrack, note: String) async throws {
        guard let conversation = activeConversation else { throw MessagesError.noConversation }
        let file = try await MessagesCatalog.video(for: track)
        guard activeConversation === conversation else { throw MessagesError.conversationChanged }
        try await conversation.insertAttachment(file, withAlternateFilename: "Bewie — \(track.title).mp4")
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            guard activeConversation === conversation else { throw MessagesError.conversationChanged }
            do { try await conversation.insertText(note) }
            catch { throw MessagesError.noteNotAdded }
        }
        requestPresentationStyle(.compact)
    }

    private func insertLink() async throws {
        guard let conversation = activeConversation else { throw MessagesError.noConversation }
        guard let appURL = MessagesCatalog.appURL else { return }
        try await conversation.insertText(appURL.absoluteString)
        requestPresentationStyle(.compact)
    }
}

enum MessagesError: LocalizedError {
    case noConversation, missingVideo, conversationChanged, noteNotAdded
    var errorDescription: String? {
        switch self {
        case .noConversation: "Open a conversation in Messages to share Bewie."
        case .missingVideo: "This song’s video is not ready. Please retry when you have a connection."
        case .conversationChanged: "The video was added to the previous conversation. Add your note there before sending."
        case .noteNotAdded: "The video is ready in Messages, but the note could not be added. Add your note in Messages before sending."
        }
    }
}

extension Notification.Name {
    static let bewieMessagesBecameInactive = Notification.Name("BewieMessagesBecameInactive")
}
