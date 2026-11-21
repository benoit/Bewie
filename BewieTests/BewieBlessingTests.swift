#if os(iOS) && !targetEnvironment(macCatalyst)
import XCTest
@testable import Bewie

@MainActor
final class BewieBlessingTests: XCTestCase {
    func testStartDoesNothingWhenBlessedAndStopRequiresNewRequest() async throws {
        let client = StubBlessingClient()
        let blessing = BewieBlessing(client: client)
        client.isBlessed = true
        let started = try await blessing.handle(URL(string: "bewie://start")!)
        XCTAssertTrue(started)
        XCTAssertTrue(client.handled.isEmpty)
        let stopped = try await blessing.handle(URL(string: "bewie://stop")!)
        XCTAssertTrue(stopped)
        XCTAssertFalse(blessing.isBlessed)
        XCTAssertEqual(client.revocations, 1)
        _ = try await blessing.handle(URL(string: "bewie://start")!)
        XCTAssertEqual(client.handled.map(\.absoluteString), ["bewie://start"])
    }

    func testMalformedStopDoesNotRemoveBlessing() async throws {
        let client = StubBlessingClient(); client.isBlessed = true
        let blessing = BewieBlessing(client: client)
        for value in ["bewie://stop?token=wrong", "bewie://stop/path", "bewie://stop#fragment"] {
            do { _ = try await blessing.handle(URL(string: value)!); XCTFail("Accepted malformed stop") }
            catch {}
        }
        XCTAssertTrue(blessing.isBlessed)
        XCTAssertEqual(client.revocations, 0)
    }

    func testGrantIsPassedToKitAndFailuresDoNotShowPearl() async throws {
        let client = StubBlessingClient()
        let blessing = BewieBlessing(client: client)
        let url = URL(string: "bewie://grant?token=invalid")!
        client.shouldFail = true
        await blessing.open(url)
        XCTAssertFalse(blessing.isBlessed)
        XCTAssertNotNil(blessing.errorMessage)
        XCTAssertEqual(client.handled, [url])
    }

    func testPerleFallbackOnlyRunsAfterFailedAppOpen() async {
        var attempts: [URL] = []
        let installed = await PerleDestination.open { url in attempts.append(url); return true }
        XCTAssertTrue(installed)
        XCTAssertEqual(attempts, [PerleDestination.appURL])
        attempts = []
        let fallback = await PerleDestination.open { url in attempts.append(url); return url == PerleDestination.storeURL }
        XCTAssertTrue(fallback)
        XCTAssertEqual(attempts, [PerleDestination.appURL, PerleDestination.storeURL])
        let failed = await PerleDestination.open { _ in false }
        XCTAssertFalse(failed)
    }
}

@MainActor
private final class StubBlessingClient: BewieBlessingClient {
    var isBlessed = false
    var handled: [URL] = []
    var revocations = 0
    var shouldFail = false
    func handle(_ url: URL) async throws -> Bool {
        handled.append(url)
        if shouldFail { throw NSError(domain: "test", code: 1) }
        return true
    }
    func revoke() throws { revocations += 1; isBlessed = false }
}
#endif
