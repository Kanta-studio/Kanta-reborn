import XCTest

/// Actual starter playback and separate explicitly labeled demo interaction tests.
final class KantaVisualWalkthroughUITests: XCTestCase {
    private let waitSeconds: TimeInterval = 25
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testStarterPlaybackAndControls() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KANTA_DEMO_MODE"] = "0"
        app.launch()
        capture("01-real-main-stage", app)
        app.buttons["More"].tap()
        app.buttons["Song Library"].tap()
        let title = app.staticTexts["Morning Light"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: waitSeconds))
        for _ in 0..<8 where !title.isHittable { app.swipeUp() }
        capture("02-real-starter-library", app)
        let play = app.buttons["starter.play.morning-light"]
        for _ in 0..<5 where !play.isHittable { app.swipeUp() }
        XCTAssertTrue(play.isHittable)
        play.tap()
        app.buttons["Done"].firstMatch.tap()
        let transport = app.buttons["stage.playPause"]
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "enabled == true AND label == 'Pause'"), evaluatedWith: transport)
        waitForExpectations(timeout: waitSeconds)
        let currentSong = app.staticTexts["stage.currentSong"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Morning Light"), evaluatedWith: currentSong)
        waitForExpectations(timeout: waitSeconds)
        capture("03-real-starter-playing", app)
        transport.tap()
        expectation(for: NSPredicate(format: "label == 'Play'"), evaluatedWith: transport)
        waitForExpectations(timeout: 5)
        capture("04-real-paused", app)
        transport.tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: transport)
        waitForExpectations(timeout: 5)
        capture("05-real-resumed", app)
        XCTAssertFalse(app.sliders["Song position"].exists)
        XCTAssertFalse(app.buttons["Previous song"].exists)
        app.buttons["stage.search"].tap()
        XCTAssertTrue(app.buttons["stage.keypad.0"].waitForExistence(timeout: 5))
        capture("06-real-search-overlay", app)
        app.buttons["Cancel"].tap()
        app.buttons["stage.controls"].tap()
        capture("07-real-controls", app)
        for index in 0..<3 {
            app.swipeUp()
            capture("08-real-controls-\(index)", app)
        }
    }

    @MainActor
    func testMainMenuButtonsAndScreens() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KANTA_DEMO_MODE"] = "0"
        for destination in ["Song Library", "KANTA Songbook", "Settings",
                            "Companion Remote", "iCloud Save", "Legal & Privacy"] {
            app.launch()
            XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: waitSeconds))
            app.buttons["More"].tap()
            let button = app.buttons[destination].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            capture("menu-" + destination, app)
            app.terminate()
        }
    }

    @MainActor
    func testDemoKeypadCancelAndRepeatedIntentionalReservations() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KANTA_DEMO_MODE"] = "1"
        app.launch()
        let queue = app.buttons["Queue"]
        XCTAssertTrue(queue.waitForExistence(timeout: waitSeconds))
        XCTAssertEqual(queue.value as? String, "2 reservations")
        app.buttons["stage.search"].tap()
        for digit in 0...9 { XCTAssertTrue(app.buttons["stage.keypad.\(digit)"].exists) }
        app.buttons["Cancel"].tap()
        XCTAssertEqual(queue.value as? String, "2 reservations")
        // The same song may legitimately be reserved twice in two separate flows.
        for count in 3...4 {
            app.buttons["stage.search"].tap()
            app.buttons["stage.keypad.Clear"].tap()
            for key in ["0", "0", "3"] { app.buttons["stage.keypad." + key].tap() }
            let result = app.buttons["Select Tadhana"]
            XCTAssertTrue(result.waitForExistence(timeout: 10))
            let enabled = NSPredicate(format: "enabled == true")
            expectation(for: enabled, evaluatedWith: result)
            waitForExpectations(timeout: 10)
            result.tap()
            capture("demo-selected-song-\(count)", app)
            app.buttons["stage.reserve"].doubleTap()
            let updated = NSPredicate(format: "value == %@", "\(count) reservations")
            expectation(for: updated, evaluatedWith: queue)
            waitForExpectations(timeout: 10)
            expectation(for: NSPredicate(format: "exists == false"),
                        evaluatedWith: app.buttons["stage.reserve"])
            waitForExpectations(timeout: 5)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["stage.search"].tap()
        XCTAssertTrue(app.buttons["stage.keypad.0"].isHittable)
        XCTAssertTrue(app.buttons["stage.reserve"].isHittable)
        capture("demo-landscape-keypad", app)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
