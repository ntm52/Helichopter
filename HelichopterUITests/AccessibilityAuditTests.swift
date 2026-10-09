import XCTest

/// Runs Apple's accessibility audit (the checks in Xcode's Accessibility Inspector) on
/// every screen, as VoiceOver and Voice Control see it. VoiceOver and Voice Control do
/// not run in the simulator, but they read this same tree; each screen's tree is
/// attached to the result so it can be read without a device.
final class AccessibilityAuditTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch arguments override saved settings for this run only.
        app.launchArguments += ["-onboarding_completed_v1", "NO", "-gs_noFailMode", "NO",
                                "-gs_scanningEnabled", "NO", "-gs_isSettingsLocked", "NO"]
        app.launch()
    }

    /// Audits what is on screen now; any issue fails the test.
    private func audit(_ screen: String) throws {
        attachTree(screen)
        try XCTContext.runActivity(named: "Audit \(screen)") { _ in
            try app.performAccessibilityAudit()
        }
    }

    private func attachTree(_ screen: String) {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Accessibility tree: \(screen)"
        add(tree)
    }

    /// Audits part of the scrolling Settings list. A row cut in half by the screen edge
    /// shows text the audit cannot match to its control, depending on where scrolling
    /// stopped; so after a first failure the list moves a little and is audited again.
    /// A real problem fails both times.
    private func auditScrolled(_ screen: String) throws {
        attachTree(screen)
        var flagged = false
        try XCTContext.runActivity(named: "Audit \(screen)") { _ in
            try app.performAccessibilityAudit { _ in
                flagged = true
                return true
            }
        }
        guard flagged else { return }
        drag(from: 0.6, to: 0.5)
        try audit(screen + ", moved")
    }

    /// Drags in the left margin, clear of sliders, so scrolling never changes a setting.
    private func drag(from startY: CGFloat, to endY: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: startY))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: endY)))
        // Let the list stop coasting; the audit compares on-screen text with element frames.
        Thread.sleep(forTimeInterval: 1.5)
    }

    func testEveryScreenPassesTheAudit() throws {
        try audit("Guide, step 1")
        app.buttons["Next"].tap()
        try audit("Guide, step 2")
        app.buttons["Skip guide"].tap()
        try audit("Home")

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5), "Back must be read as Back, without its arrow")
        try audit("Settings, top")
        // A finger tap leaves a slider alone; only assistive technology opens its larger
        // buttons (covered by AssistiveTechTreeTests, since UI tests can only touch).
        let gap = app.sliders["Gap Size"]
        let value = gap.value as? String
        gap.tap()
        XCTAssertFalse(app.buttons["Done"].waitForExistence(timeout: 2), "A finger tap must not open the slider page")
        XCTAssertEqual(gap.value as? String, value)
        for part in ["middle", "lower", "bottom"] {
            drag(from: 0.85, to: 0.25)
            try auditScrolled("Settings, \(part)")
        }
        app.buttons["Acknowledgements"].tap()
        try audit("Acknowledgements")
        app.buttons["Done"].tap()
        app.buttons["Back"].tap()

        app.buttons["Play"].tap()
        XCTAssertTrue(app.buttons["Helicopter flight control"].waitForExistence(timeout: 5))
        try audit("Playing")
        app.buttons["Pause"].tap()
        try audit("Paused")
        app.buttons["Resume"].tap()
        // The round restarts on the first flap; with No-Fail off, the helicopter then falls and crashes.
        app.buttons["Helicopter flight control"].tap()
        XCTAssertTrue(app.staticTexts["Round Over"].waitForExistence(timeout: 15))
        try audit("Round Over")
    }
}
