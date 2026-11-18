import XCTest
@testable import Bewie

final class PublicMacTests: XCTestCase {
    func testMacAcceptsTrackLinksAndRejectsEveryPrivateRoute() throws {
        for number in 1...9 {
            XCTAssertEqual(BewieLink(url: try XCTUnwrap(URL(string: "bewie://\(number)"))), .track(number))
        }
        for host in Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init) + ["activate", "0", "10"] {
            XCTAssertNil(BewieLink(url: try XCTUnwrap(URL(string: "bewie://\(host)"))), host)
        }
    }

    func testMacBundleIdentityAndFirstReleaseVersion() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "bewie.atelierindustriel.be")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "1.0")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String, "1")
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "BewieAPNSEnvironment"))
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "BewiePushKeychainGroup"))
    }
}
