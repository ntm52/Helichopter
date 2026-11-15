import Testing
import SpriteKit
import GameplayKit
import UIKit
@testable import Helichopter

/// Fixes from the accessibility audit of 2026-11-15. Each test names the problem it
/// keeps from coming back.
@MainActor @Suite("Accessibility audit fixes", .serialized)
struct AccessibilityAuditFixTests {

    private func makeSettings(_ page: SettingsPage) -> (SettingsPanelView, UIWindow) {
        let size = CGSize(width: 390, height: 844)
        let panel = SettingsPanelView(frame: CGRect(origin: .zero, size: size), theme: GameSettings.shared.selectedTheme, page: page)
        let window = makeTestWindow(frame: CGRect(origin: .zero, size: size))
        let host = UIViewController()
        host.view = panel
        window.rootViewController = host
        window.makeKeyAndVisible()
        panel.layoutIfNeeded()
        return (panel, window)
    }

    private func withUnlockedSettings(_ work: () throws -> Void) rethrows {
        let gs = GameSettings.shared
        let savedLock = gs.isSettingsLocked
        let savedScanning = gs.scanningEnabled
        let savedScheme = gs.scanScheme
        defer {
            gs.isSettingsLocked = savedLock
            gs.scanningEnabled = savedScanning
            gs.scanScheme = savedScheme
        }
        gs.isSettingsLocked = false
        gs.scanningEnabled = false
        gs.scanScheme = .twoSwitch
        try work()
    }

    /// A page opened by a finger, VoiceOver, or Voice Control used to start the switch
    /// scanner: a moving highlight and a second voice for players who never asked for one,
    /// which then carried on over the Settings list after Done.
    @Test func pagesOpenedWithoutASwitchDoNotStartTheScanner() throws {
        try withUnlockedSettings {
            let (panel, window) = makeSettings(.menu)
            defer { window.isHidden = true }
            let privacy = try #require(panel.control(labelled: "Privacy Policy"))
            privacy.sendActions(for: .touchUpInside)
            #expect(panel.isAdjusting)
            #expect(!panel.switchScanner.isActive)
            panel.closeAdjustment()
            #expect(!panel.isAdjusting)
            #expect(!panel.switchScanner.isActive)

            // A first switch press on an open page scans that page only, not the list under it.
            privacy.sendActions(for: .touchUpInside)
            panel.primaryActivate()
            #expect(panel.switchScanner.isActive)
            #expect(panel.switchScanner.items.map(\.accessibilityScanLabel) == ["Open Full Policy in Safari", "Done"])
            panel.closeAdjustment()
            // A player who was scanning keeps scanning, back on the control they came from.
            #expect(panel.switchScanner.isActive)
            #expect(panel.focusedSetting == "Privacy Policy")
            panel.stopScanning()
        }
    }

    /// With VoiceOver on, the scanner's own voice talked over VoiceOver.
    @Test func scannerHandsItsWordsToVoiceOverWhenVoiceOverIsOn() {
        let savedRunning = FocusScanner.isVoiceOverRunning
        let savedAnnounce = FocusScanner.announce
        defer {
            FocusScanner.isVoiceOverRunning = savedRunning
            FocusScanner.announce = savedAnnounce
        }
        var announced: [String] = []
        FocusScanner.announce = { announced.append($0) }
        let settings = GameSettings(defaults: UserDefaults(suiteName: "AuditFixTests.\(UUID().uuidString)")!)
        settings.scanScheme = .twoSwitch
        let scanner = FocusScanner(settings: settings)
        scanner.items = [MenuItem("First", hint: "", action: {}), MenuItem("Second", hint: "", action: {})]

        FocusScanner.isVoiceOverRunning = { false }
        scanner.start()
        #expect(announced.isEmpty)
        FocusScanner.isVoiceOverRunning = { true }
        scanner.secondaryAdvance()
        #expect(announced == ["Second"])
        scanner.stop()
    }

