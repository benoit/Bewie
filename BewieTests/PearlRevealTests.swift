import UIKit
import XCTest
@testable import Bewie

final class PearlRevealTests: XCTestCase {
    func testOnlyBlessedMapShowsPearl() {
        for blessed in [false, true] {
            for sleeve in [false, true] {
                for player in [false, true] {
                    XCTAssertEqual(PearlReveal.isVisible(isBlessed: blessed, showsOpeningSleeve: sleeve, presentsPlayer: player), blessed && !sleeve && !player)
                }
            }
        }
    }

    @MainActor
    func testPearlAssetIsBundledAndHasTransparency() throws {
        let image = try XCTUnwrap(UIImage(named: "PearlPin"))
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertGreaterThan(cgImage.width, 100)
        XCTAssertTrue([CGImageAlphaInfo.premultipliedFirst, .premultipliedLast, .first, .last].contains(cgImage.alphaInfo))
    }
}
