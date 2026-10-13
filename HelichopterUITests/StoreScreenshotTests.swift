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

    /// Scrolls Settings until `element`'s top sits at `fraction` of the screen height.
    /// Slow drags in the left margin avoid coasting and never touch a slider.
    private func scroll(_ element: XCUIElement, toTopAt fraction: CGFloat) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let height = app.frame.height
        for _ in 0..<12 {
            let offset = element.frame.minY - fraction * height
            if abs(offset) < 4 { return }
            let step = max(-0.6, min(0.6, offset / height))
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: step > 0 ? 0.85 : 0.3))
            let end = start.withOffset(CGVector(dx: 0, dy: -step * height))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }

    func testCaptureStoreScreenshots() throws {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        // Gameplay: Auto Hover holds the helicopter steady while pipes pass.
        launch(controlScheme: 2)
        app.buttons["Play"].tap()
        let flight = app.buttons["Helicopter flight control"]
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
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        if isPad {
            capture("4-difficulty-and-comfort")
            scroll(app.staticTexts["Switch Access"], toTopAt: 0.17)
            capture("5-switch-access-controls-colours")
        } else {
            scroll(app.staticTexts["Comfort"], toTopAt: 0.255)
            capture("4-comfort-and-switch-access")
            scroll(app.sliders["Scan Dwell Time"], toTopAt: 0.175)
            capture("5-controls-and-colours")
            scroll(app.staticTexts["Difficulty Preset"], toTopAt: 0.255)
            capture("6-difficulty")
        }
        app.terminate()

        launch(guide: true)
        capture(isPad ? "6-how-to-play" : "7-how-to-play")
    }
}