    /// "Decrease. Value: 37%" cannot be said to Voice Control; "Tap Decrease" can.
    @Test func sliderPageButtonsHaveShortVoiceControlNames() throws {
        try withUnlockedSettings {
            let (panel, window) = makeSettings(.category(.difficulty))
            defer { window.isHidden = true }
            let gap = try #require(panel.control(labelled: "Gap Size") as? UISlider)
            #expect(gap.accessibilityActivate())
            let page = try #require(panel.adjustmentPanel)
            let buttons = panel.controls(in: page).compactMap { $0 as? UIButton }
            for name in ["Decrease", "Increase"] {
                let button = try #require(buttons.first { $0.currentTitle == name })
                #expect(button.accessibilityUserInputLabels == [name])
                button.sendActions(for: .touchUpInside)
                // The short name survives the value changing.
                #expect(button.accessibilityUserInputLabels == [name])
                #expect(button.accessibilityLabel == "\(name). Value: \(gap.spokenValue)")
            }
            panel.closeAdjustment()
        }
    }

    /// VoiceOver's escape gesture did nothing anywhere in the app.
    @Test func escapeGestureClosesAPageThenGoesBack() throws {
        try withUnlockedSettings {
            let (panel, window) = makeSettings(.menu)
            defer { window.isHidden = true }
            var wentBack = 0
            panel.onBack = { wentBack += 1 }
            try #require(panel.control(labelled: "Reset Settings")).sendActions(for: .touchUpInside)
            #expect(panel.isAdjusting)
            #expect(panel.accessibilityPerformEscape())
            #expect(!panel.isAdjusting && wentBack == 0)
            #expect(panel.accessibilityPerformEscape())
            #expect(wentBack == 1)
        }
    }

    @Test func escapeGestureResumesAPausedGameOnly() throws {
        let gs = GameSettings.shared
        let savedScanning = gs.scanningEnabled
        let savedNoFail = gs.noFailMode
        let savedMusic = UserDefaults.standard.object(forKey: "isMusicOn")
        defer {
            gs.scanningEnabled = savedScanning
            gs.noFailMode = savedNoFail
            if let savedMusic = savedMusic { UserDefaults.standard.set(savedMusic, forKey: "isMusicOn") }
            else { UserDefaults.standard.removeObject(forKey: "isMusicOn") }
        }
        gs.scanningEnabled = false
        UserDefaults.standard.set(false, for: .isMusicOn)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let game = try #require(GameScene(fileNamed: "GameScene"))
        view.presentScene(game)
        defer { view.presentScene(nil) }
        let overlay = SceneTextOverlay(frame: view.bounds)
        view.addSubview(overlay)
        overlay.refresh(in: view)

        game.pauseForInterruption()
        let paused = try #require(overlay.gameMenu)
        #expect(paused.accessibilityPerformEscape())
        #expect(game.phase == .playing)
        #expect(overlay.gameMenu == nil)

        game.stateMachine.enter(GameOverState.self)
        let roundOver = try #require(overlay.gameMenu)
        #expect(!roundOver.accessibilityPerformEscape())
        #expect(game.phase == .roundOver)
    }

