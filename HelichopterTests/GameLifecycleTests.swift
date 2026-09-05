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
            #expect(frames.count == 20)
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
}
