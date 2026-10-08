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

// MARK: - Screen transitions

/// How one screen replaces another. SpriteKit and UIKit always change together.
enum ScreenTransition: Equatable {
    /// The old screen's snapshot fades out over the new one. Nothing moves.
    case crossFade(duration: TimeInterval)
    /// Swap with no animation (first launch, or no window to animate in).
    case instant

    static let standardDuration: TimeInterval = 0.3
    static let reducedMotionDuration: TimeInterval = 0.2

    /// A cross-fade; shorter when the player asks for less motion.
    static func preferred(reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled
                                            || UIAccessibility.prefersCrossFadeTransitions) -> ScreenTransition {
        .crossFade(duration: reduceMotion ? reducedMotionDuration : standardDuration)
    }

    var duration: TimeInterval {
        if case .crossFade(let duration) = self { return duration }
        return 0
    }
}

/// Scenes report the scanners that must freeze while their screen fades in.
protocol ScreenTransitionScanning: AnyObject {
    var scannersDuringTransition: [FocusScanner] { get }
}

/// Every `screenChanged` post goes through here, so a screen change announces itself
/// exactly once: posts made while a transition runs are held and the last one with a
/// focus target (or the last one at all) is sent when the transition finishes.
enum ScreenChangeAnnouncer {
    static var poster: (Any?) -> Void = { UIAccessibility.post(notification: .screenChanged, argument: $0) }
    private static var holding = false
    private static var pending: Any??

    static func post(_ argument: Any? = nil) {
        guard holding else { return poster(argument) }
        if argument != nil || pending == nil { pending = .some(argument) }
    }

    static func hold() {
        holding = true
        pending = nil
    }

    static func release() {
        guard holding else { return }
        holding = false
        let argument = pending
        pending = nil
        poster(argument ?? nil)
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
        guard let button = buttonNode, GameViewController.acceptsInput(in: skView) else { return false }
        button.scannerActivate()
        return true
    }
}

// MARK: - GameViewController

class GameViewController: UIViewController {

    private var inputSuspended = false
    let sceneTextOverlay = SceneTextOverlay()
    private var textRefreshTimer: Timer?
    /// True while one screen fades into the next; all input and scanning is held.
    private(set) var isChangingScreen = false
    private var transitionSnapshot: UIView?

    deinit { textRefreshTimer?.invalidate() }

    func refreshSceneText() {
        guard let skView = viewIfLoaded as? SKView else { return }
        sceneTextOverlay.refresh(in: skView)
    }


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

