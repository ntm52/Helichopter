import UIKit
import SpriteKit
import GameplayKit
import GameController

// MARK: - Scene helpers

enum Scenes: String {
    case title   = "TitleScene"
    case game    = "GameScene"
    case setting = "SettingsScene"
    case pause   = "PauseScene"
    case failed  = "FailedScene"
}

extension Scenes {
    func getName() -> String {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return isPad ? rawValue + " iPad" : rawValue
    }
}

enum NodeScale: Float {
    case gameBackgroundScale
}

extension NodeScale {
    func getValue() -> Float {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        switch self {
        case .gameBackgroundScale: return isPad ? 1.5 : 1.35
        }
    }
}

extension CGPoint {
    init(x: Float, y: Float) {
        self.init()
        self.x = CGFloat(x)
        self.y = CGFloat(y)
    }
}

// MARK: - ButtonAccessibilityElement

/// UIKit accessibility proxy that wraps a ButtonNode for iOS Switch Control item scanning.
private final class ButtonAccessibilityElement: UIAccessibilityElement {
    weak var buttonNode: ButtonNode?
    weak var skView: SKView?

    override var accessibilityFrame: CGRect {
        get {
            guard let button = buttonNode, let view = skView else { return .zero }
            return button.accessibilityScreenFrame(in: view)
        }
        set { }
    }

    override func accessibilityActivate() -> Bool {
        guard let button = buttonNode else { return false }
        button.scannerActivate()
        return true
    }
}

// MARK: - GameViewController

class GameViewController: UIViewController {

    private var inputSuspended = false

    func suspendInput() {
        inputSuspended = true
        ((viewIfLoaded as? SKView)?.scene as? GameScene)?.pauseForInterruption()
    }

    func resumeInput() {
        inputSuspended = false
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let sceneName = Scenes.title.getName()
        if let scene = SKScene(fileNamed: sceneName) as? TitleScene,
           let skView = self.view as? SKView {
            scene.scaleMode = GameViewController.scaleMode(forSize: skView.bounds.size)
            skView.presentScene(scene)
            skView.ignoresSiblingOrder = true
        }

        setupGameControllerObservers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Required so pressesBegan/Ended events reach this view controller
        becomeFirstResponder()
    }

    override var canBecomeFirstResponder: Bool { true }

