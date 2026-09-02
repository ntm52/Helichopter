import SpriteKit
import GameplayKit

extension SKScene {

    func findAllButtonsInScene() -> [ButtonNode] {
        return ButtonIdentifier.allButtonIdentifiers.compactMap { buttonIdentifier in
            childNode(withName: "//\(buttonIdentifier.rawValue)") as? ButtonNode
        }
    }
}

class GameSceneAdapter: NSObject, GameSceneProtocol {

    // MARK: - Properties

    private let overlayDuration: TimeInterval = 0.25

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

    var score: Int = 0
    private(set) var scoreLabel: SKLabelNode?

    private(set) var scoreSound = SKAction.playSoundFileNamed("Score.wav", waitForCompletion: false)
    private(set) var hitSound = SKAction.playSoundFileNamed("Dead.wav", waitForCompletion: false)

    typealias PlayableCharacter = (PhysicsContactable & Updatable & Touchable & Playable & SKNode)
    var playerCharacter: PlayableCharacter?

    private(set) lazy var menuAudio: SKAudioNode = {
        let audioNode = SKAudioNode(fileNamed: "MainTheme.wav")
        audioNode.autoplayLooped = true
        audioNode.name = "menu audio"
        return audioNode
    }()

    private(set) lazy var playingAudio: SKAudioNode = {
        let audioNode = SKAudioNode(fileNamed: "MainTheme.wav")
        audioNode.autoplayLooped = true
        audioNode.name = "playing audio"
        return audioNode
    }()

    // MARK: - Conformance to GameSceneProtocol

    weak var scene: SKScene?
    var stateMachine: GKStateMachine?

    var updatables = [Updatable]()
    var touchables = [Touchable]()

    var buttons = [ButtonNode]()

    var overlay: SceneOverlay? {
        didSet {
            buttons = []

            oldValue?.backgroundNode.run(SKAction.fadeOut(withDuration: overlayDuration)) {
                oldValue?.backgroundNode.removeFromParent()
            }

            if let overlay = overlay, let scene = scene {
                overlay.backgroundNode.removeFromParent()
                scene.addChild(overlay.backgroundNode)
                overlay.backgroundNode.alpha = 1.0
                overlay.backgroundNode.run(SKAction.fadeIn(withDuration: overlayDuration))
                buttons = scene.findAllButtonsInScene()
            }
        }
    }

    private var _isHUDHidden: Bool = false
    var isHUDHidden: Bool {
        get { _isHUDHidden }
        set {
            _isHUDHidden = newValue
            if let world = self.scene?.childNode(withName: "world") {
                world.childNode(withName: "Score Node")?.isHidden = newValue
                world.childNode(withName: "Pause")?.isHidden = newValue
            }
        }
    }

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

    convenience init?(with scene: SKScene, stateMachine: GKStateMachine) {
        self.init(with: scene)
        self.stateMachine = stateMachine
    }

    // MARK: - Helpers

    func resetScores() {
        scoreLabel?.text = "Score 0"
    }

    func removePipes() {
        var nodes = [SKNode]()

        infiniteBackgroundNode?.children.forEach({ node in
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

        infiniteBackgroundNode = InfiniteSpriteScrollNode(
            fileName: backgroundResourceName,
            scaleFactor: CGPoint(x: scaleFactor, y: scaleFactor),
            speed: GameSettings.shared.scrollSpeed
        )
        infiniteBackgroundNode!.zPosition = 0

        scene.addChild(infiniteBackgroundNode!)
        updatables.append(infiniteBackgroundNode!)
    }

}

extension GameSceneAdapter: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        let collision: UInt32 = (contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask)
        let player = PhysicsCategories.player.rawValue

        if collision == (player | PhysicsCategories.gap.rawValue) {
            score += 1
            scoreLabel?.text = "Score \(score)"

            if isSoundEffectsOn { scene?.run(scoreSound) }

            notification.notificationOccurred(.success)
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
        deadState()
        hit()
        stopMoving()
    }

    private func deadState() {
        if stateMachine?.currentState is GameOverState { return }
        stateMachine?.enter(GameOverState.self)
    }

    private func hit() {
        impact.impactOccurred()
        if isSoundEffectsOn { scene?.run(hitSound) }
    }

    private func stopMoving() {
        playerCharacter?.physicsBody?.velocity.dx = 0
    }
}
