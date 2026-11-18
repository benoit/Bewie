import XCTest

@MainActor
final class WatchControlTouchTests: XCTestCase {
    private func launchPlayer() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "bewie.atelierindustriel.be.watchkitapp")
        app.launchArguments = ["--watch-controls-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["watch.next"].waitForExistence(timeout: 15))
        return app
    }

    private func assertTrack(_ title: String, in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        let condition = NSPredicate(format: "value == %@", title)
        let expected = XCTNSPredicateExpectation(predicate: condition,
                                                object: app.buttons["watch.next"])
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed,
                       "One tap should change the track", file: file, line: line)
    }

    func testCoverWaitsForTapAndReturnsOnEveryForegroundActivation() {
        let app = XCUIApplication(bundleIdentifier: "bewie.atelierindustriel.be.watchkitapp")
        app.launchArguments = ["--watch-controls-ui-testing", "--watch-launch-reveal-ui-testing",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let sleeve = app.buttons["watch.openingSleeve"].firstMatch
        XCTAssertTrue(sleeve.waitForExistence(timeout: 10))
        // It must outlast the old automatic 3.5-second reveal without a tap.
        let remains = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sleeve)
        remains.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [remains], timeout: 4), .completed)
        XCTAssertTrue(sleeve.isHittable)
        let cover = XCTAttachment(screenshot: app.screenshot())
        cover.name = "Album cover waiting for tap with system time"
        cover.lifetime = .keepAlways
        add(cover)
        // Tap above Next: this must reveal the player without changing the track.
        sleeve.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.85)).tap()
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sleeve)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 8), .completed)
        XCTAssertTrue(app.buttons["watch.next"].isHittable)
        assertTrack("Party Warriors", in: app)
        app.buttons["watch.next"].tap()
        assertTrack("Every Room Is Borrowed", in: app)

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(sleeve.waitForExistence(timeout: 10), "Every foreground entry must show the cover again")
        XCTAssertTrue(sleeve.isHittable)
        sleeve.tap()
        let reopened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sleeve)
        XCTAssertEqual(XCTWaiter.wait(for: [reopened], timeout: 8), .completed)
        XCTAssertTrue(app.buttons["watch.next"].isHittable)
        assertTrack("Every Room Is Borrowed", in: app)
    }

    func testPreviousAndNextRespondOutsideTheirIcons() {
        let app = launchPlayer()
        let previous = app.buttons["watch.previous"]
        let play = app.buttons["watch.playPause"]
        let next = app.buttons["watch.next"]
        XCTAssertEqual(previous.frame.width, play.frame.width, accuracy: 1)
        XCTAssertEqual(next.frame.width, play.frame.width, accuracy: 1)
        XCTAssertEqual(previous.frame.maxX, play.frame.minX, accuracy: 1)
        XCTAssertEqual(play.frame.maxX, next.frame.minX, accuracy: 1)
        XCTAssertGreaterThanOrEqual(play.frame.height, 76)
        assertTrack("Party Warriors", in: app)

        // Blank space near both sides of each third, not the icon center.
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.15)).tap()
        assertTrack("Every Room Is Borrowed", in: app)
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.75)).tap()
        assertTrack("Next", in: app)
        previous.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.15)).tap()
        assertTrack("Every Room Is Borrowed", in: app)
        previous.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.75)).tap()
        assertTrack("Party Warriors", in: app)
    }

    func testPinStaysVisibleAcrossAllTracksAndReturningToApp() {
        let app = launchPlayer()
        let pin = app.descendants(matching: .any)["watch.trackPin"]
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        let originalCenter = CGPoint(x: pin.frame.midX, y: pin.frame.midY)
        XCTAssertEqual(originalCenter.x, app.frame.midX, accuracy: 1)
        XCTAssertEqual(pin.frame.width, 18, accuracy: 1)
        XCTAssertTrue(app.frame.contains(pin.frame))
        XCTAssertLessThan(pin.frame.maxY, app.buttons["watch.next"].frame.minY)

        for step in 1...9 {
            app.buttons["watch.next"].tap()
            let expectedID = String(step % 9 + 1)
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expectedID),
                                                    object: pin)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
            XCTAssertTrue(app.frame.contains(pin.frame))
            XCTAssertEqual(pin.frame.midX, originalCenter.x, accuracy: 1)
            XCTAssertEqual(pin.frame.midY, originalCenter.y, accuracy: 1)
        }

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertEqual(pin.value as? String, "1")
        XCTAssertEqual(pin.frame.midX, originalCenter.x, accuracy: 1)
        XCTAssertEqual(pin.frame.midY, originalCenter.y, accuracy: 1)
        XCTAssertTrue(app.frame.contains(pin.frame))
    }

    func testTrackHeaderUpdatesAndCrownLeavesPlaybackResponsive() {
        let app = launchPlayer()
        XCTAssertEqual(app.staticTexts["watch.trackNumber"].label, "1")
        XCTAssertEqual(app.staticTexts["watch.trackTitle"].label, "Party Warriors")
        app.buttons["watch.next"].tap()
        assertTrack("Every Room Is Borrowed", in: app)
        XCTAssertEqual(app.staticTexts["watch.trackNumber"].label, "2")
        XCTAssertEqual(app.staticTexts["watch.trackTitle"].label, "Every Room Is Borrowed")
        XCTAssertFalse(app.buttons["watch.audioOutput"].exists)
        let volume = app.descendants(matching: .any)["watch.volumeControl"].firstMatch
        XCTAssertFalse(volume.exists && volume.isHittable, "The volume control starts invisible")
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "System Crown volume indicator"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCUIDevice.shared.rotateDigitalCrown(delta: -0.5)
        assertTrack("Every Room Is Borrowed", in: app)
        app.buttons["watch.next"].tap()
        assertTrack("Next", in: app)
    }

    func testPlayRespondsInTheBlankTopAndBottomOfItsZone() {
        for point in [CGVector(dx: 0.1, dy: 0.1), CGVector(dx: 0.9, dy: 0.9)] {
            let app = launchPlayer()
            let play = app.buttons["watch.playPause"]
            XCTAssertTrue(play.isEnabled)
            play.coordinate(withNormalizedOffset: point).tap()
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Starting playback"),
                                                    object: play)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed,
                           "One tap anywhere in the center third should request playback")
            // A repeat tap while starting must leave the accepted Play request intact.
            play.coordinate(withNormalizedOffset: point).tap()
            XCTAssertEqual(play.label, "Starting playback")
            XCTAssertTrue(app.buttons["watch.previous"].isEnabled)
            XCTAssertTrue(app.buttons["watch.next"].isEnabled)
            app.terminate()
        }
    }
}
