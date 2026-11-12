import XCTest

/// Captures the App Store screenshots (see "Screenshot capture brief" in
/// `Release/APP_STORE_COPY.md`). Skipped in normal test runs. To capture, run on each
/// store device with the variable set, then export the attachments from the result:
///
///     TEST_RUNNER_STORE_SCREENSHOTS=1 xcodebuild test ... \
///         -only-testing:HelichopterUITests/StoreScreenshotTests
final class StoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SCREENSHOTS"] == "1",
                          "Set TEST_RUNNER_STORE_SCREENSHOTS=1 to capture store screenshots")
        continueAfterFailure = false
    }

    /// Launches with the default look, so every device's shots match. Values are plist
    /// literals because some settings are read only as numbers or booleans, not text.
    private func launch(guide: Bool = false, controlScheme: Int = 0) {
        app = XCUIApplication()
        app.launchArguments += ["-onboarding_completed_v1", guide ? "<false/>" : "<true/>",
                                "-gs_noFailMode", "<true/>", "-gs_calmMode", "<false/>",
                                "-gs_helicopterOutline", "<true/>", "-gs_hideGameWhilePaused", "<false/>",
                                "-gs_showScore", "<true/>", "-gs_scanningEnabled", "<false/>",
                                "-gs_isSettingsLocked", "<false/>", "-gs_selectedThemeID", "nightSky",
                                "-gs_selectedPaletteID", "default", "-isMusicOn", "<false/>",
                                "-gs_scanScheme", "<integer>0</integer>",
                                "-gs_scanDwellTime", "<real>2</real>",
                                "-gs_switchPauseHoldDuration", "<real>3</real>",
                                "-gs_controlScheme", "<integer>\(controlScheme)</integer>",
                                "-bestScore", "<integer>18</integer>"]
        app.launch()
    }

    private func capture(_ name: String) {
        // Let fades and scrolling finish.
        Thread.sleep(forTimeInterval: 1.5)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCaptureStoreScreenshots() throws {
        // Gameplay: Auto Hover holds the helicopter steady while pipes pass. Its screen
        // is split into Fly up and Fly down areas.
        launch(controlScheme: 2)
        app.buttons["Play"].tap()
        let flight = app.buttons["Fly up"]
        XCTAssertTrue(flight.waitForExistence(timeout: 5))
        flight.tap()
        // About 10 s in, the first pipe pair is passing the helicopter.
        Thread.sleep(forTimeInterval: 8.5)
        capture("1-gameplay")
        app.terminate()

        launch()
        capture("2-home")
        // The menu themes live in the Hangar from 2.1.
        app.buttons["Hangar"].tap()
        XCTAssertTrue(app.buttons["Classic Pipes"].waitForExistence(timeout: 5))
        capture("3-hangar")
        app.buttons["Back"].tap()
        // Taps wait for each fade, and the Hangar also has Back, so wait for each screen.
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        app.buttons["Settings"].tap()
        // Settings is a menu of categories; each page rests at its top, so nothing scrolls.
        XCTAssertTrue(app.buttons["Reset Settings"].waitForExistence(timeout: 5))
        capture("4-settings")
        let pages: [(category: String, control: XCUIElement, name: String)] = [
            ("Difficulty", app.buttons["Gentle"], "5-difficulty"),
            ("Comfort", app.switches["Calm Mode"], "6-comfort"),
            ("Controls and Switches", app.buttons["Tap to Flap"], "7-controls-and-switches"),
            ("Colours", app.buttons["Default"], "8-colours")
        ]
        for page in pages {
            app.buttons[page.category].tap()
            XCTAssertTrue(page.control.waitForExistence(timeout: 5), "\(page.category) did not open")
            capture(page.name)
            app.buttons["Back"].tap()
            XCTAssertTrue(app.buttons["Reset Settings"].waitForExistence(timeout: 5))
            Thread.sleep(forTimeInterval: 1)
        }
        app.terminate()

        launch(guide: true)
        capture("9-how-to-play")
    }
}
