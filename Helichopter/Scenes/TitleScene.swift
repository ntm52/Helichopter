import SpriteKit
import UIKit

class TitleScene: RoutingUtilityScene {

    // MARK: - Overrides

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        centerBackground()
        loadSelectedPlayer()
        setupAudio()
        applyContrastStyling()
    }

    private func centerBackground() {
        // The .sks-placed sprite has an incorrect squished size (487×281 instead of the
        // texture's 512×1500), so repositioning alone can't avoid the dark bottom zone.
        // Replace it: scale uniformly to fill the scene width and pin the top to the
        // scene top so the starry portion fills the screen.
        childNode(withName: "Background 01")?.removeFromParent()

        let texture = SKTexture(imageNamed: "Background")
        let bg = SKSpriteNode(texture: texture)
        bg.name = "Background 01"
        bg.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        let scale = size.width / texture.size().width
        bg.xScale = scale
        bg.yScale = scale
        bg.position = CGPoint(x: 0, y: size.height / 2)
        bg.zPosition = -1
        addChild(bg)
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
        // Keep the SKView background in sync so pillarbox bars on iPad landscape
        // match the theme rather than showing as black.
        view?.backgroundColor = theme.sceneBackgroundColor
    }
}