        (view as? SKView)?.ignoresSiblingOrder = true
        sceneTextOverlay.frame = view.bounds
        sceneTextOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneTextOverlay)
        if let scene = TitleScene(fileNamed: Scenes.title.getName()) {
            present(scene, transition: .instant)
        }
        // UIKit continues refreshing when SpriteKit is paused. Capture weakly so
        // the run loop cannot retain the controller or a departed scene.
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.refreshSceneText() }
        RunLoop.main.add(timer, forMode: .common)
        textRefreshTimer = timer
        setupGameControllerObservers()
        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusChanged),
                                               name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
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

    @objc private func voiceOverStatusChanged() {
        // Changing input methods must not leave a toggled climb/descent running.
        ((viewIfLoaded as? SKView)?.scene as? GameScene)?.pauseForInterruption()
        refreshSceneText()
    }

    // MARK: - Screen changes

    /// The controller that owns `view`, when the view is its root SKView.
    static func controller(for view: SKView?) -> GameViewController? {
        guard let controller = view?.next as? GameViewController, controller.viewIfLoaded === view else { return nil }
        return controller
    }

    /// False while a screen change is animating in `view`.
    static func acceptsInput(in view: SKView?) -> Bool {
        controller(for: view)?.isChangingScreen != true
    }

    /// The only way to change screens. Views without a controller (tests) swap directly.
    static func present(_ scene: SKScene, in view: SKView?, transition: ScreenTransition = .preferred()) {
        guard let view = view else { return }
        if let controller = controller(for: view) {
            controller.present(scene, transition: transition)
        } else {
            scene.scaleMode = scaleMode(for: scene, in: view.bounds.size)
            view.presentScene(scene)
        }
    }

    /// Replaces the whole screen as one unit: a snapshot of SpriteKit and UIKit together
    /// covers the swap, then fades away. Input, scanning, and VoiceOver announcements
    /// are held until the new screen is fully visible.
    func present(_ scene: SKScene, transition: ScreenTransition = .preferred()) {
        guard let skView = viewIfLoaded as? SKView, !isChangingScreen else { return }
        scene.scaleMode = Self.scaleMode(for: scene, in: skView.bounds.size)
        let animated = transition.duration > 0 && skView.scene != nil && skView.window != nil
        let snapshot = animated ? makeTransitionSnapshot(of: skView) : nil

        isChangingScreen = true
        skView.isUserInteractionEnabled = false
        ScreenChangeAnnouncer.hold()
        if let snapshot = snapshot {
            snapshot.frame = skView.bounds
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            skView.addSubview(snapshot)
            transitionSnapshot = snapshot
        }

        skView.presentScene(scene)
        refreshSceneText()
        let scanners = (scene as? ScreenTransitionScanning)?.scannersDuringTransition ?? []
        scanners.forEach { $0.suspend() }
        // Scenes add UIKit panels in didMove; the outgoing image must stay on top of them.
        if let snapshot = snapshot { skView.bringSubviewToFront(snapshot) }

        let finish = { [weak self, weak skView] in
            self?.transitionSnapshot?.removeFromSuperview()
            self?.transitionSnapshot = nil
            self?.isChangingScreen = false
            skView?.isUserInteractionEnabled = true
            scanners.forEach { $0.resume() }
            ScreenChangeAnnouncer.release()
        }
        guard let fading = snapshot else { return finish() }
        UIView.animate(withDuration: transition.duration, delay: 0, options: [.curveEaseInOut]) {
            fading.alpha = 0
        } completion: { _ in finish() }
    }

    /// An image of everything on screen, SpriteKit layer included. The system snapshot
    /// was checked on the simulator (2026-10-08) and includes the Metal layer.
    private func makeTransitionSnapshot(of skView: SKView) -> UIView? {
        skView.snapshotView(afterScreenUpdates: false) ?? Self.compositeSnapshot(of: skView).map(UIImageView.init)
    }

    /// Fallback from Plan 01: draw the scene with SpriteKit itself, then UIKit on top.
    /// Use this alone if device recordings show `snapshotView` coming out blank.
    static func compositeSnapshot(of skView: SKView) -> UIImage? {
        guard let scene = skView.scene, skView.bounds.width > 0, skView.bounds.height > 0 else { return nil }
        let sceneRect = CGRect(x: -scene.anchorPoint.x * scene.size.width, y: -scene.anchorPoint.y * scene.size.height,
                               width: scene.size.width, height: scene.size.height)
        let topLeft = skView.convert(CGPoint(x: sceneRect.minX, y: sceneRect.maxY), from: scene)
        let bottomRight = skView.convert(CGPoint(x: sceneRect.maxX, y: sceneRect.minY), from: scene)
        let drawRect = CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
        let texture = skView.texture(from: scene, crop: sceneRect)
        return UIGraphicsImageRenderer(bounds: skView.bounds).image { context in
            (skView.backgroundColor ?? scene.backgroundColor).setFill()
            context.fill(skView.bounds)
            scene.backgroundColor.setFill()
            context.fill(drawRect)
            if let texture = texture { UIImage(cgImage: texture.cgImage()).draw(in: drawRect) }
            for subview in skView.subviews where !subview.isHidden {
                subview.drawHierarchy(in: subview.frame, afterScreenUpdates: false)
            }
        }
    }

    // MARK: - Orientation

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Also called when an iPadOS window is resized, not only on rotation.
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let skView = self?.view as? SKView, let scene = skView.scene else { return }
            scene.scaleMode = GameViewController.scaleMode(for: scene, in: size)
            skView.backgroundColor = scene.backgroundColor
        })
    }

    /// Most scene units aspectFill may trim from each side. The helicopter's left
    /// edge sits 50 units in, so it always stays fully visible.
    static let maximumSideCrop: CGFloat = 48

    /// Chooses how the portrait scene fits a window of any shape: iPhone, either iPad
    /// orientation, and iPadOS resizable windows. Filling may only trim a sliver from
    /// the sides; otherwise the whole scene is shown with theme-coloured bars, so the
    /// helicopter, ceiling, and floor are never cut off. Critical for switch users,
    /// whose iPads are often mounted in landscape.
    static func scaleMode(for scene: SKScene, in size: CGSize) -> SKSceneScaleMode {
        let sceneSize = scene.size
        guard size.width > 0, size.height > 0, sceneSize.width > 0, sceneSize.height > 0 else { return .aspectFill }
        let viewAspect = size.width / size.height
        // Wider than the scene: filling would crop the ceiling and floor.
        guard viewAspect <= sceneSize.width / sceneSize.height else { return .aspectFit }
        let cropPerSide = (sceneSize.width - sceneSize.height * viewAspect) / 2
        return cropPerSide <= maximumSideCrop ? .aspectFill : .aspectFit
    }

    // MARK: - Accessibility (VoiceOver + iOS Switch Control)

    /// Returns UIKit accessibility elements for every button in the scene, plus a score
    /// element when gameplay is active. VoiceOver and iOS Switch Control item scanning
    /// both use this list.
    override var accessibilityElements: [Any]? {
        get {
            guard let skView = view as? SKView, let scene = skView.scene else { return nil }
            if scene is SettingsScene || !sceneTextOverlay.isHidden { return nil }
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
        guard !inputSuspended, !isChangingScreen else { return true }
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
        guard !inputSuspended, !isChangingScreen else { return }
        guard let skView = view as? SKView,
              let scene = skView.scene as? SwitchInputReceivable else { return }
        if primary {
            pressed ? scene.switchPrimaryBegan() : scene.switchPrimaryEnded()
        } else {
            pressed ? scene.switchSecondaryBegan() : scene.switchSecondaryEnded()
        }
    }
}
