import GameplayKit
import SpriteKit

class PausedState: GKState {
    
    // MARK: - Properites
    
    unowned var levelScene: SKScene
    unowned var adapter: GameSceneAdapter
    
    // MARK: - Intializers
    
    init(scene: SKScene, adapter: GameSceneAdapter) {
        self.levelScene = scene
        self.adapter = adapter
        super.init()
    }
    
    // MARK: GKState Life Cycle
    
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)

        (adapter.playerCharacter as? HelicopterNode)?.prepareForNewRun()
        adapter.playerCharacter?.shouldAcceptTouches = false
        levelScene.isPaused = true
        adapter.isHUDHidden = true
        adapter.reportPhase(.paused)
    }
    
    override func willExit(to nextState: GKState) {
        super.willExit(to: nextState)
        
        adapter.playerCharacter?.shouldAcceptTouches = true
        levelScene.isPaused = false
        adapter.isHUDHidden = false
    }
    
    // MARK: Convenience
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return true
    }
}