    override var shouldAutorotate: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .allButUpsideDown : .portrait
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Orientation

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let skView = self?.view as? SKView, let scene = skView.scene else { return }
            scene.scaleMode = GameViewController.scaleMode(forSize: size)
            skView.backgroundColor = scene.backgroundColor
        })
    }

    /// Returns the appropriate scene scale mode for the given view size.
    /// iPad landscape uses aspectFit (pillarboxed portrait game) so the full scene
    /// is always visible regardless of mount orientation — critical for switch users.
    static func scaleMode(forSize size: CGSize) -> SKSceneScaleMode {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return .aspectFill }
        return size.width > size.height ? .aspectFit : .aspectFill
    }

    // MARK: - Accessibility (VoiceOver + iOS Switch Control)

    /// Returns UIKit accessibility elements for every button in the scene, plus a score
    /// element when gameplay is active. VoiceOver and iOS Switch Control item scanning
    /// both use this list.
    override var accessibilityElements: [Any]? {
        get {
            guard let skView = view as? SKView, let scene = skView.scene else { return nil }
            if scene is SettingsScene { return nil }
            var elements: [Any] = []

            // Score element — present when GameScene is playing
            if let gameScene = scene as? GameScene, let scoreText = gameScene.currentScoreText {
                let scoreElem = UIAccessibilityElement(accessibilityContainer: skView)
                scoreElem.accessibilityLabel = scoreText
                scoreElem.accessibilityTraits = .staticText
                scoreElem.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(
                    CGRect(x: 0, y: 0, width: skView.bounds.width, height: 80), in: skView)
                elements.append(scoreElem)
            }

            // Button elements
            let buttons = scene.findAllButtonsInScene()
            let buttonElems: [ButtonAccessibilityElement] = buttons.map { btn in
                let elem = ButtonAccessibilityElement(accessibilityContainer: skView)
                elem.buttonNode = btn
                elem.skView = skView
                elem.accessibilityLabel = btn.accessibilityScanLabel
                elem.accessibilityHint  = btn.accessibilityScanHint
                elem.accessibilityTraits = .button
                return elem
            }
            elements.append(contentsOf: buttonElems)

            return elements.isEmpty ? nil : elements
        }
        set { }
    }

    // MARK: - Keyboard input (hardware keyboard / Bluetooth switch interfaces)
    //
    // Common emulation mappings:
    //   Space / Enter / 1 / Up Arrow  → primary switch  (flap, activate)
    //   2 / Down Arrow / Left Arrow   → secondary switch (advance scan, nudge down)

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !forwardPresses(presses, ended: false) {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !forwardPresses(presses, ended: true) {
            super.pressesEnded(presses, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        _ = forwardPresses(presses, ended: true)
        super.pressesCancelled(presses, with: event)
    }

    @discardableResult
    private func forwardPresses(_ presses: Set<UIPress>, ended: Bool) -> Bool {
        guard !inputSuspended else { return true }
        guard let skView = view as? SKView,
              let scene = skView.scene as? SwitchInputReceivable else { return false }
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }
            switch key.keyCode {
            case .keyboardSpacebar, .keyboardReturnOrEnter,
                 .keyboard1, .keyboardUpArrow:
                ended ? scene.switchPrimaryEnded() : scene.switchPrimaryBegan()
                handled = true
            case .keyboard2, .keyboardDownArrow, .keyboardLeftArrow, .keyboardRightArrow:
                ended ? scene.switchSecondaryEnded() : scene.switchSecondaryBegan()
                handled = true
            default:
                break
            }
        }
        return handled
    }

    // MARK: - Game Controller (Xbox Adaptive Controller, Logitech Adaptive Gaming Kit, etc.)

    private func setupGameControllerObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(controllerConnected(_:)),
            name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(controllerDisconnected(_:)),
            name: .GCControllerDidDisconnect, object: nil)
        // Wire any controller that was already connected before the app launched
        GCController.controllers().forEach { setupController($0) }
    }

    @objc private func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        setupController(controller)
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        ((viewIfLoaded as? SKView)?.scene as? GameScene)?.pauseForInterruption()
    }

    private func setupController(_ controller: GCController) {
        controller.handlerQueue = .main
        if let pad = controller.extendedGamepad {
            // Primary: A, Right Shoulder
            pad.buttonA.pressedChangedHandler          = { [weak self] _, _, p in self?.forwardController(primary: true,  pressed: p) }
            pad.rightShoulder.pressedChangedHandler    = { [weak self] _, _, p in self?.forwardController(primary: true,  pressed: p) }
            // Secondary: B, Left Shoulder
            pad.buttonB.pressedChangedHandler          = { [weak self] _, _, p in self?.forwardController(primary: false, pressed: p) }
            pad.leftShoulder.pressedChangedHandler     = { [weak self] _, _, p in self?.forwardController(primary: false, pressed: p) }
            // D-pad up/right = advance scan; down/left = secondary
            pad.dpad.up.pressedChangedHandler          = { [weak self] _, _, p in self?.forwardController(primary: true,  pressed: p) }
            pad.dpad.right.pressedChangedHandler       = { [weak self] _, _, p in self?.forwardController(primary: false, pressed: p) }
        }
    }

    private func forwardController(primary: Bool, pressed: Bool) {
        guard !inputSuspended else { return }
        guard let skView = view as? SKView,
              let scene = skView.scene as? SwitchInputReceivable else { return }
        if primary {
            pressed ? scene.switchPrimaryBegan() : scene.switchPrimaryEnded()
        } else {
            pressed ? scene.switchSecondaryBegan() : scene.switchSecondaryEnded()
        }
    }
}
