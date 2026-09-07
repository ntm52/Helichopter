import Testing
import SpriteKit
import GameplayKit
import GameController
@testable import Helichopter

@MainActor @Suite("Game lifecycle", .serialized)
struct GameLifecycleTests {
    private func withSettings(_ work: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let saved = defaults.dictionaryRepresentation()
        defer {
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("gs_") || ["bestScore", "lastScore", "isMusicOn"].contains(key) {
                defaults.removeObject(forKey: key)
            }
            for (key, value) in saved where key.hasPrefix("gs_") || ["bestScore", "lastScore", "isMusicOn"].contains(key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(false, for: .isMusicOn)
        GameSettings.shared.scanningEnabled = false
        try work()
    }

    @Test func bundledScenesAndAtlasLoad() throws {
        try withSettings {
            for name in ["TitleScene", "SettingsScene", "GameScene", "PauseScene", "FailedScene"] {
                for suffix in ["", " iPad"] {
                    #expect(SKScene(fileNamed: name + suffix) != nil)
                }
            }
            let frames = try SKTextureAtlas.upload(named: "Helicopter Player") { _, index in "r_player\(index)" }
            #expect(frames.count == 60)
            #expect(frames.allSatisfy { $0.size() == CGSize(width: 200, height: 200) })
        }
    }

    @Test func titleReplacesLegacyFourFrameAnimationOnPhoneAndPad() throws {
        try withSettings {
            for suffix in ["", " iPad"] {
                let scene = try #require(TitleScene(fileNamed: "TitleScene" + suffix))
                let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
                scene.didMove(to: view)
                #expect(scene.childNode(withName: "Animated Bird") == nil)
                let helicopter = try #require(scene.childNode(withName: "Animated Helicopter") as? HelicopterNode)
                #expect(helicopter.flyTextures?.count == 60)
                #expect(helicopter.animationTimeInterval == HelicopterNode.rotorFrameInterval)
                #expect(helicopter.physicsBody == nil)
                #expect(!helicopter.shouldAcceptTouches)
                #expect((helicopter.action(forKey: "rotorAnimation") != nil) == !UIAccessibility.isReduceMotionEnabled)
                // Re-presenting the same scene must not duplicate or restart the mascot.
                scene.didMove(to: view)
                #expect(scene.children.compactMap { $0 as? HelicopterNode }.count == 1)
                #expect(scene.childNode(withName: "Animated Helicopter") === helicopter)
            }
        }
    }

    @Test func pausePreservesGravityAndClearsHeldInput() throws {
        try withSettings {
            GameSettings.shared.controlScheme = .holdHover
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
            #expect(!heli.isAffectedByGravity)
            heli.switchPrimaryBegan()
            #expect(heli.isAffectedByGravity)
            #expect(heli.isHoveringHeld)
            #expect(scene.action(forKey: "Pipe Action") != nil)
            #expect(scene.stateMachine.enter(PausedState.self))
            #expect(!heli.isHoveringHeld)
            #expect(!heli.shouldAcceptTouches)
            #expect(scene.stateMachine.enter(PlayingState.self))
            #expect(heli.isAffectedByGravity)
            #expect(heli.shouldAcceptTouches)
            #expect(scene.action(forKey: "Pipe Action") != nil)
        }
    }

    @Test func pauseBeforeFirstInputDoesNotStartRun() throws {
        try withSettings {
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
            #expect(scene.stateMachine.enter(PausedState.self))
            #expect(scene.stateMachine.enter(PlayingState.self))
            #expect(!heli.isAffectedByGravity)
            #expect(heli.onFirstInput != nil)
            #expect(scene.action(forKey: "Pipe Action") == nil)
        }
    }

    @Test func retryPreservesFinalScoreAndWaitsForInput() throws {
        try withSettings {
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            let adapter = try #require(scene.sceneAdapter)
            let heli = try #require(adapter.playerCharacter as? HelicopterNode)
            adapter.score = 7
            #expect(scene.stateMachine.enter(GameOverState.self))
            #expect(UserDefaults.standard.integer(for: .lastScore) == 7)
            #expect(scene.stateMachine.enter(PlayingState.self))
            #expect(adapter.score == 0)
            #expect(!heli.isAffectedByGravity)
            #expect(heli.onFirstInput != nil)
            #expect(adapter.overlay == nil)
        }
    }

    @Test func hiddenButtonsAreNotScannable() {
        let scene = SKScene(size: CGSize(width: 400, height: 800))
        let container = SKNode()
        let button = ButtonNode(texture: nil, color: .white, size: CGSize(width: 100, height: 50))
        button.name = "Pause"
        button.buttonIdentifier = .pause
        button.isUserInteractionEnabled = true
        scene.addChild(container)
        container.addChild(button)
        #expect(scene.findAllButtonsInScene().count == 1)
        container.isHidden = true
        #expect(scene.findAllButtonsInScene().isEmpty)
        container.isHidden = false
        button.isUserInteractionEnabled = false
        #expect(scene.findAllButtonsInScene().isEmpty)
    }

    @Test func scorePreferenceAppliesFromFirstFrame() throws {
        try withSettings {
            GameSettings.shared.showScore = false
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            #expect(scene.currentScoreText == nil)
            #expect(scene.childNode(withName: "world")?.childNode(withName: "Score Node")?.isHidden == true)
        }
    }

    @Test func scenesReleaseBeforeAndAfterFirstInput() {
        withSettings {
            for startsRun in [false, true] {
                weak var releasedScene: GameScene?
                autoreleasepool {
                    let scene = GameScene(fileNamed: "GameScene")!
                    releasedScene = scene
                    if startsRun { scene.switchPrimaryBegan() }
                }
                #expect(releasedScene == nil)
            }
        }
    }

    @Test func interruptionClearsControlsAndRequiresExplicitResume() throws {
        try withSettings {
            GameSettings.shared.controlScheme = .twoSwitchUD
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
            let controller = GameViewController()
            controller.view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            (controller.view as? SKView)?.presentScene(scene)
            scene.switchPrimaryBegan()
            scene.switchSecondaryBegan()
            scene.sceneAdapter?.score = 4
            controller.suspendInput()
            let overlay = scene.sceneAdapter?.overlay
            controller.suspendInput()
            controller.resumeInput()
            #expect(scene.stateMachine.currentState is PausedState)
            #expect(scene.isPaused)
            #expect(scene.sceneAdapter?.overlay === overlay)
            #expect(scene.sceneAdapter?.score == 4)
            #expect(!heli.isTwoSwitchUpHeld && !heli.isTwoSwitchDownHeld)
            #expect(scene.stateMachine.enter(PlayingState.self))
            #expect(!scene.isPaused)
            #expect(scene.action(forKey: "Pipe Action") != nil)
        }
    }

    @Test func controllerDisconnectPausesHeldFlight() throws {
        try withSettings {
            GameSettings.shared.controlScheme = .holdHover
            let controller = GameViewController()
            controller.loadViewIfNeeded()
            let skView = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            controller.view = skView
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            skView.presentScene(scene)
            scene.switchPrimaryBegan()
            let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
            #expect(heli.isHoveringHeld)
            NotificationCenter.default.post(name: .GCControllerDidDisconnect, object: nil)
            #expect(scene.stateMachine.currentState is PausedState)
            #expect(!heli.isHoveringHeld)
        }
    }

    @Test func interruptionsPreserveReadyAndGameOverStates() throws {
        try withSettings {
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            scene.pauseForInterruption()
            #expect(scene.stateMachine.enter(PlayingState.self))
            #expect(scene.action(forKey: "Pipe Action") == nil)
            let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
            #expect(heli.onFirstInput != nil)
            #expect(!heli.isAffectedByGravity)
            scene.sceneAdapter?.score = 8
            #expect(scene.stateMachine.enter(GameOverState.self))
            let overlay = scene.sceneAdapter?.overlay
            scene.pauseForInterruption()
            #expect(scene.stateMachine.currentState is GameOverState)
            #expect(scene.sceneAdapter?.overlay === overlay)
            #expect(UserDefaults.standard.integer(for: .lastScore) == 8)
        }
    }

    @Test func hoverDampingMatchesAcrossFrameRates() throws {
        try withSettings {
            for scheme in [ControlScheme.autoHover, .twoSwitchUD] {
                GameSettings.shared.controlScheme = scheme
                var velocities: [CGFloat] = []
                for fps in [30, 60, 120] {
                    let heli = HelicopterNode(texture: nil, color: .white, size: CGSize(width: 50, height: 50))
                    heli.physicsBody = SKPhysicsBody(circleOfRadius: 20)
                    heli.physicsBody?.velocity.dy = 260
                    heli.update(1)
                    #expect(heli.physicsBody?.velocity.dy == 260)
                    for frame in 1...(fps / 5) {
                        heli.update(1 + Double(frame) / Double(fps))
                    }
                    velocities.append(try #require(heli.physicsBody?.velocity.dy))
                    heli.prepareForNewRun()
                    heli.update(100)
                    #expect(heli.delta == 0)
                    #expect(abs((heli.physicsBody?.velocity.dy ?? 0) - velocities.last!) < 0.001)
                }
                #expect(abs(velocities[0] - velocities[1]) < 0.001)
                #expect(abs(velocities[1] - velocities[2]) < 0.001)
                #expect(velocities[0] < 260 && velocities[0] > 5)
            }
        }
    }

    private func settingsScene() throws -> (SKView, SettingsScene) {
        GameSettings.shared.isSettingsLocked = false
        GameSettings.shared.scanScheme = .twoSwitch
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scene = try #require(SettingsScene(fileNamed: "SettingsScene"))
        view.presentScene(scene)
        return (view, scene)
    }

    private func focusSetting(_ label: String, in scene: SettingsScene) throws {
        let overlay = try #require(scene.settingsOverlay)
        let input: SwitchInputReceivable = scene
        if !overlay.switchScanner.isActive { input.switchPrimaryBegan() }
        for _ in 0..<overlay.switchScanner.items.count {
            let scanner = overlay.switchScanner
            if scanner.items[scanner.currentIndex].accessibilityScanLabel.hasPrefix(label) { return }
            input.switchSecondaryBegan()
        }
        Issue.record("Setting not reachable by switch: \(label)")
    }

    @Test func settingsSwitchReachesControlsAndBackWithoutLegacyScanner() throws {
        try withSettings {
            let (view, scene) = try settingsScene()
            defer { view.presentScene(nil) }
            let overlay = try #require(scene.settingsOverlay)
            let expected = ["Gentle", "Standard", "Challenge", "Gap Size", "Pipe Speed", "Hitbox Size",
                            "Background Scroll", "No-Fail Mode", "Calm Mode", "Show Score", "Auto-Scan Menus",
                            "Menu Scan Mode", "Scan Dwell Time", "In-Game Control", "Menu Theme",
                            "Sound Effects", "Music", "Lock Settings"] + GameSettings.allPalettes.map { $0.name }
            for label in expected { try focusSetting(label, in: scene) }
            #expect(overlay.scrollPosition.y > 0)
            #expect(scene.focusScanner?.isActive == false)
            try focusSetting("No-Fail Mode", in: scene)
            let previous = GameSettings.shared.noFailMode
            scene.switchPrimaryBegan()
            #expect(GameSettings.shared.noFailMode != previous)
            var backActivated = false
            overlay.onBack = { backActivated = true }
            try focusSetting("◀  Back", in: scene)
            scene.switchPrimaryBegan()
            #expect(backActivated)
            view.presentScene(nil)
            #expect(!overlay.switchScanner.isActive)
        }
    }

    @Test func settingsSwitchAdjustsSliderBothWaysAndReturnsToRow() throws {
        try withSettings {
            GameSettings.shared.backgroundScrollSpeed = 100
            let (view, scene) = try settingsScene()
            defer { view.presentScene(nil) }
            try focusSetting("Background Scroll", in: scene)
            let overlay = try #require(scene.settingsOverlay)
            scene.switchPrimaryBegan()
            #expect(overlay.switchScanner.items.count == 3)
            scene.switchPrimaryBegan() // Decrease.
            #expect(GameSettings.shared.backgroundScrollSpeed == 90)
            for _ in 0..<30 { scene.switchPrimaryBegan() }
            #expect(GameSettings.shared.backgroundScrollSpeed == 0)
            scene.switchSecondaryBegan() // Increase.
            for _ in 0..<30 { scene.switchPrimaryBegan() }
            #expect(GameSettings.shared.backgroundScrollSpeed == 200)
            scene.switchSecondaryBegan() // Done.
            scene.switchPrimaryBegan()
            #expect(overlay.focusedSetting == "Background Scroll")
            #expect(overlay.switchScanner.items.count > 3)
        }
    }

    @Test func settingsSwitchPreservesFocusAcrossThemePresetAndLockRebuilds() throws {
        try withSettings {
            let (view, scene) = try settingsScene()
            defer { view.presentScene(nil) }
            try focusSetting("Menu Theme", in: scene)
            let oldOverlay = try #require(scene.settingsOverlay)
            scene.switchPrimaryBegan()
            scene.switchSecondaryBegan() // Parchment.
            scene.switchPrimaryBegan()
            let themed = try #require(scene.settingsOverlay)
            #expect(themed !== oldOverlay)
            #expect(!oldOverlay.switchScanner.isActive)
            #expect(themed.focusedSetting == "Menu Theme")
            #expect(GameSettings.shared.selectedThemeID == GameSettings.allThemes[1].id)
            try focusSetting("Gentle", in: scene)
            scene.switchPrimaryBegan()
            #expect(scene.settingsOverlay?.focusedSetting == "Gentle")
            #expect(GameSettings.shared.gapMin == GameSettings.gentlePreset.gapMin)
            try focusSetting("Lock Settings", in: scene)
            scene.switchPrimaryBegan()
            #expect(GameSettings.shared.isSettingsLocked)
            #expect(scene.settingsOverlay?.switchScanner.items.count == 2)
            #expect(scene.settingsOverlay?.focusedSetting == "Lock Settings")
            scene.switchPrimaryBegan()
            #expect(!GameSettings.shared.isSettingsLocked)
            #expect((scene.settingsOverlay?.switchScanner.items.count ?? 0) > 2)
        }
    }

    @Test func settingsSwitchSelectsPaletteAndChangesScanMode() throws {
        try withSettings {
            let (view, scene) = try settingsScene()
            defer { view.presentScene(nil) }
            let palette = try #require(GameSettings.allPalettes.last)
            try focusSetting(palette.name, in: scene)
            scene.switchPrimaryBegan()
            #expect(GameSettings.shared.selectedPaletteID == palette.id)
            try focusSetting("Menu Scan Mode", in: scene)
            scene.switchPrimaryBegan()
            scene.switchPrimaryBegan() // Auto-Advance.
            #expect(GameSettings.shared.scanScheme == .autoScan)
            #expect(scene.settingsOverlay?.focusedSetting == "Menu Scan Mode")
            scene.switchPrimaryBegan()
            scene.switchSecondaryBegan()
            scene.switchPrimaryBegan() // Two-Switch.
            #expect(GameSettings.shared.scanScheme == .twoSwitch)
        }
    }


    @Test func settingsOneSwitchCanAdjustAndReturnUsingTimedScanning() async throws {
        let gs = GameSettings.shared
        let savedScheme = gs.scanScheme
        let savedDwell = gs.scanDwellTime
        let savedEnabled = gs.scanningEnabled
        let savedLocked = gs.isSettingsLocked
        let savedSpeed = gs.backgroundScrollSpeed
        defer {
            gs.scanScheme = savedScheme
            gs.scanDwellTime = savedDwell
            gs.scanningEnabled = savedEnabled
            gs.isSettingsLocked = savedLocked
            gs.backgroundScrollSpeed = savedSpeed
        }
        gs.scanningEnabled = false
        gs.backgroundScrollSpeed = 100
        let (view, scene) = try settingsScene()
        defer { view.presentScene(nil) }
        gs.scanScheme = .autoScan
        gs.scanDwellTime = 0.1
        let overlay = try #require(scene.settingsOverlay)
        let input: SwitchInputReceivable = scene
        input.switchPrimaryBegan()

        func activateWhenScanned(_ label: String) async throws {
            let deadline = Date().addingTimeInterval(6)
            while Date() < deadline {
                let scanner = overlay.switchScanner
                if scanner.items[scanner.currentIndex].accessibilityScanLabel.hasPrefix(label) {
                    input.switchPrimaryBegan()
                    return
                }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            Issue.record("Auto-scan did not reach \(label)")
        }

        try await activateWhenScanned("Background Scroll")
        #expect(overlay.switchScanner.items.count == 3)
        try await activateWhenScanned("Increase")
        #expect(gs.backgroundScrollSpeed == 110)
        try await activateWhenScanned("Done")
        #expect(overlay.focusedSetting == "Background Scroll")
        var returned = false
        overlay.onBack = { returned = true }
        try await activateWhenScanned("◀  Back")
        #expect(returned)
        view.presentScene(nil)
        let stoppedIndex = overlay.switchScanner.currentIndex
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(!overlay.switchScanner.isActive)
        #expect(overlay.switchScanner.currentIndex == stoppedIndex)
    }


    @Test func settingsAdjustmentLayoutsOnSmallPhoneAndLandscapeTablet() throws {
        try withSettings {
            for size in [CGSize(width: 320, height: 568), CGSize(width: 1024, height: 768)] {
                let (view, scene) = try settingsScene()
                defer { view.presentScene(nil) }
                view.frame.size = size
                let overlay = try #require(scene.settingsOverlay)
                overlay.frame = view.bounds
                try focusSetting("Menu Theme", in: scene)
                overlay.layoutIfNeeded()
                let renderer = UIGraphicsImageRenderer(bounds: overlay.bounds)
                Attachment.record(try #require(renderer.image { overlay.layer.render(in: $0.cgContext) }.pngData()),
                                  named: "Settings-focus-\(Int(size.width)).png")
                scene.switchPrimaryBegan()
                overlay.layoutIfNeeded()
                Attachment.record(try #require(renderer.image { overlay.layer.render(in: $0.cgContext) }.pngData()),
                                  named: "Settings-choices-\(Int(size.width)).png")
                #expect(overlay.switchScanner.items.count == GameSettings.allThemes.count + 1)
                for _ in GameSettings.allThemes { scene.switchSecondaryBegan() }
                scene.switchPrimaryBegan() // Done.
                try focusSetting("Background Scroll", in: scene)
                scene.switchPrimaryBegan()
                overlay.layoutIfNeeded()
                Attachment.record(try #require(renderer.image { overlay.layer.render(in: $0.cgContext) }.pngData()),
                                  named: "Settings-slider-\(Int(size.width)).png")
            }
        }
    }

}
