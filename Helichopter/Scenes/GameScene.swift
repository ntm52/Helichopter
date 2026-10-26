import SpriteKit
import GameplayKit

/// Which part of a round is on screen; the HUD shows only while `playing`.
enum GamePhase: Equatable {
    case playing, paused, roundOver
}

/// The scene reports every change the HUD shows as it happens, so the HUD never
/// polls the scene. Calls arrive on the main thread.
protocol GameSceneHUDDelegate: AnyObject {
    func scoreDidChange(_ score: Int)
    func bestScoreDidChange(_ best: Int)
    func stateDidChange(_ phase: GamePhase)
    /// The hint's wording, or nil when it should fade away after the first input.
    func flightHintDidChange(_ text: String?)
    func newHighScoreDidChange(_ isShowing: Bool)
}

class GameScene: SKScene {

    // MARK: - Properties

    lazy var stateMachine: GKStateMachine = GKStateMachine(states: [
        PlayingState(adapter: sceneAdapter!),
        GameOverState(scene: sceneAdapter!),
        PausedState(scene: self, adapter: sceneAdapter!)
    ])

    var sceneAdapter: GameSceneAdapter?
    let selection = UISelectionFeedbackGenerator()
    weak var hudDelegate: GameSceneHUDDelegate?

    // Drives focus-ring scanning in pause / game-over overlays.
    private(set) var overlayScanner: FocusScanner?
    private(set) var switchPauseTimer: Timer?
    private var primarySwitchHeld = false
    private var secondarySwitchHeld = false

    deinit { switchPauseTimer?.invalidate() }

    /// Cancel the pending gesture whenever gameplay ends, including direct state changes.
    func cancelSwitchPauseHold() {
        switchPauseTimer?.invalidate()
        switchPauseTimer = nil
    }

    // MARK: - Lifecycle

    override func sceneDidLoad() {
        super.sceneDidLoad()
        sceneAdapter = GameSceneAdapter(with: self)
        sceneAdapter?.stateMachine = stateMachine
        sceneAdapter?.onGameOverEntered = { [weak self] in
            self?.setupOverlayScanner()
        }
        sceneAdapter?.stateMachine?.enter(PlayingState.self)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        let theme = GameSettings.shared.selectedTheme
        backgroundColor = theme.sceneBackgroundColor
        view.backgroundColor = theme.sceneBackgroundColor
        // Themes with a plain backdrop hide the starfield so the scene colour shows.
        // Tinting would not work: SpriteKit multiplies the tint by the dark texture.
        sceneAdapter?.infiniteBackgroundNode?.isHidden = theme.backgroundSpriteTintColor != nil
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        overlayScanner?.stop()
        cancelSwitchPauseHold()
        primarySwitchHeld = false
        secondarySwitchHeld = false
    }

    // MARK: - Flight hint

    /// The hint the HUD shows, or nil once the player has started flying this run.
    private(set) var flightHintText: String?

    func showFlightHint(_ text: String) {
        flightHintText = text
        hudDelegate?.flightHintDidChange(text)
    }

    func hideFlightHint() {
        guard flightHintText != nil else { return }
        flightHintText = nil
        hudDelegate?.flightHintDidChange(nil)
    }

    /// What the HUD shows for the current state, read once when the HUD is built.
    var phase: GamePhase {
        switch stateMachine.currentState {
        case is PausedState: return .paused
        case is GameOverState: return .roundOver
        default: return .playing
        }
    }

    // MARK: - Pause and Round Over menus

    /// Menu choices in focus order. The scene owns them so switch scanning works
    /// without a view; `GameMenuView` draws whichever menu is current.
    private(set) lazy var pauseMenu = [MenuAction.resume, .home].map { GameMenuItem($0, phase: .paused, scene: self) }
    private(set) lazy var roundOverMenu = [MenuAction.home, .retry].map { GameMenuItem($0, phase: .roundOver, scene: self) }

    /// The menu for the current state; empty during play.
    var menuItems: [GameMenuItem] {
        switch phase {
        case .paused: return pauseMenu
        case .roundOver: return roundOverMenu
        case .playing: return []
        }
    }

    /// Every menu route (tap, scanner, VoiceOver) ends here. A choice from a menu that
    /// has already closed, or one made during a screen change, is ignored.
    func perform(_ action: MenuAction, from menuPhase: GamePhase) {
        guard phase == menuPhase, RootViewController.acceptsInput(in: view) else { return }
        selection.selectionChanged()

        switch action {
        case .resume, .retry:
            stateMachine.enter(PlayingState.self)
            teardownOverlayScanner()

        case .home:
            // A paused scene must not depend on render-loop progress to leave its menu.
            // The Home screen makes the only screen-change announcement.
            overlayScanner?.stop()
            overlayScanner = nil
            cancelSwitchPauseHold()
            RootViewController.present(.home, in: view)
        }
    }

