#if os(iOS) && !targetEnvironment(macCatalyst)
import BlessingKit
import XCTest
@testable import Bewie

@MainActor
final class BewieBlessingEndToEndTests: XCTestCase {
    func testRealMacPersonalGrantRestoresAndStopRequiresFreshApproval() async throws {
        struct Profile: Decodable {
            let appID: String
            let urlScheme: String
            let linksBaseURL: URL
            let authorityPublicKeys: [String]
        }
        let file = try XCTUnwrap(Bundle.main.url(forResource: "Blessing.public", withExtension: "json"))
        let profile = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: file))
        let configuration = try BlessingConfiguration(appID: profile.appID, urlScheme: profile.urlScheme,
            linksBaseURL: profile.linksBaseURL, authorityPublicKeys: profile.authorityPublicKeys.map { try XCTUnwrap(Data(base64Encoded: $0)) }, transmission: .controlled)
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BlessingIntegration", isDirectory: true)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: directory.appendingPathComponent("enabled").path),
                          "Requires the local Mac-mini grant approval harness")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var requestNumber = 0
        let client = try Blessing(configuration: configuration, share: { url in
            requestNumber += 1
            try url.absoluteString.write(to: directory.appendingPathComponent("request-\(requestNumber).txt"), atomically: true, encoding: .utf8)
        })
        try client.revoke()
        let wrapper = BewieBlessing(client: client)
        XCTAssertFalse(wrapper.isBlessed)
        _ = try await wrapper.handle(URL(string: "bewie://start")!)
        let firstGrant = try await response(1, in: directory)
        _ = try await wrapper.handle(firstGrant)
        XCTAssertTrue(wrapper.isBlessed)
        XCTAssertTrue(client.rights.isEmpty)
        let restored = try Blessing(configuration: configuration, share: { _ in XCTFail("Blessed start must not share") })
        let reopened = BewieBlessing(client: restored)
        XCTAssertTrue(reopened.isBlessed)
        _ = try await reopened.handle(URL(string: "bewie://start")!)
        XCTAssertEqual(requestNumber, 1)
        _ = try await wrapper.handle(URL(string: "bewie://stop")!)
        XCTAssertFalse(wrapper.isBlessed)
        let stopped = try Blessing(configuration: configuration, share: { _ in })
        XCTAssertFalse(stopped.isBlessed)
        do { _ = try await wrapper.handle(firstGrant); XCTFail("Old grant restored after stop") }
        catch {}
        XCTAssertFalse(wrapper.isBlessed)
        _ = try await wrapper.handle(URL(string: "bewie://start")!)
        let freshGrant = try await response(2, in: directory)
        _ = try await wrapper.handle(freshGrant)
        XCTAssertTrue(wrapper.isBlessed)
        XCTAssertTrue(client.rights.isEmpty)
        try client.revoke()
    }

    private func response(_ number: Int, in directory: URL) async throws -> URL {
        let path = directory.appendingPathComponent("grant-\(number).txt")
        for _ in 0..<240 {
            if let text = try? String(contentsOf: path, encoding: .utf8), let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) { return url }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw NSError(domain: "MacGrantTimeout", code: number)
    }
}
#endif
