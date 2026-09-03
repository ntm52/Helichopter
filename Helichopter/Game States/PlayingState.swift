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
        adapter.scene?.run(infinitePipeProducer, withKey: infinitePipeProducerKey)

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

        // Fade out the tap-to-fly hint a few seconds after the game starts.
        // The label lives inside the "world" node; try the explicit path first,
        // then fall back to a full-tree search in case the hierarchy ever changes.
        let hint = scene.childNode(withName: "world/CLICK ME TO FLY")
            ?? scene.childNode(withName: "//CLICK ME TO FLY")
        if let hint {
            hint.alpha = 1
            hint.run(.sequence([.wait(forDuration: 3.0), .fadeOut(withDuration: 0.5)]))
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
