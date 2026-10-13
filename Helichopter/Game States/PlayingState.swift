import GameplayKit
import SpriteKit
import UIKit

class PlayingState: GKState {

    // MARK: - Properties

    unowned var adapter: GameSceneAdapter

    // 60 frames × 1/60 s = 1 second per animation loop.
    private let animationTimeInterval = HelicopterNode.rotorFrameInterval

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
        infinitePipeProducer = PipeFactory.launch(for: scene, targetNode: scene)
    }

    // MARK: - Lifecycle

    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)
        defer { adapter.reportPhase(.playing) }

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

        adapter.playerCharacter?.isAffectedByGravity = false
        (adapter.playerCharacter as? HelicopterNode)?.prepareForNewRun()
        adapter.beginRun()

        guard let scene = adapter.scene, let player = adapter.playerCharacter else {
            return
        }

        if adapter.isMusicOn {
            if let menuAudio = scene.childNode(withName: adapter.menuAudio.name!) {
                menuAudio.removeFromParent()
            }
        }

        // Refreshed each run so it matches the current scheme and VoiceOver state.
        (scene as? GameScene)?.showFlightHint(GameScene.flightHintText(for: GameSettings.shared.controlScheme,
                                                                        voiceOver: UIAccessibility.isVoiceOverRunning))

        // Pipes and the hint both wait for the player's first input.
        // The helicopter floats at the center with gravity off until the player acts.
        (adapter.playerCharacter as? HelicopterNode)?.onFirstInput = { [weak self, weak scene] in
            guard let self = self, let scene = scene else { return }
            self.adapter.scene?.run(self.infinitePipeProducer, withKey: self.infinitePipeProducerKey)
            (scene as? GameScene)?.hideFlightHint()
        }

        position(in: scene)
        player.shouldUpdate = true
    }

    override func willExit(to nextState: GKState) {
        super.willExit(to: nextState)
        (adapter.scene as? GameScene)?.cancelSwitchPauseHold()

        if adapter.isMusicOn {
            adapter.playingAudio.removeFromParent()
        }

        if nextState is GameOverState {
            adapter.scene?.removeAction(forKey: infinitePipeProducerKey)
            adapter.removePipes()
            adapter.playerCharacter?.isAffectedByGravity = false
            adapter.playerCharacter?.physicsBody?.velocity.dy = 0
        }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return true
    }

    // MARK: - Methods

    private func preparePlayer(for scene: SKScene) {
        let assetName = GameSettings.shared.selectedHelicopterSkin.assetName

        adapter.playerCharacter = HelicopterNode(
            animationTimeInterval: animationTimeInterval,
            withTextureAtlas: assetName,
            size: adapter.playerSize)

        guard let playableCharacter = adapter.playerCharacter else {
            debugPrint(#function + " could not unwrap HelicopterNode, the execution will be aborted")
            return
        }
        position(in: scene)
        scene.addChild(playableCharacter)

        adapter.updatables.append(playableCharacter)
        adapter.touchables.append(playableCharacter)
    }

    private func position(in scene: SKScene) {
        guard let playerNode = adapter.playerCharacter else {
            return
        }
        playerNode.position = CGPoint(x: playerNode.size.width / 2 + 50, y: scene.size.height / 2)
        playerNode.zPosition = 10
    }

}
