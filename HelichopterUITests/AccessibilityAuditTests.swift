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
        app.launchArguments += ["-gs_noFailMode", "NO",
                                "-gs_scanningEnabled", "NO", "-gs_isSettingsLocked", "NO"]
    }

    /// Audits what is on screen now; any issue fails the test.
    private func audit(_ screen: String) throws {
        // A screen change cross-fades for 0.3 s over a picture of the old screen. Audited
        // mid-fade, the old screen's text is visible but not in the tree, which the audit
        // reports as "Potentially inaccessible text" with no element.
        Thread.sleep(forTimeInterval: 0.6)
        attachTree(screen)
        try XCTContext.runActivity(named: "Audit \(screen)") { _ in
            try app.performAccessibilityAudit { issue in
                // The Home wordmark is the app's name drawn as a logo: at least 46 pt, and
                // it grows with the text size only until it fills one line (Plan 03 Stage 2),
                // so the name never breaks mid-word or pushes Play off the screen. Only
                // this one check on this one label is excused.
                if issue.auditType == .dynamicType, issue.element?.label == "Helichopter" { return true }
                // Name the element in the log; the failure message alone does not.
                print("AUDIT ISSUE on \(screen): \(issue.compactDescription) — \(issue.element?.debugDescription ?? "no element")")
                return false
            }
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
        app.launchArguments += ["-onboarding_completed_v1", "NO", "-gs_selectedThemeID", "nightSky"]
        app.launch()
        try audit("Guide, step 1")
        app.buttons["Next"].tap()
        try audit("Guide, step 2")
        app.buttons["Skip guide"].tap()
        try audit("Home")

        app.buttons["Hangar"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        try audit("Hangar")
        for name in ["Classic Helicopter", "Classic Pipes"] {
            let card = app.buttons[name]
            XCTAssertTrue(card.exists, "\(name) is one button")
            XCTAssertTrue(card.isSelected, "\(name) is equipped")
            XCTAssertEqual(card.value as? String, "Equipped")
        }
        app.buttons["Back"].tap()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5), "Back must be read as Back, without its arrow")
        try audit("Settings, top")
        let pointer = app.buttons.matching(NSPredicate(format: "label == %@", "Menu Theme: Night Sky. Change it in the Hangar"))
        var sawPointer = pointer.count == 1
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
            sawPointer = sawPointer || pointer.count == 1
        }
        XCTAssertTrue(sawPointer, "Settings points to the Hangar for the menu theme")
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

    /// Auto Hover and Up/Down Switches split the play screen into Fly up and Fly down,
    /// with a divider and Up and Down labels.
    func testSplitFlightScreenPassesTheAudit() throws {
        for scheme in ["2", "3"] {
            app.launchArguments = ["-gs_noFailMode", "<true/>", "-gs_scanningEnabled", "NO", "-gs_isSettingsLocked", "NO",
                                   "-onboarding_completed_v1", "YES", "-gs_controlScheme", "<integer>\(scheme)</integer>"]
            app.launch()
            app.buttons["Play"].tap()
            XCTAssertTrue(app.buttons["Fly up"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Fly down"].exists)
            XCTAssertFalse(app.buttons["Helicopter flight control"].exists)
            try audit("Playing, split screen \(scheme)")
            app.buttons["Fly down"].tap()
            app.buttons["Fly up"].tap()
            app.buttons["Pause"].tap()
            XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    /// The Hangar rebuilds in each theme's colours when a card is chosen. The theme is
    /// not set by a launch argument here: that would hide the choice the cards save.
    func testHangarPassesTheAuditInEveryTheme() throws {
        app.launchArguments += ["-onboarding_completed_v1", "YES"]
        app.launch()
        app.buttons["Hangar"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        for theme in ["Night Sky", "Parchment", "Neon Night", "Night Sky"] {
            app.buttons[theme].tap()
            let chosen = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: app.buttons[theme])
            XCTAssertEqual(XCTWaiter.wait(for: [chosen], timeout: 5), .completed, "\(theme) card must be marked selected")
            Thread.sleep(forTimeInterval: 0.5) // The rebuilt panel fades in.
            try audit("Hangar, \(theme)")
        }
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Hangar"].waitForExistence(timeout: 5))
    }

    /// Choosing the other helicopter and pipes equips them, and the Hangar and the play
    /// screen pass the audit with them. Classic is equipped again at the end, because the
    /// choice is saved and the other tests expect Classic.
    func testOtherLooksPassTheAuditInTheHangarAndInPlay() throws {
        app.launchArguments += ["-onboarding_completed_v1", "YES"]
        app.launch()
        try equip(["Two Tone Helicopter", "Striped Pipes"])
        for name in ["Classic Helicopter", "Classic Pipes"] {
            XCTAssertFalse(app.buttons[name].isSelected, "\(name) is no longer equipped")
        }
        try audit("Hangar, other looks")
        app.buttons["Back"].tap()
        app.buttons["Play"].tap()
        XCTAssertTrue(app.buttons["Helicopter flight control"].waitForExistence(timeout: 5))
        app.buttons["Helicopter flight control"].tap()
        try audit("Playing, other looks")
        app.terminate()

        app.launch()
        try equip(["Classic Helicopter", "Classic Pipes"])
    }

    /// Opens the Hangar from Home and chooses each named look.
    private func equip(_ names: [String]) throws {
        app.buttons["Hangar"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        for name in names {
            app.buttons[name].tap()
            let chosen = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: app.buttons[name])
            XCTAssertEqual(XCTWaiter.wait(for: [chosen], timeout: 5), .completed, "\(name) card must be marked selected")
            XCTAssertEqual(app.buttons[name].value as? String, "Equipped")
            Thread.sleep(forTimeInterval: 0.5) // The rebuilt panel fades in.
        }
    }
}
