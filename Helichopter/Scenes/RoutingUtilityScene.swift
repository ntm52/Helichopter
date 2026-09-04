import SpriteKit

class RoutingUtilityScene: SKScene, ButtonNodeResponderType {

    // MARK: - Properties

    let selection = UISelectionFeedbackGenerator()
    // Computed so that scenes loaded during iPad landscape use aspectFit (pillarbox),
    // keeping the full portrait game visible regardless of mount orientation.
    static var sceneScaleMode: SKSceneScaleMode {
        GameViewController.scaleMode(forSize: UIScreen.main.bounds.size)
    }
    private static var lastPushTransitionDirection: SKTransitionDirection?

    // Focus scanner drives the ButtonNode focus-ring for switch / keyboard / controller navigation.
    // Nil until the first didMove(to:) — subclasses share the same instance.
    private(set) var focusScanner: FocusScanner?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupFocusScanner()
        // Notify Switch Control that a new screen is available
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        focusScanner?.stop()
    }

    // MARK: - Scanner setup

    private func setupFocusScanner() {
        focusScanner?.stop()
        let scanner = FocusScanner()
        scanner.items = findAllButtonsInScene()
        focusScanner = scanner
        // Auto-start the timed scanning loop only when the user has opted into switch access.
        // First-time switch users can still trigger scanning via the first key/controller press.
        if GameSettings.shared.scanningEnabled {
            scanner.start()
        }
    }

    // MARK: - Conformance to ButtonNodeResponderType

    func buttonTriggered(button: ButtonNode) {
        guard let identifier = button.buttonIdentifier else { return }
        selection.selectionChanged()

        var sceneToPresent: SKScene?
        var transition: SKTransition?
        let scaleMode: SKSceneScaleMode = RoutingUtilityScene.sceneScaleMode

        // Honour system motion preferences: push/slide transitions are suppressed when
        // Reduce Motion is enabled or the user has requested cross-fade transitions.
        var reduceMotion = UIAccessibility.isReduceMotionEnabled
        if #available(iOS 14.0, *) {
            reduceMotion = reduceMotion || UIAccessibility.prefersCrossFadeTransitions
        }

        switch identifier {
        case .play:
            sceneToPresent = GameScene(fileNamed: Scenes.game.getName())
            transition = SKTransition.fade(withDuration: 1.0)

        case .settings:
            guard !GameSettings.shared.isSettingsLocked else { return }
            sceneToPresent = SettingsScene(fileNamed: Scenes.setting.getName())
            if reduceMotion {
                transition = SKTransition.fade(withDuration: 0.4)
            } else {
                RoutingUtilityScene.lastPushTransitionDirection = .down
                transition = SKTransition.push(with: .down, duration: 1.0)
            }

        case .menu:
            sceneToPresent = TitleScene(fileNamed: Scenes.title.getName())
            if reduceMotion {
                RoutingUtilityScene.lastPushTransitionDirection = nil
                transition = SKTransition.fade(withDuration: 0.4)
            } else {
                var pushDir: SKTransitionDirection?
                if let last = RoutingUtilityScene.lastPushTransitionDirection {
                    switch last {
                    case .up:    pushDir = .down
                    case .down:  pushDir = .up
                    case .left:  pushDir = .right
                    case .right: pushDir = .left
                    @unknown default:
                        fatalError("Unhandled SKTransitionDirection in RoutingUtilityScene")
                    }
                    RoutingUtilityScene.lastPushTransitionDirection = pushDir
                }
                transition = pushDir.map { SKTransition.push(with: $0, duration: 1.0) }
                          ?? SKTransition.fade(withDuration: 1.0)
            }

        default:
            debugPrint(#function, "unhandled identifier:", identifier)
        }

        guard let scene = sceneToPresent, let tx = transition else { return }
        scene.scaleMode = scaleMode
        tx.pausesIncomingScene = false
        tx.pausesOutgoingScene = false
        view?.presentScene(scene, transition: tx)
    }
}

// MARK: - SwitchInputReceivable

extension RoutingUtilityScene: SwitchInputReceivable {

    func switchPrimaryBegan() {
        focusScanner?.primaryActivate()
    }

    func switchPrimaryEnded() { }

    func switchSecondaryBegan() {
        focusScanner?.secondaryAdvance()
    }

    func switchSecondaryEnded() { }
}
