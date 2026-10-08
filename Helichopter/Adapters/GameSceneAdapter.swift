import SpriteKit
import GameplayKit

extension SKScene {

    func findAllButtonsInScene() -> [ButtonNode] {
        return ButtonIdentifier.allButtonIdentifiers.compactMap { buttonIdentifier in
            guard let button = childNode(withName: "//\(buttonIdentifier.rawValue)") as? ButtonNode,
                  (button.isUserInteractionEnabled || button.isPresentedInUIKit) else { return nil }
            var ancestor: SKNode? = button
            while let node = ancestor {
                if node.isHidden || (node.alpha == 0 && !(node === button && button.isPresentedInUIKit)) { return nil }
                ancestor = node.parent
            }
            return button
        }
    }
}

class GameSceneAdapter: NSObject, GameSceneProtocol {

    // MARK: - Properties

    var gravity: CGFloat { GameSettings.shared.gravity }
    let playerSize = CGSize(width: 100, height: 100)
    let backgroundResourceName = "Background"
    let floorDistance: CGFloat = 0

    let isSoundEffectsOn: Bool = {
        return UserDefaults.standard.bool(for: .isSoundEffectsOn)
    }()
    let isMusicOn: Bool = {
        return UserDefaults.standard.bool(for: .isMusicOn)
    }()

    var score: Int = 0 {
        didSet {
            guard score != oldValue else { return }
            scoreLabel?.text = "Score \(score)"
            hudDelegate?.scoreDidChange(score)
            let saved = UserDefaults.standard.integer(for: .bestScore)
            if max(score, saved) != max(oldValue, saved) { hudDelegate?.bestScoreDidChange(bestScore) }
        }
    }
    private(set) var scoreLabel: SKLabelNode?

    /// The score the last round ended on, shown by the Round Over menu.
    var roundScore = 0

    /// The best the HUD shows: the saved record, or this run's score once it is higher.
    var bestScore: Int { max(score, UserDefaults.standard.integer(for: .bestScore)) }

    // New-high-score celebration: once per run, only when beating an existing record.
    private(set) var bestAtRunStart = 0
    private var celebratedThisRun = false
    private var isCelebrating = false
    private var celebrationTimer: Timer?
    static let newHighScoreDisplayDuration: TimeInterval = 3

    /// True while the HUD should show the "New high score!" banner.
    var isShowingNewHighScore: Bool {
        GameSettings.shared.showScore && isCelebrating
    }

    private var hudDelegate: GameSceneHUDDelegate? { (scene as? GameScene)?.hudDelegate }

    /// States call this once they have finished entering, so the HUD sees the final state.
    func reportPhase(_ phase: GamePhase) {
        hudDelegate?.stateDidChange(phase)
    }

    private func setCelebrating(_ celebrating: Bool) {
        celebrationTimer?.invalidate()
        celebrationTimer = nil
        guard celebrating != isCelebrating else { return }
        isCelebrating = celebrating
        hudDelegate?.newHighScoreDidChange(isShowingNewHighScore)
    }

    private(set) var scoreSound = SKAction.playSoundFileNamed("Score.caf", waitForCompletion: false)
    private(set) var hitSound = SKAction.playSoundFileNamed("Dead.caf", waitForCompletion: false)

    typealias PlayableCharacter = (PhysicsContactable & Updatable & Touchable & Playable & SKNode)
    var playerCharacter: PlayableCharacter?

    private(set) lazy var menuAudio: SKAudioNode = {
        let audioNode = SKAudioNode(fileNamed: "MainTheme.caf")
        audioNode.autoplayLooped = true
        audioNode.name = "menu audio"
        return audioNode
    }()

    private(set) lazy var playingAudio: SKAudioNode = {
        let audioNode = SKAudioNode(fileNamed: "MainTheme.caf")
        audioNode.autoplayLooped = true
        audioNode.name = "playing audio"
        return audioNode
    }()

    // MARK: - Conformance to GameSceneProtocol

    weak var scene: SKScene?
    var stateMachine: GKStateMachine?

    var updatables = [Updatable]()
    var touchables = [Touchable]()

    private var _isHUDHidden: Bool = false
    var isHUDHidden: Bool {
        get { _isHUDHidden }
        set {
            _isHUDHidden = newValue
            if let world = self.scene?.childNode(withName: "world") {
                // Score is hidden when HUD is hidden OR when the player has disabled score display.
                world.childNode(withName: "Score Node")?.isHidden = newValue || !GameSettings.shared.showScore
            }
            // "Pause" is a direct child of the scene, not under "world".
            self.scene?.childNode(withName: "Pause")?.isHidden = newValue
        }
    }

    /// Called on the main thread when GameOverState is entered via collision.
    /// GameScene uses this to set up the menu focus scanner.
    var onGameOverEntered: (() -> Void)?

    // MARK: - Private properties

    private(set) var infiniteBackgroundNode: InfiniteSpriteScrollNode?
    private let notification = UINotificationFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Initializers

