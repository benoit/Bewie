import UIKit
import XCTest
@testable import Bewie

final class PearlRevealTests: XCTestCase {
    func testPublicPearlAppearsOnlyOnTheAnniversary() throws {
        let calendar = calendar(in: "Europe/Paris")
        for (day, visible) in [("2026-11-29T23:59:59+01:00", false),
                               ("2026-11-30T00:00:00+01:00", true),
                               ("2026-11-30T23:59:59+01:00", true),
                               ("2026-12-01T00:00:00+01:00", false),
                               ("2027-11-30T12:00:00+01:00", false)] {
            XCTAssertEqual(PearlReveal.isVisible(on: try date(day), calendar: calendar,
                                                isInternalTestFlight: false), visible, day)
        }
    }

    func testRevealUsesTheListenersLocalDayAndGregorianAnniversary() throws {
        let instant = try date("2026-11-29T23:30:00Z")
        XCTAssertTrue(PearlReveal.isVisible(on: instant, calendar: calendar(in: "Europe/Paris"),
                                           isInternalTestFlight: false))
        XCTAssertFalse(PearlReveal.isVisible(on: instant, calendar: calendar(in: "America/New_York"),
                                            isInternalTestFlight: false))
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Bangkok"))
        XCTAssertTrue(PearlReveal.isVisible(on: instant, calendar: buddhist, isInternalTestFlight: false))
    }

    func testInternalTestFlightCanPreviewBeforeAndAfterTheDate() throws {
        for value in ["2026-10-22T10:00:00Z", "2026-12-01T10:00:00Z"] {
            XCTAssertTrue(PearlReveal.isVisible(on: try date(value), isInternalTestFlight: true))
            XCTAssertFalse(PearlReveal.isVisible(on: try date(value), isInternalTestFlight: false))
        }
    }

    @MainActor
    func testPearlAssetIsBundledAndHasTransparency() throws {
        let image = try XCTUnwrap(UIImage(named: "PearlPin"))
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertGreaterThan(cgImage.width, 100)
        XCTAssertGreaterThan(cgImage.height, 100)
        XCTAssertTrue([CGImageAlphaInfo.premultipliedFirst, .premultipliedLast, .first, .last].contains(cgImage.alphaInfo))
    }

    private func date(_ text: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: text))
    }

    private func calendar(in zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }
}
