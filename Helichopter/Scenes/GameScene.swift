import SpriteKit
import GameplayKit

class GameScene: SKScene {

    // MARK: - Constants

    static var viewportSize: CGSize = .zero

    // MARK: - Properties

    lazy var stateMachine: GKStateMachine = GKStateMachine(states: [
        PlayingState(adapter: sceneAdapter!),
        GameOverState(scene: sceneAdapter!),
        PausedState(scene: self, adapter: sceneAdapter!)
    ])

    var entities = [GKEntity]()
    var graphs   = [String: GKGraph]()

    private var lastUpdateTime: TimeInterval = 0
    let maximumUpdateDeltaTime: TimeInterval = 1.0 / 60.0

    var sceneAdapter: GameSceneAdapter?
    let selection = UISelectionFeedbackGenerator()

    // Drives focus-ring scanning in pause / game-over overlays.
    private(set) var overlayScanner: FocusScanner?
    private var switchPauseTimer: Timer?
    private var primarySwitchHeld = false

    deinit { switchPauseTimer?.invalidate() }

    /// Cancel the pending gesture whenever gameplay ends, including direct state changes.
    func cancelSwitchPauseHold() {
        switchPauseTimer?.invalidate()
        switchPauseTimer = nil
    }

    // MARK: - Lifecycle

    override func sceneDidLoad() {
        super.sceneDidLoad()
        lastUpdateTime = 0
        sceneAdapter = GameSceneAdapter(with: self)
        sceneAdapter?.stateMachine = stateMachine
        sceneAdapter?.onGameOverEntered = { [weak self] in
            self?.setupOverlayScanner()
        }
        sceneAdapter?.stateMachine?.enter(PlayingState.self)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        GameScene.viewportSize = view.bounds.size
        let theme = GameSettings.shared.selectedTheme
        backgroundColor = theme.sceneBackgroundColor
        view.backgroundColor = theme.sceneBackgroundColor
        applyUITheme(theme)
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        overlayScanner?.stop()
        cancelSwitchPauseHold()
        primarySwitchHeld = false
    }

    // MARK: - Accessibility

    /// Interruptions leave the run paused until the player explicitly resumes.
    func pauseForInterruption() {
        cancelSwitchPauseHold()
        primarySwitchHeld = false
        helicopter?.prepareForNewRun()
        lastUpdateTime = 0
        guard stateMachine.currentState is PlayingState else { return }
        if stateMachine.enter(PausedState.self) {
            setupOverlayScanner()
        }
    }

    /// Score string exposed to the UIKit accessibility tree via GameViewController.
    /// Returns nil when not in PlayingState so the element is absent from VoiceOver's list.
    var currentScoreText: String? {
        guard stateMachine.currentState is PlayingState, GameSettings.shared.showScore else { return nil }
        return "Score: \(sceneAdapter?.score ?? 0)"
    }

    // MARK: - Overlay scanner management

    /// Called when PausedState or GameOverState presents an overlay.
    func setupOverlayScanner(forceStart: Bool = false) {
        overlayScanner?.stop()
        let scanner = FocusScanner()
        scanner.items = findAllButtonsInScene()
        overlayScanner = scanner
        if forceStart || GameSettings.shared.scanningEnabled {
            scanner.start()
        }
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    private func teardownOverlayScanner() {
        overlayScanner?.stop()
        overlayScanner = nil
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        sceneAdapter?.touchables.forEach { $0.touchesBegan(touches, with: event) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        sceneAdapter?.touchables.forEach { $0.touchesMoved(touches, with: event) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        sceneAdapter?.touchables.forEach { $0.touchesEnded(touches, with: event) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        sceneAdapter?.touchables.forEach { $0.touchesCancelled(touches, with: event) }
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard view != nil else { return }

        let deltaTime = lastUpdateTime == 0 ? 0 : min(max(currentTime - lastUpdateTime, 0), maximumUpdateDeltaTime)
        lastUpdateTime = currentTime

        if isPaused { return }

        stateMachine.update(deltaTime: deltaTime)
        sceneAdapter?.updatables.filter { $0.shouldUpdate }.forEach { $0.update(currentTime) }
    }
}

// MARK: - ButtonNodeResponderType

extension GameScene: ButtonNodeResponderType {

    func buttonTriggered(button: ButtonNode) {
        guard let identifier = button.buttonIdentifier else { return }
        selection.selectionChanged()

        switch identifier {
        case .pause:
            sceneAdapter?.stateMachine?.enter(PausedState.self)
            setupOverlayScanner()

        case .resume:
            sceneAdapter?.stateMachine?.enter(PlayingState.self)
            teardownOverlayScanner()

        case .home:
            guard let titleScene = TitleScene(fileNamed: Scenes.title.getName()) else { return }
            titleScene.scaleMode = RoutingUtilityScene.sceneScaleMode
            // A paused scene must not depend on render-loop progress to leave its menu.
            teardownOverlayScanner()
            cancelSwitchPauseHold()
            view?.presentScene(titleScene)

        case .retry:
            sceneAdapter?.stateMachine?.enter(PlayingState.self)
            teardownOverlayScanner()

        default:
            debugPrint(#function, "unhandled identifier:", identifier)
        }
    }
}

// MARK: - SwitchInputReceivable

extension GameScene: SwitchInputReceivable {

    func switchPrimaryBegan() {
        // Ignore key repeat and the still-held pause gesture until its release.
        guard !primarySwitchHeld else { return }
        primarySwitchHeld = true
        if stateMachine.currentState is PlayingState {
            helicopter?.switchPrimaryBegan()
            let timer = Timer(timeInterval: GameSettings.shared.switchPauseHoldDuration, repeats: false) { [weak self] _ in
                guard let self = self, self.primarySwitchHeld,
                      self.stateMachine.currentState is PlayingState else { return }
                self.cancelSwitchPauseHold()
                if self.stateMachine.enter(PausedState.self) {
                    // Switch entry always enables navigation, even if menu auto-start is off.
                    self.setupOverlayScanner(forceStart: true)
                }
            }
            switchPauseTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else {
            overlayScanner?.primaryActivate()
        }
    }

    func switchPrimaryEnded() {
        primarySwitchHeld = false
        cancelSwitchPauseHold()
        if stateMachine.currentState is PlayingState {
            helicopter?.switchPrimaryEnded()
        }
    }

    func switchSecondaryBegan() {
        if stateMachine.currentState is PlayingState {
            helicopter?.switchSecondaryBegan()
        } else {
            overlayScanner?.secondaryAdvance()
        }
    }

    func switchSecondaryEnded() {
        if stateMachine.currentState is PlayingState {
            helicopter?.switchSecondaryEnded()
        }
    }

    private var helicopter: HelicopterNode? {
        sceneAdapter?.touchables.compactMap { $0 as? HelicopterNode }.first
    }
}
