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
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("gs_") || ["bestScore", "lastScore", "isMusicOn", "isSoundEffectsOn", "difficulty"].contains(key) {
                defaults.removeObject(forKey: key)
            }
            for (key, value) in saved where key.hasPrefix("gs_") || ["bestScore", "lastScore", "isMusicOn", "isSoundEffectsOn", "difficulty"].contains(key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(false, for: .isMusicOn)
        GameSettings.shared.scanningEnabled = false
        try work()
    }

    private func withAsyncSettings(_ work: () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let saved = defaults.dictionaryRepresentation()
        defer {
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("gs_") || ["bestScore", "lastScore", "isMusicOn", "isSoundEffectsOn", "difficulty"].contains(key) {
                defaults.removeObject(forKey: key)
            }
            for (key, value) in saved where key.hasPrefix("gs_") || ["bestScore", "lastScore", "isMusicOn", "isSoundEffectsOn", "difficulty"].contains(key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(false, for: .isMusicOn)
        GameSettings.shared.scanningEnabled = false
        try await work()
    }

    private func activateGameItem(_ action: MenuAction, in scene: GameScene) async throws {
        for _ in 0..<150 {
            if let scanner = scene.overlayScanner, scanner.isActive,
               let item = scanner.items[scanner.currentIndex] as? GameMenuItem,
               item.action == action {
                scene.switchPrimaryBegan()
                scene.switchPrimaryEnded()
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        Issue.record("Switch menu item not reachable: \(action)")
    }

    @Test func heldPrimaryPausesEveryFlightSchemeAndResumesWithOneSwitch() async throws {
        try await withAsyncSettings {
            let gs = GameSettings.shared
            gs.switchPauseHoldDuration = 2
            gs.scanScheme = .autoScan
            gs.scanDwellTime = 0.5
            gs.noFailMode = true
            for scheme in [ControlScheme.tapFlap, .holdHover, .autoHover, .twoSwitchUD] {
                gs.controlScheme = scheme
                let scene = try #require(GameScene(fileNamed: "GameScene"))
                let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
                scene.switchPrimaryBegan()
                let gravityBeforePause = heli.isAffectedByGravity
                scene.sceneAdapter?.score = 5
                // Keyboard repeat must neither re-flap nor restart the hold deadline.
                try await Task.sleep(nanoseconds: 1_100_000_000)
                scene.switchPrimaryBegan()
                // Checked at 2.6 s: a 2 s hold has fired, while a restarted one (3.1 s) would not.
                try await Task.sleep(nanoseconds: 1_500_000_000)
                #expect(scene.stateMachine.currentState is PausedState)
                #expect(scene.isPaused)
                #expect(scene.overlayScanner?.isActive == true)
                #expect(!heli.isHoveringHeld && !heli.isTwoSwitchUpHeld && !heli.isTwoSwitchDownHeld)
                scene.switchPrimaryBegan() // Still held: cannot activate the overlay.
                #expect(scene.stateMachine.currentState is PausedState)
                scene.switchPrimaryEnded()
                try await activateGameItem(.resume, in: scene)
                #expect(scene.stateMachine.currentState is PlayingState)
                #expect(!scene.isPaused)
                #expect(scene.sceneAdapter?.score == 5)
                #expect(heli.isAffectedByGravity == gravityBeforePause)
                #expect(scene.action(forKey: "Pipe Action") != nil)
                #expect(scene.overlayScanner == nil)
            }
        }
    }

    @Test func releasedOrInterruptedHoldsCannotPauseLaterRuns() async throws {
        try await withAsyncSettings {
            GameSettings.shared.switchPauseHoldDuration = 2
            let released = try #require(GameScene(fileNamed: "GameScene"))
            released.switchPrimaryBegan()
            released.switchPrimaryEnded()
            let interrupted = try #require(GameScene(fileNamed: "GameScene"))
            interrupted.switchPrimaryBegan()
            interrupted.pauseForInterruption()
            #expect(interrupted.stateMachine.enter(PlayingState.self))
            let ended = try #require(GameScene(fileNamed: "GameScene"))
            ended.switchPrimaryBegan()
            #expect(ended.stateMachine.enter(GameOverState.self))
            ended.switchPrimaryEnded()
            #expect(ended.stateMachine.enter(PlayingState.self))
            let scenes = [released, interrupted, ended]
            // An unpresented SpriteKit archive can already report isPaused.
            let pausedBeforeWait = scenes.map { $0.isPaused }
            try await Task.sleep(nanoseconds: 2_200_000_000)
            for (scene, wasPaused) in zip(scenes, pausedBeforeWait) {
                #expect(scene.stateMachine.currentState is PlayingState)
                #expect(scene.isPaused == wasPaused)
            }
        }
    }

    @Test func oneSwitchCanRetryAndReturnHome() async throws {
        try await withAsyncSettings {
            let gs = GameSettings.shared
            gs.switchPauseHoldDuration = 2
            gs.scanScheme = .autoScan
            gs.scanDwellTime = 0.5
            gs.scanningEnabled = true
            gs.noFailMode = true
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let windowScene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: windowScene)
            let controller = UIViewController()
            controller.view = view
            window.rootViewController = controller
            window.isHidden = false
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            scene.scaleMode = .aspectFit
            view.presentScene(scene)
            defer {
                view.presentScene(nil)
                window.isHidden = true
                window.rootViewController = nil
            }
            scene.switchPrimaryBegan()
            scene.switchPrimaryEnded()
            scene.sceneAdapter?.score = 6
            #expect(scene.stateMachine.enter(GameOverState.self))
            scene.setupOverlayScanner()
            try await activateGameItem(.retry, in: scene)
            #expect(scene.stateMachine.currentState is PlayingState)
            #expect(scene.sceneAdapter?.score == 0)
            #expect(scene.action(forKey: "Pipe Action") == nil)
            scene.switchPrimaryBegan()
            try await Task.sleep(nanoseconds: 2_200_000_000)
            #expect(scene.stateMachine.currentState is PausedState)
            scene.switchPrimaryEnded()
            let scanner = try #require(scene.overlayScanner)
            try await activateGameItem(.home, in: scene)
            // A bare view has no Home screen to show; it just leaves the game.
            #expect(view.scene == nil)
            #expect(!scanner.isActive)
        }
    }

    @Test func switchPausePreservesManualScanningAndCancelsOnSceneRemoval() async throws {
        try await withAsyncSettings {
            let gs = GameSettings.shared
            gs.controlScheme = .twoSwitchUD
            gs.scanScheme = .twoSwitch
            gs.switchPauseHoldDuration = 2
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            scene.switchSecondaryBegan()
            scene.switchPrimaryBegan()
            try await Task.sleep(nanoseconds: 2_200_000_000)
            #expect(scene.stateMachine.currentState is PausedState)
            let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
            #expect(!heli.isTwoSwitchUpHeld && !heli.isTwoSwitchDownHeld)
            scene.switchPrimaryEnded()
            scene.switchSecondaryEnded()
            let scanner = try #require(scene.overlayScanner)
            let originalIndex = scanner.currentIndex
            try await Task.sleep(nanoseconds: 150_000_000)
            #expect(scanner.currentIndex == originalIndex)
            for _ in scanner.items.indices {
                if (scanner.items[scanner.currentIndex] as? GameMenuItem)?.action == .resume { break }
                scene.switchSecondaryBegan()
                scene.switchSecondaryEnded()
            }
            scene.switchPrimaryBegan()
            // A repeated menu activation must not become flight input after Resume.
            scene.switchPrimaryBegan()
            #expect(!heli.isTwoSwitchUpHeld)
            scene.switchPrimaryEnded()
            #expect(scene.stateMachine.currentState is PlayingState)

            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let removed = try #require(GameScene(fileNamed: "GameScene"))
            view.presentScene(removed)
            removed.switchPrimaryBegan()
            view.presentScene(nil)
            try await Task.sleep(nanoseconds: 2_200_000_000)
            #expect(removed.stateMachine.currentState is PlayingState)
            #expect(removed.overlayScanner == nil)
        }
    }

    @Test func switchPauseDelayIsBoundedAndPersisted() {
        withSettings {
            let settings = GameSettings.shared
            UserDefaults.standard.removeObject(forKey: "gs_switchPauseHoldDuration")
            #expect(settings.switchPauseHoldDuration == 3)
            settings.switchPauseHoldDuration = 7
            #expect(GameSettings(defaults: .standard).switchPauseHoldDuration == 7)
            settings.switchPauseHoldDuration = -1
            #expect(settings.switchPauseHoldDuration == 2)
            settings.switchPauseHoldDuration = 50
            #expect(settings.switchPauseHoldDuration == 10)
            settings.switchPauseHoldDuration = .nan
            #expect(settings.switchPauseHoldDuration == 3)
        }
    }

    @Test func renderedGameplayBoundariesAcrossEveryThemeAndPalette() throws {
        try withSettings {
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            for theme in GameSettings.allThemes {
                for palette in GameSettings.allPalettes {
                    GameSettings.shared.selectedThemeID = theme.id
                    GameSettings.shared.selectedPaletteID = palette.id
                    let scene = try #require(GameScene(fileNamed: "GameScene"))
                    scene.scaleMode = .aspectFit
                    view.presentScene(scene)
                    defer { view.presentScene(nil) }
                    let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
                    heli.removeAllActions()
                    heli.physicsBody?.isDynamic = false
                    // Include actual sky, theme overrides, shaded art and both cap directions.
                    for side in [false, true] {
                        let pipe = try #require(PipeNode(textures: ("pipe-yellow", "cap-yellow"),
                            of: CGSize(width: 110, height: 200), side: side,
                            tintColor: palette.pipeColor, blendFactor: palette.colorBlendFactor))
                        pipe.position = CGPoint(x: scene.frame.minX + scene.size.width * 0.7,
                                                y: side ? scene.frame.maxY - 100 : scene.frame.minY + 100)
                        scene.addChild(pipe)
                        try assertRenderedBoundary(pipe, in: view)
                    }
                    try assertRenderedBoundary(heli, in: view)
                    heli.triggerInvulnerability()
                    #expect(heli.alpha == 1)
                    heli.endInvulnerability()
                    #expect(heli.alpha == 1 && abs(heli.colorBlendFactor - 0.35) < 0.0001)
                    let texture = try #require(view.texture(from: scene, crop: scene.frame))
                    Attachment.record(try #require(UIImage(cgImage: texture.cgImage()).pngData()),
                                      named: "Gameplay-\(theme.id)-\(palette.id).png")
                }
            }
        }
    }

    private func assertRenderedBoundary(_ node: SKNode, in view: SKView) throws {
        let rendered = try #require(view.texture(from: node)).cgImage()
        let width = rendered.width, height = rendered.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(rendered, in: CGRect(x: 0, y: 0, width: width, height: height))
        var black = 0, white = 0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] == 255 {
            if pixels[i] < 5 && pixels[i + 1] < 5 && pixels[i + 2] < 5 { black += 1 }
            if pixels[i] > 250 && pixels[i + 1] > 250 && pixels[i + 2] > 250 { white += 1 }
        }
        #expect(black > width, "Opaque black boundary must survive SpriteKit rendering")
        #expect(white > width, "Opaque white boundary must survive SpriteKit rendering")
    }

    @Test func bundledScenesAndAtlasLoad() throws {
        try withSettings {
            for name in ["SettingsScene", "GameScene"] {
                for suffix in ["", " iPad"] {
                    #expect(SKScene(fileNamed: name + suffix) != nil)
                }
            }
            let frames = try SKTextureAtlas.upload(named: "Helicopter Player") { _, index in "r_player\(index)" }
            #expect(frames.count == 60)
            #expect(frames.allSatisfy { $0.size() == CGSize(width: 200, height: 200) })
        }
    }

    /// Home's mascot is the 60-frame rotor animation at the game's frame rate, and the
    /// title shows on phone and tablet widths.
    @Test func homeShowsTitleAndAnimatedMascotOnPhoneAndPad() throws {
        let saved = HomeViewController.prefersReducedMotion
        HomeViewController.prefersReducedMotion = { false }
        defer { HomeViewController.prefersReducedMotion = saved }
        try withSettings {
            for size in [CGSize(width: 390, height: 844), CGSize(width: 1024, height: 1366)] {
                let home = HomeViewController()
                home.view.frame = CGRect(origin: .zero, size: size)
                home.view.layoutIfNeeded()
                #expect(home.mascot.animationImages?.count == 60)
                #expect(abs(home.mascot.animationDuration - 60 * HelicopterNode.rotorFrameInterval) < 0.001)
                #expect(home.mascot.isAnimating)
                #expect(!home.mascot.isAccessibilityElement)
                #expect(home.titleLabel.text == "Helichopter")
                #expect(home.titleLabel.bounds.width > 0 && !home.titleLabel.isHidden)
            }
        }
    }

    @Test func scrollingBackgroundCoversPhoneAndPadScenes() throws {
        for suffix in ["", " iPad"] {
            let scene = try #require(GameScene(fileNamed: "GameScene" + suffix))
            let scroller = try #require(scene.sceneAdapter?.infiniteBackgroundNode)
            scroller.backgroundSpeed = 97
            scroller.update(1)
            for frame in 1...600 {
                scroller.update(1 + Double(frame) / 30)
                let frames = scroller.tiles.map { $0.calculateAccumulatedFrame() }
                    .map { scroller.background.convert($0.origin, to: scroller).x ... scroller.background.convert($0.origin, to: scroller).x + $0.width }
                // Every visible column of the scene lies under some tile.
                var covered: CGFloat = 0
                for span in frames.sorted(by: { $0.lowerBound < $1.lowerBound }) where span.lowerBound <= covered + 1 {
                    covered = max(covered, span.upperBound)
                }
                #expect(covered >= scene.size.width, "GameScene\(suffix) frame \(frame)")
                if covered < scene.size.width { break }
            }
        }
    }

    @Test func autoHoverNudgesAreBoundedAndGravityStaysOff() throws {
        try withSettings {
            GameSettings.shared.controlScheme = .autoHover
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
            heli.switchPrimaryBegan()
            heli.switchPrimaryEnded()
            #expect(!heli.isAffectedByGravity)
            #expect(heli.physicsBody?.velocity.dy == GameSettings.shared.terminalVelocity)
            // Repeated nudges replace the speed rather than stacking it.
            heli.switchPrimaryBegan()
            heli.switchPrimaryEnded()
            #expect(heli.physicsBody?.velocity.dy == GameSettings.shared.terminalVelocity)
            heli.switchSecondaryBegan()
            heli.switchSecondaryEnded()
            #expect(heli.physicsBody?.velocity.dy == -GameSettings.shared.terminalVelocity)
            // Each nudge glides a short, finite distance and settles.
            heli.update(1)
            var travelled: CGFloat = 0
            for frame in 1...120 {
                heli.update(1 + Double(frame) / 60)
                travelled += abs(heli.physicsBody?.velocity.dy ?? 0) / 60
            }
            #expect(heli.physicsBody?.velocity.dy == 0)
            #expect(travelled > 40 && travelled < scene.size.height / 5)
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
            #expect(scene.phase == .playing && scene.menuItems.isEmpty)
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
            let menu = scene.menuItems
            controller.suspendInput()
            controller.resumeInput()
            #expect(scene.stateMachine.currentState is PausedState)
            #expect(scene.isPaused)
            #expect(scene.menuItems.map(\.action) == [.resume, .home])
            #expect(zip(scene.menuItems, menu).allSatisfy { $0 === $1 })
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
            scene.pauseForInterruption()
            #expect(scene.stateMachine.currentState is GameOverState)
            #expect(scene.menuItems.map(\.action) == [.home, .retry])
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

    @Test func gapsFitWithinSmallScenes() throws {
        try withSettings {
            GameSettings.shared.gapMin = 600
            GameSettings.shared.gapMax = 100
            for height in [CGFloat(121), 320, 568, 1024] {
                for _ in 0..<20 {
                    let parts = try #require(PipeFactory.standardPipeParts(for: CGSize(width: 320, height: height)))
                    #expect(parts.threshold.size.height > 0)
                    #expect(parts.top.size.height >= 50)
                    #expect(abs(parts.top.size.height + parts.bottom.size.height + parts.threshold.size.height - height) < 0.001)
                }
            }
            #expect(PipeFactory.standardPipeParts(for: .zero) == nil)
        }
    }

    @Test func newHighScoreCelebratesOncePerRunAndSavesImmediately() throws {
        try withSettings {
            let defaults = UserDefaults.standard
            GameSettings.shared.showScore = true
            defaults.set(3, for: .bestScore)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let game = try #require(GameScene(fileNamed: "GameScene"))
            view.presentScene(game)
            defer { view.presentScene(nil) }
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            overlay.refresh(in: view)
            // No refresh: the banner must follow the scene's events alone.
            func bannerVisible() -> Bool {
                func find(_ v: UIView) -> UILabel? {
                    (v as? UILabel).flatMap { $0.text == "New high score!" ? $0 : nil } ?? v.subviews.lazy.compactMap(find).first
                }
                return find(overlay).map { !$0.isHidden } ?? false
            }
            let adapter = try #require(game.sceneAdapter)
            #expect(adapter.bestAtRunStart == 3)
            for _ in 0..<3 { adapter.scorePoint() }
            #expect(!adapter.isShowingNewHighScore && !bannerVisible())
            adapter.scorePoint()
            #expect(adapter.isShowingNewHighScore && bannerVisible())
            // Saved at once, so a No-Fail run that never reaches Round Over keeps its record.
            #expect(defaults.integer(for: .bestScore) == 4)
            GameSettings.shared.showScore = false
            #expect(!adapter.isShowingNewHighScore)
            GameSettings.shared.showScore = true
            #expect(game.stateMachine.enter(PausedState.self))
            #expect(!bannerVisible())
            #expect(game.stateMachine.enter(PlayingState.self))
            adapter.scorePoint()
            #expect(defaults.integer(for: .bestScore) == 5)

            // A retry is a new run measured against the updated record, celebrating only once.
            #expect(game.stateMachine.enter(GameOverState.self))
            #expect(game.stateMachine.enter(PlayingState.self))
            #expect(adapter.bestAtRunStart == 5 && !adapter.isShowingNewHighScore)
            for _ in 0..<5 { adapter.scorePoint() }
            #expect(!adapter.isShowingNewHighScore)
            adapter.scorePoint()
            #expect(adapter.isShowingNewHighScore)

            // No existing record: the first points are not a "new high score".
            defaults.set(0, for: .bestScore)
            #expect(game.stateMachine.enter(GameOverState.self))
            defaults.set(0, for: .bestScore)
            #expect(game.stateMachine.enter(PlayingState.self))
            adapter.scorePoint()
            #expect(!adapter.isShowingNewHighScore)
            #expect(defaults.integer(for: .bestScore) == 1)
        }
    }

    @Test func privacyAndAcknowledgementsReachableBySwitchWhenLocked() throws {
        try withSettings {
            let (view, scene) = try settingsScene()
            defer { view.presentScene(nil) }
            GameSettings.shared.isSettingsLocked = true
            let overlay = try #require(scene.settingsOverlay)
            overlay.onThemeChanged?()
            let locked = try #require(scene.settingsOverlay)
            for (label, expected) in [("Privacy Policy", "Open Full Policy in Safari"), ("Acknowledgements", "Done")] {
                try focusSetting(label, in: scene)
                scene.switchPrimaryBegan()
                #expect(locked.isAdjusting)
                #expect(locked.switchScanner.items[0].accessibilityScanLabel == expected)
                let texts = [AppLinks.privacySummary, AppLinks.acknowledgements]
                #expect(locked.subviews.contains { panel in
                    func labels(_ v: UIView) -> [String] { ((v as? UILabel)?.text).map { [$0] } ?? v.subviews.flatMap(labels) }
                    return labels(panel).contains { texts.contains($0) }
                })
                // Done is the last choice in both panels.
                let scanner = locked.switchScanner
                while scanner.items[scanner.currentIndex].accessibilityScanLabel != "Done" { scene.switchSecondaryBegan() }
                scene.switchPrimaryBegan()
                #expect(!locked.isAdjusting)
            }
            #expect(AppLinks.acknowledgements.contains("Copyright (c) 2018, Astemir Eleev"))
            #expect(AppLinks.privacySummary.contains(AppLinks.supportEmail))
        }
    }

    @Test func resetCanBeCancelledAndConfirmedBySwitch() throws {
        try withSettings {
            GameSettings.shared.applyChallenge()
            let (view, scene) = try settingsScene()
            defer { view.presentScene(nil) }
            try focusSetting("Reset Settings", in: scene)
            scene.switchPrimaryBegan()
            let overlay = try #require(scene.settingsOverlay)
            #expect(overlay.isAdjusting)
            #expect(overlay.switchScanner.items[0].accessibilityScanLabel == "Cancel")
            scene.switchPrimaryBegan()
            #expect(!overlay.isAdjusting)
            #expect(GameSettings.shared.gapMin == 180)
            scene.switchPrimaryBegan()
            scene.switchSecondaryBegan()
            scene.switchPrimaryBegan()
            #expect(GameSettings.shared.gapMin == 240)
            #expect(scene.settingsOverlay?.isAdjusting == false)
            #expect(scene.settingsOverlay?.switchScanner.isActive == true)
        }
    }

    @Test func settingsSwitchReachesControlsAndBackWithoutLegacyScanner() throws {
        try withSettings {
            let (view, scene) = try settingsScene()
            defer { view.presentScene(nil) }
            let overlay = try #require(scene.settingsOverlay)
            let expected = ["Gentle", "Standard", "Challenge", "Gap Size", "Pipe Speed", "Hitbox Size",
                            "Background Scroll", "No-Fail Mode", "Calm Mode", "Show Score", "Auto-Scan Menus",
                            "Menu Scan Mode", "Scan Dwell Time", "In-Game Control", "Hold Switch to Pause", "Menu Theme",
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
            // Back, Lock Settings, Privacy Policy, Acknowledgements.
            #expect(scene.settingsOverlay?.switchScanner.items.count == 4)
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
        gs.scanDwellTime = 0.5
        let overlay = try #require(scene.settingsOverlay)
        let input: SwitchInputReceivable = scene
        input.switchPrimaryBegan()

        func activateWhenScanned(_ label: String) async throws {
            let deadline = Date().addingTimeInterval(25)
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