    /// Shown until the first flight input; worded for how this player actually flies.
    static func flightHintText(for scheme: ControlScheme, voiceOver: Bool,
                               directTouch: Bool = GameSettings.shared.voiceOverDirectTouch) -> String {
        if voiceOver {
            guard directTouch else { return "Double-tap the flight control to start" }
            return scheme.splitsTouchIntoUpAndDown
                ? "Touch the top or bottom half of the screen to fly up or down"
                : "Touch the lower half of the screen to fly"
        }
        switch scheme {
        case .tapFlap: return "Tap or press your switch to fly"
        case .holdHover: return "Hold the screen or your switch to rise"
        case .autoHover: return "Tap the top or bottom half, or press a switch, to nudge up or down"
        case .twoSwitchUD: return "Hold the top or bottom half, or a switch, to move up or down"
        }
    }

    // MARK: - Accessibility

    /// Interruptions leave the run paused until the player explicitly resumes.
    func pauseForInterruption() {
        cancelSwitchPauseHold()
        primarySwitchHeld = false
        secondarySwitchHeld = false
        helicopter?.prepareForNewRun()
        guard stateMachine.currentState is PlayingState else { return }
        if stateMachine.enter(PausedState.self) {
            setupOverlayScanner()
        }
    }

    /// VoiceOver activations have no release event, so sustained flight uses toggles.
    @discardableResult
    func accessibilityFly(down: Bool = false) -> Bool {
        guard view != nil, stateMachine.currentState is PlayingState, let helicopter = helicopter else { return false }
        switch GameSettings.shared.controlScheme {
        case .tapFlap:
            guard !down else { return false }
            helicopter.switchPrimaryBegan()
            helicopter.switchPrimaryEnded()
        case .holdHover:
            if helicopter.isHoveringHeld || down { helicopter.switchPrimaryEnded() }
            else { helicopter.switchPrimaryBegan() }
        case .autoHover:
            if down { helicopter.switchSecondaryBegan(); helicopter.switchSecondaryEnded() }
            else { helicopter.switchPrimaryBegan(); helicopter.switchPrimaryEnded() }
        case .twoSwitchUD:
            let wasHeld = down ? helicopter.isTwoSwitchDownHeld : helicopter.isTwoSwitchUpHeld
            helicopter.switchPrimaryEnded()
            helicopter.switchSecondaryEnded()
            if !wasHeld {
                if down { helicopter.switchSecondaryBegan() }
                else { helicopter.switchPrimaryBegan() }
            }
        }
        return true
    }

    /// The VoiceOver hint for a flight area; `down` is the lower area of a split screen.
    func accessibilityFlightHint(down: Bool = false) -> String {
        let scheme = GameSettings.shared.controlScheme
        if GameSettings.shared.voiceOverDirectTouch {
            // Touches pass straight through, so swipe gestures cannot start on the flight area.
            let pause = "Pause is at the top of the screen."
            switch scheme {
            case .tapFlap: return "Direct touch. Tap the lower half of the screen to flap upward. \(pause)"
            case .holdHover: return "Direct touch. Touch and hold the lower half of the screen to rise; lift your finger to fall. \(pause)"
            case .autoHover: return "Direct touch. Tap here to nudge \(down ? "down" : "up"). \(pause)"
            case .twoSwitchUD: return "Direct touch. Touch and hold here to move \(down ? "down" : "up"); lift your finger to stop. \(pause)"
            }
        }
        switch scheme {
        case .tapFlap: return "Double-tap to flap upward. Use the Pause action to pause."
        case .holdHover: return "Double-tap to toggle rising and falling. Use the Pause action to pause."
        case .autoHover: return "Double-tap to nudge \(down ? "down" : "up"). Use the Pause action to pause."
        case .twoSwitchUD: return "Double-tap to toggle \(down ? "descending" : "rising") and stopping. Use the Pause action to pause."
        }
    }

    var accessibilityFlightStatus: String {
        guard let player = helicopter else { return "Ready" }
        if player.onFirstInput != nil { return "Ready to fly" }
        let motion: String
        if player.isHoveringHeld || player.isTwoSwitchUpHeld { motion = "Rising" }
        else if player.isTwoSwitchDownHeld { motion = "Descending" }
        else { motion = "Altitude \(Int(max(0, min(1, player.position.y / size.height)) * 100)) percent" }
        let radius = player.size.width / 2 * GameSettings.shared.hitboxFraction
        let gaps = children.filter { $0.name == "pipe" }.flatMap { $0.children }
            .compactMap { $0 as? SKSpriteNode }
            .filter { $0.physicsBody?.categoryBitMask == PhysicsCategories.gap.rawValue }
        let next = gaps.filter { $0.convert(CGPoint.zero, to: self).x + PipeFactory.pipeWidth / 2 >= player.position.x - radius }
            .min { $0.convert(CGPoint.zero, to: self).x < $1.convert(CGPoint.zero, to: self).x }
        guard let gap = next else { return "\(motion). Clear ahead" }
        let center = gap.convert(CGPoint.zero, to: self)
        let direction: String
        if player.position.y < center.y - gap.size.height / 2 + radius { direction = "Move up" }
        else if player.position.y > center.y + gap.size.height / 2 - radius { direction = "Move down" }
        else { direction = "Aligned with gap" }
        let near = center.x - player.position.x < size.width * 0.35
        return "\(motion). Pipe \(near ? "near" : "ahead"). \(direction)"
    }

