import XCTest

@MainActor
final class BewieTVUITests: XCTestCase {
    func testPlaybackRemoteNavigationAndCompactControls() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "bewie.atelierindustriel.be")
        app.launchArguments = ["--preview-player", "--uitest-audio", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let remote = XCUIRemote.shared
        let pause = app.buttons["Pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Every Room Is Borrowed"].exists)
        for id in 1...9 { XCTAssertTrue(app.buttons["track-pin-\(id)"].exists, "Missing pin \(id)") }
        XCTAssertEqual(app.links.count, 0)
        let player = app.otherElements["tv-compact-player"]
        XCTAssertTrue(player.exists)
        XCTAssertLessThanOrEqual(player.frame.width, app.frame.width * 0.26)
        remote.press(.playPause)
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5), app.debugDescription)
        remote.press(.playPause)
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        // Preview starts with Play focused. Move to Next, then select.
        remote.press(.right)
        XCTAssertTrue(app.buttons["Next track"].hasFocus, app.debugDescription)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Next"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.buttons["track-pin-3"].exists)
        let pin = app.buttons["track-pin-3"]
        let arrival = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: pin)
        XCTAssertEqual(XCTWaiter.wait(for: [arrival], timeout: 15), .completed, app.debugDescription)
        remote.press(.select)
        XCTAssertTrue(pause.hasFocus, app.debugDescription)
        remote.press(.up)
        let seek = app.buttons["Playback position"]
        XCTAssertTrue(seek.hasFocus, app.debugDescription)
        func seconds(_ value: Any?) -> Int {
            let parts = (value as? String ?? "0:00").split(separator: ":").compactMap { Int($0) }
            return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
        }
        let before = seconds(seek.value)
        remote.press(.right)
        XCTAssertGreaterThanOrEqual(seconds(seek.value) - before, 8)
        remote.press(.down)
        remote.press(.menu)
        XCTAssertTrue(pause.waitForNonExistence(timeout: 5), app.debugDescription)
        remote.press(.select)
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bewie TV player and edge pins"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