    required init?(with scene: SKScene) {
        self.scene = scene

        guard let scene = self.scene else {
            debugPrint(#function + " could not unwrap the host SKScene instance")
            return nil
        }

        if let scoreNode = scene.childNode(withName: "world")?.childNode(withName: "Score Node") {
            scoreLabel = scoreNode.childNode(withName: "Score Label") as? SKLabelNode
        }

        super.init()

        prepareWorld(for: scene)
        prepareInfiniteBackgroundScroller(for: scene)
    }

    deinit { celebrationTimer?.invalidate() }

    convenience init?(with scene: SKScene, stateMachine: GKStateMachine) {
        self.init(with: scene)
        self.stateMachine = stateMachine
    }

    // MARK: - Helpers

    func resetScores() {
        scoreLabel?.text = "Score 0"
    }

    /// Called when a fresh run (not a resume) starts.
    func beginRun() {
        bestAtRunStart = UserDefaults.standard.integer(for: .bestScore)
        celebratedThisRun = false
        setCelebrating(false)
    }

    /// Adds a point, saves a new best immediately (No-Fail runs may never reach
    /// Round Over), and celebrates the first time this run beats the old record.
    func scorePoint() {
        score += 1
        if score > UserDefaults.standard.integer(for: .bestScore) {
            UserDefaults.standard.set(score, for: .bestScore)
        }
        let isNewHighScore = !celebratedThisRun && bestAtRunStart > 0 && score > bestAtRunStart
        if isNewHighScore {
            celebratedThisRun = true
            setCelebrating(true)
            // A real-time timer, so the banner also expires while the game is paused.
            let timer = Timer(timeInterval: Self.newHighScoreDisplayDuration, repeats: false) { [weak self] _ in
                self?.setCelebrating(false)
            }
            RunLoop.main.add(timer, forMode: .common)
            celebrationTimer = timer
        }

        if isSoundEffectsOn { scene?.run(scoreSound) }
        notification.notificationOccurred(.success)

        // Announce score to VoiceOver — only when it's running to avoid interrupting audio.
        // Hidden scores stay silent, including the new-high-score message.
        if GameSettings.shared.showScore && UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement,
                                 argument: isNewHighScore ? "New high score! \(score)" : "Score \(score)")
        }
    }

    func removePipes() {
        var nodes = [SKNode]()

        scene?.children.forEach({ node in
            let nodeName = node.name
            if let doesContainNodeName = nodeName?.contains("pipe"), doesContainNodeName { nodes += [node] }
        })
        nodes.forEach { node in
            node.removeAllActions()
            node.removeAllChildren()
            node.removeFromParent()
        }
        nodes.removeAll()
    }

    private func prepareWorld(for scene: SKScene) {
        scene.physicsWorld.gravity = CGVector(dx: 0.0, dy: gravity)
        let rect = CGRect(x: 0, y: floorDistance, width: scene.size.width, height: scene.size.height - floorDistance)
        scene.physicsBody = SKPhysicsBody(edgeLoopFrom: rect)

        let boundary: PhysicsCategories = .boundary
        let player: PhysicsCategories = .player

        scene.physicsBody?.categoryBitMask = boundary.rawValue
        scene.physicsBody?.collisionBitMask = player.rawValue

        scene.physicsWorld.contactDelegate = self
    }

    private func prepareInfiniteBackgroundScroller(for scene: SKScene) {
        let scaleFactor = NodeScale.gameBackgroundScale.getValue()

        // Use backgroundScrollSpeed — independent of gameplay difficulty — so the
        // parallax can be slowed or stopped without making the game easier.
        infiniteBackgroundNode = InfiniteSpriteScrollNode(
            fileName: backgroundResourceName,
            scaleFactor: CGPoint(x: scaleFactor, y: scaleFactor),
            speed: GameSettings.shared.backgroundScrollSpeed,
            coverWidth: scene.size.width
        )
        infiniteBackgroundNode!.zPosition = 0

        // Pin the tile's top edge to the scene top so the starry portion of the texture
        // fills the play area. The tile is taller than the scene, keeping the plain dark
        // bottom of the image below the visible area.
        let tileHeight = SKTexture(imageNamed: backgroundResourceName).size().height * CGFloat(scaleFactor)
        infiniteBackgroundNode!.position.y = scene.size.height - tileHeight

        scene.addChild(infiniteBackgroundNode!)
        updatables.append(infiniteBackgroundNode!)
    }

}

extension GameSceneAdapter: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        guard stateMachine?.currentState is PlayingState else { return }
        let collision: UInt32 = (contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask)
        let player = PhysicsCategories.player.rawValue

        if collision == (player | PhysicsCategories.gap.rawValue) {
            let threshold = contact.bodyA.categoryBitMask == PhysicsCategories.gap.rawValue
                ? contact.bodyA : contact.bodyB
            guard threshold.node?.userData?["scored"] as? Bool != true else { return }
            if threshold.node?.userData == nil { threshold.node?.userData = NSMutableDictionary() }
            threshold.node?.userData?["scored"] = true
            scorePoint()
        }

        if collision == (player | PhysicsCategories.pipe.rawValue) {
            handleDeadState()
        }

        if collision == (player | PhysicsCategories.boundary.rawValue) {
            handleDeadState()
        }
    }

    // MARK: - Collision Helpers

    private func handleDeadState() {
        // Ignore contacts that fire during a no-fail invulnerability window.
        if let heli = playerCharacter as? HelicopterNode, heli.isInvulnerable { return }

        if GameSettings.shared.noFailMode {
            handleNoFailHit()
        } else {
            deadState()
            hit()
            stopMoving()
        }
    }

    /// Called instead of deadState() when no-fail mode is active.
    /// Triggers a brief invulnerability window so the helicopter passes through pipes.
    private func handleNoFailHit() {
        (playerCharacter as? HelicopterNode)?.triggerInvulnerability()
        hit()
    }

    private func deadState() {
        if stateMachine?.currentState is GameOverState { return }
        let finalScore = score
        stateMachine?.enter(GameOverState.self)
        onGameOverEntered?()

        if GameSettings.shared.showScore && UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement,
                                 argument: "Game over. Score \(finalScore)")
        }
    }

    /// Plays the collision hit sound and haptic, unless calm mode is active.
    private func hit() {
        guard !GameSettings.shared.calmMode else { return }
        impact.impactOccurred()
        if isSoundEffectsOn { scene?.run(hitSound) }
    }

    private func stopMoving() {
        playerCharacter?.physicsBody?.velocity.dx = 0
    }
}