    private var lastVoiceGuidanceTime: TimeInterval = 0
    private var lastVoiceGuidance: String?

    private func updateVoiceGuidance(_ time: TimeInterval) {
        guard UIAccessibility.isVoiceOverRunning, stateMachine.currentState is PlayingState,
              helicopter?.onFirstInput == nil else {
            lastVoiceGuidance = nil
            lastVoiceGuidanceTime = 0
            return
        }
        // Short, rate-limited speech avoids a queue of obsolete obstacle positions.
        guard time - lastVoiceGuidanceTime >= 2 else { return }
        // Keep automatic speech brief enough to finish between updates. Altitude
        // remains available by focusing the flight control's live value.
        let guidance = accessibilityFlightStatus.components(separatedBy: ". ").dropFirst().joined(separator: ". ")
        guard guidance != lastVoiceGuidance else { return }
        lastVoiceGuidance = guidance
        lastVoiceGuidanceTime = time
        UIAccessibility.post(notification: .announcement, argument: guidance)
    }

    // MARK: - Overlay scanner management

    /// Called when the game enters Pause or Round Over.
    func setupOverlayScanner(forceStart: Bool = false) {
        overlayScanner?.stop()
        let scanner = FocusScanner()
        scanner.items = menuItems
        overlayScanner = scanner
        if forceStart || GameSettings.shared.scanningEnabled {
            scanner.start()
        }
        ScreenChangeAnnouncer.post()
    }

    private func teardownOverlayScanner() {
        overlayScanner?.stop()
        overlayScanner = nil
        ScreenChangeAnnouncer.post()
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
        guard view != nil, !isPaused else { return }

        updateVoiceGuidance(currentTime)
        sceneAdapter?.updatables.filter { $0.shouldUpdate }.forEach { $0.update(currentTime) }
    }
}

// MARK: - HUD Pause button

extension GameScene {

    /// The HUD's Pause button. Ignored outside play and during a screen change.
    func pauseFromHUD() {
        guard stateMachine.currentState is PlayingState, RootViewController.acceptsInput(in: view) else { return }
        selection.selectionChanged()
        stateMachine.enter(PausedState.self)
        setupOverlayScanner()
    }
}

// MARK: - SwitchInputReceivable

extension GameScene: ScreenTransitionScanning {
    var scannersDuringTransition: [FocusScanner] { overlayScanner.map { [$0] } ?? [] }
}

extension GameScene: SwitchInputReceivable {

    /// Up/Down Switches pauses when both switches are held this long; a brief overlap does not.
    static let bothSwitchesPauseDelay: TimeInterval = 0.5

    func switchPrimaryBegan() {
        // Ignore key repeat and the still-held pause gesture until its release.
        guard !primarySwitchHeld else { return }
        primarySwitchHeld = true
        guard stateMachine.currentState is PlayingState else {
            overlayScanner?.primaryActivate()
            return
        }
        helicopter?.switchPrimaryBegan()
        if GameSettings.shared.controlScheme.holdingPrimaryPauses {
            if GameSettings.shared.holdToPauseEnabled {
                startSwitchPause(after: GameSettings.shared.switchPauseHoldDuration)
            }
        } else if secondarySwitchHeld {
            startSwitchPause(after: Self.bothSwitchesPauseDelay)
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
        guard !secondarySwitchHeld else { return }
        secondarySwitchHeld = true
        guard stateMachine.currentState is PlayingState else {
            overlayScanner?.secondaryAdvance()
            return
        }
        let scheme = GameSettings.shared.controlScheme
        // Tap to Flap and Hold to Hover have no flight job for it, so it pauses at once.
        if scheme.secondarySwitchPauses {
            pauseFromSwitch()
            return
        }
        helicopter?.switchSecondaryBegan()
        if !scheme.holdingPrimaryPauses && primarySwitchHeld {
            startSwitchPause(after: Self.bothSwitchesPauseDelay)
        }
    }

    func switchSecondaryEnded() {
        secondarySwitchHeld = false
        // Releasing it ends the both-switches gesture, but not a primary hold in Auto Hover.
        if !GameSettings.shared.controlScheme.holdingPrimaryPauses { cancelSwitchPauseHold() }
        if stateMachine.currentState is PlayingState {
            helicopter?.switchSecondaryEnded()
        }
    }

    /// Pauses once the gesture has lasted `delay`; releasing the switch cancels it.
    private func startSwitchPause(after delay: TimeInterval) {
        cancelSwitchPauseHold()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, self.primarySwitchHeld,
                  self.stateMachine.currentState is PlayingState else { return }
            self.pauseFromSwitch()
        }
        switchPauseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func pauseFromSwitch() {
        cancelSwitchPauseHold()
        guard stateMachine.currentState is PlayingState else { return }
        if stateMachine.enter(PausedState.self) {
            // Switch entry always enables navigation, even if menu auto-start is off.
            setupOverlayScanner(forceStart: true)
        }
    }

    private var helicopter: HelicopterNode? {
        sceneAdapter?.touchables.compactMap { $0 as? HelicopterNode }.first
    }
}
