import GameplayKit
import SpriteKit

class PlayingState: GKState {

    // MARK: - Properties

    unowned var adapter: GameSceneAdapter

    private let playerScale = CGPoint(x: 0.4, y: 0.4)
    // 10 frames × 0.05 s = 0.5 s per full rotor rotation (2 Hz — well under the 3 Hz flicker threshold).
    private let animationTimeInterval: TimeInterval = 0.05

    private(set) var infinitePipeProducer: SKAction! = nil
    let infinitePipeProducerKey = "Pipe Action"

    // MARK: - Initializers

    init(adapter: GameSceneAdapter) {
        self.adapter = adapter
        super.init()

        guard let scene = adapter.scene else {
            return
        }
        preparePlayer(for: scene)

        if let scene = adapter.scene, let target = adapter.infiniteBackgroundNode {
            infinitePipeProducer = PipeFactory.launch(for: scene, targetNode: target)
        }
    }

    // MARK: - Lifecycle

    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)

        adapter.playerCharacter?.isAffectedByGravity = false
        // Pipes are NOT started here for fresh starts/retries — they wait for first input below.
        // For resume from pause, the pipe action was already running and resumes automatically
        // when PausedState.willExit sets isPaused = false.

        if adapter.isMusicOn {
            adapter.scene?.addChild(adapter.playingAudio)
            // B6 fix: run the action on the audio node rather than discarding it
            adapter.playingAudio.run(SKAction.play())
        }

        if previousState is PausedState {
            return
        }

        guard let scene = adapter.scene, let player = adapter.playerCharacter else {
            return
        }

        if adapter.isMusicOn {
            if let menuAudio = scene.childNode(withName: adapter.menuAudio.name!) {
                menuAudio.removeFromParent()
            }
        }

        // Pipes and the hint both wait for the player's first input.
        // The helicopter floats at the center with gravity off until the player acts.
        (adapter.playerCharacter as? HelicopterNode)?.onFirstInput = { [weak self] in
            guard let self = self else { return }
            self.adapter.scene?.run(self.infinitePipeProducer, withKey: self.infinitePipeProducerKey)
            scene.enumerateChildNodes(withName: "//*") { node, stop in
                guard let label = node as? SKLabelNode, label.text == "CLICK ME TO FLY" else { return }
                label.run(.fadeOut(withDuration: 0.5))
                stop.pointee = true
            }
        }

        let character = PlayableCharacter.helicopter
        position(player: character, in: scene)
        player.shouldUpdate = true
    }

    override func willExit(to nextState: GKState) {
        super.willExit(to: nextState)

        if adapter.isMusicOn {
            adapter.playingAudio.removeFromParent()
        }

        if nextState is GameOverState {
            adapter.scene?.removeAction(forKey: infinitePipeProducerKey)
            adapter.removePipes()
            adapter.resetScores()
            adapter.playerCharacter?.isAffectedByGravity = false
            adapter.playerCharacter?.physicsBody?.velocity.dy = 0
        }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return true
    }

    // MARK: - Methods

    private func preparePlayer(for scene: SKScene) {
        let character = PlayableCharacter.helicopter
        let assetName = character.getAssetName()

        adapter.playerCharacter = HelicopterNode(
            animationTimeInterval: animationTimeInterval,
            withTextureAtlas: assetName,
            size: adapter.playerSize)

        guard let playableCharacter = adapter.playerCharacter else {
            debugPrint(#function + " could not unwrap HelicopterNode, the execution will be aborted")
            return
        }
        position(player: character, in: scene)
        scene.addChild(playableCharacter)

        adapter.updatables.append(playableCharacter)
        adapter.touchables.append(playableCharacter)
    }

    private func position(player: PlayableCharacter, in scene: SKScene) {
        guard let playerNode = adapter.playerCharacter else {
            return
        }
        playerNode.position = CGPoint(x: playerNode.size.width / 2 + 50, y: scene.size.height / 2)
        playerNode.zPosition = 10
    }

}
