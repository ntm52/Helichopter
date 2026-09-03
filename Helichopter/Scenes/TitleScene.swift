import SpriteKit
import UIKit

class TitleScene: RoutingUtilityScene {

    // MARK: - Overrides

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        loadSelectedPlayer()
        setupAudio()
        applyContrastStyling()
    }

    // MARK: - Private helpers

    private func loadSelectedPlayer() {
        guard let targetNode = childNode(withName: "Animated Helicopter") else { return }

        let helicopterNode = HelicopterNode(
            animationTimeInterval: 0.05,
            withTextureAtlas: "Helicopter Player",
            size: CGSize(width: 200, height: 200)
        )
        helicopterNode.isAffectedByGravity = false
        helicopterNode.position  = targetNode.position
        helicopterNode.zPosition = targetNode.zPosition
        scene?.addChild(helicopterNode)
        targetNode.removeFromParent()
    }

    private func setupAudio() {
        guard !UserDefaults.standard.bool(for: .isMusicOn) else { return }
        let audioNode = childNode(withName: "Audio Node") as? SKAudioNode
        audioNode?.isPaused = true
        audioNode?.removeAllActions()
        audioNode?.removeFromParent()
    }

    // Applies the active UITheme: background color, button tints, and label colors.
    // Runs after the .sks loads so it overrides any editor-set values.
    private func applyContrastStyling() {
        let theme = GameSettings.shared.selectedTheme
        backgroundColor = theme.sceneBackgroundColor

        // Use SpriteKit's own recursive enumeration to hide background nodes when
        // the theme wants a solid color. This is belt-and-suspenders alongside the
        // applyUITheme extension, which only walks direct children at each level.
        if theme.backgroundSpriteTintColor != nil {
            enumerateChildNodes(withName: "//*") { node, _ in
                guard node.name?.lowercased().hasPrefix("background") == true else { return }
                node.isHidden = true
            }
        }

        applyUITheme(theme)
    }
}
