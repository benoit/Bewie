import XCTest
@testable import Bewie

final class BewieIdentityTests: XCTestCase {
    func testBewieOwnsOnlyItsSongLinks() throws {
        for number in 1...9 {
            XCTAssertEqual(BewieLink(url: try XCTUnwrap(URL(string: "bewie://\(number)"))), .track(number))
        }
        for value in ["perle://1", "bewie://activate", "bewie://AA", "bewie://0", "bewie://10",
                      "bewie://1/path", "bewie://1?code=private", "bewie://1#fragment", "bewie://user@1"] {
            XCTAssertNil(BewieLink(url: try XCTUnwrap(URL(string: value))), value)
        }
    }

    func testAlbumAppHasIndependentIdentityAndNoGuideServices() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "bewie.atelierindustriel.be")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Bewie")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "BAAppGroupID") as? String, "group.bewie.atelierindustriel.be.music")
        let routes = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        XCTAssertEqual(routes.first?["CFBundleURLSchemes"] as? [String], ["bewie"])
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "BewieAPNSEnvironment"))
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "BewiePushKeychainGroup"))
    }
}