    /// Scanner speech named a choice but never said which one was chosen.
    @Test func scannerSaysWhichChoiceIsChosen() throws {
        try withUnlockedSettings {
            let gs = GameSettings.shared
            let savedControl = gs.controlScheme
            let savedPalette = gs.selectedPaletteID
            let savedSkin = gs.selectedPipeSkinID
            defer {
                gs.controlScheme = savedControl
                gs.selectedPaletteID = savedPalette
                gs.selectedPipeSkinID = savedSkin
            }
            gs.controlScheme = .holdHover
            gs.selectedPaletteID = "highContrast"
            gs.select(CosmeticsCatalog.stripedPipes)

            let (controls, controlsWindow) = makeSettings(.category(.controls))
            defer { controlsWindow.isHidden = true }
            controls.startScanning()
            var spoken = controls.switchScanner.items.map(\.accessibilityScanLabel)
            #expect(spoken.contains("Hold to Hover, selected") && spoken.contains("Tap to Flap"))
            #expect(spoken.contains("Step with Switch 2, selected") && spoken.contains("Timed"))
            controls.stopScanning()

            let (colours, coloursWindow) = makeSettings(.category(.colours))
            defer { coloursWindow.isHidden = true }
            colours.startScanning()
            spoken = colours.switchScanner.items.map(\.accessibilityScanLabel)
            #expect(spoken.contains("High Contrast, selected") && spoken.contains("Default"))
            colours.stopScanning()

            let hangar = HangarPanelView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), theme: gs.selectedTheme)
            hangar.startScanning()
            spoken = hangar.switchScanner.items.map(\.accessibilityScanLabel)
            #expect(spoken.contains("Striped Pipes, Equipped") && spoken.contains("Classic Pipes"))
            #expect(spoken.contains("\(gs.selectedTheme.name), selected"))
            hangar.stopScanning()
        }
    }

    /// The chosen palette was marked only by its border's colour and width.
    @Test func chosenPaletteIsMarkedByATick() throws {
        try withUnlockedSettings {
            let gs = GameSettings.shared
            let savedPalette = gs.selectedPaletteID
            defer { gs.selectedPaletteID = savedPalette }
            gs.selectedPaletteID = "default"
            let (panel, window) = makeSettings(.category(.colours))
            defer { window.isHidden = true }
            let swatches = panel.paletteViews.compactMap { $0 as? SwatchButton }
            #expect(swatches.count == GameSettings.allPalettes.count)
            #expect(swatches.map { !$0.mark.isHidden } == [true, false, false, false, false, false])
            #expect(swatches.allSatisfy { $0.mark.image != nil && !$0.mark.isAccessibilityElement })
            swatches[2].sendActions(for: .touchUpInside)
            #expect(swatches.map { !$0.mark.isHidden } == [false, false, true, false, false, false])
            #expect(swatches.map { $0.accessibilityTraits.contains(.selected) } == [false, false, true, false, false, false])
            // The tick stays inside its card, clear of the name.
            panel.layoutIfNeeded()
            for swatch in swatches { #expect(swatch.bounds.contains(swatch.mark.frame)) }
        }
    }

    /// A switch was a 51 by 31 point target; now its name and description flip it too.
    @Test func tappingASwitchRowFlipsTheSwitch() throws {
        try withUnlockedSettings {
            let gs = GameSettings.shared
            let savedCalm = gs.calmMode
            defer { gs.calmMode = savedCalm }
            gs.calmMode = false
            let (panel, window) = makeSettings(.category(.comfort))
            defer { window.isHidden = true }
            let calm = try #require(panel.control(labelled: "Calm Mode") as? UISwitch)
            let row = try #require(calm.superview)
            let taps = (row.gestureRecognizers ?? []).compactMap { $0 as? UITapGestureRecognizer }
            #expect(taps.count == 1)
            #expect(row.bounds.height >= 44 && row.bounds.width > calm.bounds.width * 3)
            let target = try #require(panel.controlTargets.compactMap { $0 as? RowTapTarget }.dropFirst().first)
            target.tapped()
            #expect(calm.isOn && gs.calmMode)
            target.tapped()
            #expect(!calm.isOn && !gs.calmMode)
            // A locked row's switch does not move.
            calm.isEnabled = false
            target.tapped()
            #expect(!calm.isOn && !gs.calmMode)
        }
    }

    /// Reduce Transparency asks for solid backgrounds; the pause menu was see-through.
    @Test func reduceTransparencyGivesThePauseMenuASolidBackground() throws {
        let gs = GameSettings.shared
        let savedHide = gs.hideGameWhilePaused
        let savedScanning = gs.scanningEnabled
        let savedMusic = UserDefaults.standard.object(forKey: "isMusicOn")
        let savedPreference = SceneTextOverlay.prefersReducedTransparency
        defer {
            gs.hideGameWhilePaused = savedHide
            gs.scanningEnabled = savedScanning
            SceneTextOverlay.prefersReducedTransparency = savedPreference
            if let savedMusic = savedMusic { UserDefaults.standard.set(savedMusic, forKey: "isMusicOn") }
            else { UserDefaults.standard.removeObject(forKey: "isMusicOn") }
        }
        gs.hideGameWhilePaused = false
        gs.scanningEnabled = false
        UserDefaults.standard.set(false, for: .isMusicOn)
        for (reduced, solid) in [(false, false), (true, true)] {
            SceneTextOverlay.prefersReducedTransparency = { reduced }
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let game = try #require(GameScene(fileNamed: "GameScene"))
            view.presentScene(game)
            defer { view.presentScene(nil) }
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            overlay.refresh(in: view)
            game.pauseForInterruption()
            var alpha: CGFloat = 0
            overlay.backgroundColor?.getWhite(nil, alpha: &alpha)
            #expect((alpha == 1) == solid)
        }
    }

    /// At the largest text size the flight hint sat over the middle of the screen: it
    /// covered the waiting helicopter and the Up and Down labels.
    @Test func largeFlightHintStaysClearOfTheHelicopterAndTheLabels() throws {
        let gs = GameSettings.shared
        let savedScheme = gs.controlScheme
        let savedMusic = UserDefaults.standard.object(forKey: "isMusicOn")
        defer {
            gs.controlScheme = savedScheme
            if let savedMusic = savedMusic { UserDefaults.standard.set(savedMusic, forKey: "isMusicOn") }
            else { UserDefaults.standard.removeObject(forKey: "isMusicOn") }
        }
        gs.controlScheme = .autoHover
        UserDefaults.standard.set(false, for: .isMusicOn)
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            // In a window, with the text size in place before the HUD is built.
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let window = makeTestWindow(frame: view.frame)
            let host = UIViewController()
            host.view = view
            window.rootViewController = host
            window.isHidden = false
            defer { window.isHidden = true }
            let game = try #require(GameScene(fileNamed: "GameScene"))
            view.presentScene(game)
            defer { view.presentScene(nil) }
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            overlay.traitOverrides.preferredContentSizeCategory = category
            overlay.updateTraitsIfNeeded()
            overlay.refresh(in: view)
            overlay.layoutIfNeeded()
            let hint = try #require(overlay.flightHintLabel)
            let hintFrame = hint.convert(hint.bounds, to: overlay)
            #expect(hint.alpha == 1 && hintFrame.height > 0)
            // The helicopter waits at the middle of the screen, 100 scene units tall.
            let helicopter = CGRect(x: 0, y: overlay.bounds.midY - 40, width: overlay.bounds.width, height: 80)
            #expect(!hintFrame.intersects(helicopter), "\(category): hint at \(hintFrame)")
            #expect(overlay.bounds.contains(hintFrame))
            #expect(overlay.upDownLabels.count == 2)
            for label in overlay.upDownLabels where !label.isHidden {
                #expect(!label.frame.intersects(hintFrame), "\(category)")
            }
            // VoiceOver still reads the hint, once.
            let listed = (overlay.accessibilityElements ?? []).filter { ($0 as? UIView) === hint }.count
            #expect(listed == (hint.superview === overlay ? 1 : 0))
            // Touches on the hint still reach the game.
            #expect(overlay.hitTest(CGPoint(x: hintFrame.midX, y: hintFrame.midY), with: nil) == nil)
            // Once the first input fades the hint, both labels show.
            game.hideFlightHint()
            overlay.layoutIfNeeded()
            #expect(overlay.upDownLabels.allSatisfy { !$0.isHidden })
        }
    }

    /// A switch user cannot scroll. Scanning down the guide's choices scrolled its words
    /// off the top, and coming round to the first choice did not bring them back.
    @Test func scanningBackToTheFirstChoiceShowsTheWordsAboveIt() throws {
        let gs = GameSettings.shared
        let savedScheme = gs.scanScheme
        defer { gs.scanScheme = savedScheme }
        gs.scanScheme = .twoSwitch
        let guide = GuideViewController(defaults: UserDefaults(suiteName: "AuditFixTests.\(UUID().uuidString)")!)
        guide.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        guide.view.layoutIfNeeded()
        let scroll = guide.menu.scroll
        #expect(scroll.contentSize.height > scroll.bounds.height)
        guide.scanner.start()
        let first = scroll.contentOffset.y
        for _ in guide.scanner.items.dropFirst() { guide.scanner.secondaryAdvance() }
        #expect(scroll.contentOffset.y > first)
        guide.scanner.secondaryAdvance()
        #expect(guide.scanner.currentIndex == 0)
        #expect(scroll.contentOffset.y == first)
        let button = try #require(guide.menu.buttons.first)
        #expect(scroll.bounds.contains(button.convert(button.bounds, to: scroll)))
        guide.scanner.stop()
    }

    /// The No-Fail bump pulsed 3.3 times a second; flashing must stay under three.
    @Test func noFailBumpPulsesUnderThreeTimesASecond() {
        #expect(1 / (2 * HelicopterNode.bumpPulseHalfPeriod) < 3)
    }
}
