import GameplayKit
import SpriteKit

class GameOverState: GKState {

    // MARK: - Properties

    unowned var levelScene: GameSceneAdapter

    // MARK: - Initializers

    init(scene: GameSceneAdapter) {
        self.levelScene = scene
        super.init()
    }

    // MARK: GKState Life Cycle

    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)

        if previousState is PlayingState {
            levelScene.removePipes()
        }

        levelScene.playerCharacter?.shouldAcceptTouches = false
        updateScores()

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
        levelScene.reportPhase(.roundOver)
    }

    override func willExit(to nextState: GKState) {
        super.willExit(to: nextState)

        if nextState is PlayingState {
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
        // The Round Over menu shows this after the live score resets for the next run.
        levelScene.roundScore = currentScore
    }
}
