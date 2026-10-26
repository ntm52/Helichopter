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

    /// Scrolls Settings until `element`'s top sits at `fraction` of the screen height.
    private func scroll(_ element: XCUIElement, toTopAt fraction: CGFloat) {
        scroll(element, toY: fraction * app.frame.height)
    }

    /// Scrolls Settings until `element`'s top sits `points` below the Settings title, so
    /// the framing matches on phones whose title bars differ in height.
    private func scroll(_ element: XCUIElement, belowTitleBy points: CGFloat) {
        scroll(element, toY: app.staticTexts["Settings"].frame.maxY + points)
    }

    /// Slow drags 6 points from the left edge avoid coasting and start left of every
    /// slider track (2% of an iPad's width is already on one).
    /// Settings exposes only rows near the visible area, so an element at the edge can
    /// drop out of the tree for a moment; each pass waits for it again.
    private func scroll(_ element: XCUIElement, toY target: CGFloat) {
        let height = app.frame.height
        // Each drag loses its first few points to the scroll view's touch slop (about 10
        // on a phone, 15 on an iPad); learn it from each long drag and add it back.
        var slop: CGFloat = 10
        var lastDrag: CGFloat?
        var lastY: CGFloat?
        var stuck = 0
        for _ in 0..<12 {
            guard element.waitForExistence(timeout: 3) else {
                // Gone from the tree for now: nudge the same way (or down the page) and look again.
                drag(by: (lastDrag ?? height / 2) / 2, height: height)
                lastDrag = nil
                continue
            }
            let y = element.frame.minY
            // Two long drags in a row that moved nothing mean the page has reached its end
            // (one alone can be a stale reading).
            if let drag = lastDrag, let before = lastY, abs(drag) > 60, abs(before - y) < 2 {
                stuck += 1
                if stuck == 2 { return }
            } else {
                stuck = 0
            }
            if let drag = lastDrag, let before = lastY, abs(drag) > 60,
               abs(before - y) > 30, abs(before - y) < abs(drag) {
                slop = abs(drag) - abs(before - y)
            }
            let offset = y - target
            if abs(offset) < 4 { return }
            let distance = offset + (offset > 0 ? slop : -slop)
            lastDrag = drag(by: distance, height: height, avoiding: element.frame)
            lastY = y
        }
        // Close enough still frames the shot; only a real miss fails.
        if abs(element.frame.minY - target) > 20 { XCTFail("Could not scroll \(element) into place") }
    }

    /// Drags the page up by `distance` points (down if negative), at most 60% of the
    /// screen at a time, and returns how far it dragged. The drag starts off `avoiding`,
    /// because a full-width button under the finger takes the touch instead of the page.
    @discardableResult
    private func drag(by distance: CGFloat, height: CGFloat, avoiding: CGRect = .null) -> CGFloat {
        let step = max(-0.6, min(0.6, distance / height))
        let starts: [CGFloat] = step > 0 ? [0.85, 0.95, 0.75] : [0.3, 0.2, 0.35]
        let startY = starts.first { !avoiding.insetBy(dx: 0, dy: -8).contains(CGPoint(x: 6, y: $0 * height)) } ?? starts[0]
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: startY))
            .withOffset(CGVector(dx: 6, dy: 0))
        let end = start.withOffset(CGVector(dx: 0, dy: -step * height))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        return step * height
    }

    func testCaptureStoreScreenshots() throws {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

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
        XCTAssertTrue(app.staticTexts["Difficulty Preset"].waitForExistence(timeout: 5))
        if isPad {
            capture("4-difficulty-and-comfort")
            scroll(app.staticTexts["Switch Access"], toTopAt: 0.17)
            capture("5-switch-access-controls-colours")
        } else {
            scroll(app.staticTexts["Comfort"], toTopAt: 0.255)
            capture("4-comfort-and-switch-access")
            // From 2.1 the pause toggles push the palettes off screen, so they get their own shot.
            // Row titles can drop out of the UI-test tree mid-scroll; the slider above
            // In-Game Control does not. Its frame is the whole row, so tuck the row
            // under the title bar.
            let dwell = app.sliders["Scan Dwell Time"]
            XCTAssertTrue(dwell.waitForExistence(timeout: 5))
            scroll(dwell, belowTitleBy: 8 - dwell.frame.height)
            capture("5-controls-and-pausing")
            // The Hangar also has a Menu Theme heading, so use the Settings-only button.
            scroll(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Menu Theme:'")).firstMatch,
                   belowTitleBy: 55)
            capture("6-colours")
            // Back at the top, where the page rests.
            scroll(app.staticTexts["Difficulty Preset"], belowTitleBy: 36)
            capture("7-difficulty")
        }
        app.terminate()

        launch(guide: true)
        capture(isPad ? "6-how-to-play" : "8-how-to-play")
    }
}
