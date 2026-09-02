import GameplayKit
import SpriteKit

class GameOverState: GKState {

    // MARK: - Properties

    var overlaySceneFileName: String {
        return Scenes.failed.getName()
    }

    unowned var levelScene: GameSceneAdapter
    var overlay: SceneOverlay!

    private(set) var currentScoreLabel: SKLabelNode?

    // MARK: - Initializers

    init(scene: GameSceneAdapter) {
        self.levelScene = scene
        super.init()

        overlay = SceneOverlay(overlaySceneFileName: overlaySceneFileName, zPosition: 100)
        currentScoreLabel = overlay.contentNode.childNode(withName: "Current Score") as? SKLabelNode
    }

    // MARK: GKState Life Cycle

    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)

        if previousState is PlayingState {
            levelScene.removePipes()
        }

        levelScene.playerCharacter?.shouldAcceptTouches = false
        updateScores()
        updateOverlayPresentation()

        levelScene.overlay = overlay
        levelScene.isHUDHidden = true
        levelScene.playerCharacter?.shouldUpdate = false
        levelScene.scene?.removeAllActions()
        levelScene.score = 0

        if levelScene.isMusicOn {
            if let playingAudioNodeName = levelScene.playingAudio.name {
                levelScene.scene?.childNode(withName: playingAudioNodeName)?.removeFromParent()
            }
            if levelScene.scene?.childNode(withName: levelScene.menuAudio.name!) == nil {
                levelScene.scene?.addChild(levelScene.menuAudio)
                // B6 fix: run the action on the audio node rather than discarding it
                levelScene.menuAudio.run(SKAction.play())
            }
        }
    }

    override func willExit(to nextState: GKState) {
        super.willExit(to: nextState)

        if nextState is PlayingState {
            levelScene.overlay = nil
            levelScene.isHUDHidden = false
            levelScene.playerCharacter?.shouldAcceptTouches = true
        }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return true
    }
}

extension GameOverState {

    fileprivate func updateScores() {
        let bestScore = UserDefaults.standard.integer(for: .bestScore)
        let currentScore = levelScene.score

        if currentScore > bestScore {
            UserDefaults.standard.set(currentScore, for: .bestScore)
        }
        UserDefaults.standard.set(currentScore, for: .lastScore)
    }

    fileprivate func updateOverlayPresentation() {
        let contentNode = overlay.contentNode

        if let bestScoreLabel = contentNode.childNode(withName: "Best Score") as? SKLabelNode {
            let bestScore = UserDefaults.standard.integer(for: .bestScore)
            bestScoreLabel.text = "Best Score: \(bestScore)"
        }

        if let currentScore = contentNode.childNode(withName: "Current Score") as? SKLabelNode {
            currentScore.text = "Current Score: \(levelScene.score)"
        }
    }
}
