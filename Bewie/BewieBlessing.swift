#if os(iOS) && !targetEnvironment(macCatalyst)
import BlessingKit
import Foundation
import Observation
import UIKit

@MainActor
protocol BewieBlessingClient: AnyObject {
    var isBlessed: Bool { get }
    func handle(_ url: URL) async throws -> Bool
    func revoke() throws
}
extension Blessing: BewieBlessingClient {}

@MainActor @Observable
final class BewieBlessing {
    private var client: (any BewieBlessingClient)?
    var errorMessage: String?
    var isBlessed: Bool { client?.isBlessed ?? false }

    init() {
        do {
            let url = try Self.profileURL()
            let profile = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: url))
            let keys = try profile.authorityPublicKeys.map { key in
                guard let data = Data(base64Encoded: key) else { throw BlessingError.invalidConfiguration }
                return data
            }
            client = try Blessing(configuration: BlessingConfiguration(
                appID: profile.appID, urlScheme: profile.urlScheme,
                linksBaseURL: profile.linksBaseURL, authorityPublicKeys: keys,
                transmission: .controlled))
        } catch { errorMessage = Self.failureMessage }
    }

    init(client: any BewieBlessingClient) { self.client = client }

    @discardableResult
    func handle(_ url: URL) async throws -> Bool {
        guard let client else { throw BlessingError.invalidConfiguration }
        if url.scheme == "bewie", url.host == "stop" {
            guard url.absoluteString == "bewie://stop" else { throw BlessingError.malformedURL }
            try client.revoke()
            errorMessage = nil
            return true
        }
        if url.absoluteString == "bewie://start", client.isBlessed { return true }
        return try await client.handle(url)
    }

    func open(_ url: URL) async {
        do { _ = try await handle(url) }
        catch { errorMessage = Self.failureMessage }
    }

    static let failureMessage = "The blessing link could not be accepted. Please request a new blessing from the Mac mini."
    private static func profileURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "Blessing.public", withExtension: "json") else {
            throw BlessingError.invalidConfiguration
        }
        return url
    }
    private struct Profile: Decodable {
        let appID: String
        let urlScheme: String
        let linksBaseURL: URL
        let authorityPublicKeys: [String]
    }
}

@MainActor
enum PerleDestination {
    static let appURL = URL(string: "perle://")!
    static let storeURL = URL(string: "https://apps.apple.com/app/id6834117140")!

    static func open(using open: @MainActor (URL) async -> Bool = { await UIApplication.shared.open($0) }) async -> Bool {
        if await open(appURL) { return true }
        return await open(storeURL)
    }
}
#endif
