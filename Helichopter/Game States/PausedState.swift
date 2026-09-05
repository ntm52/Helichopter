import GameplayKit
import SpriteKit

class PausedState: GKState {
    
    // MARK: - Properites
    
    var overlaySceneFileName: String {
        return Scenes.pause.getName()
    }
    
    unowned var levelScene: SKScene
    unowned var adapter: GameSceneAdapter
    var overlay: SceneOverlay!
    
    // MARK: - Intializers
    
    init(scene: SKScene, adapter: GameSceneAdapter) {
        self.levelScene = scene
        self.adapter = adapter
        super.init()
        overlay = SceneOverlay(overlaySceneFileName: overlaySceneFileName, zPosition: 1000)
    }
    
    // MARK: GKState Life Cycle
    
    override func didEnter(from previousState: GKState?) {
        super.didEnter(from: previousState)

        (adapter.playerCharacter as? HelicopterNode)?.prepareForNewRun()
        adapter.playerCharacter?.shouldAcceptTouches = false
        levelScene.isPaused = true
        overlay.applyUITheme(GameSettings.shared.selectedTheme)
        adapter.overlay = overlay
        adapter.isHUDHidden = true
    }
    
    override func willExit(to nextState: GKState) {
        super.willExit(to: nextState)
        
        adapter.playerCharacter?.shouldAcceptTouches = true
        levelScene.isPaused = false
        adapter.overlay = nil
        adapter.isHUDHidden = false
    }
    
    // MARK: Convenience
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return true
    }
}
