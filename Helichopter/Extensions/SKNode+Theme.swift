import SpriteKit
import UIKit

extension SKNode {

    /// Recursively applies the UITheme to all ButtonNode tints, SKLabelNode font colors,
    /// and — when the theme requests it — background nodes throughout the scene tree.
    ///
    /// Any node whose name begins with "background" (case-insensitive) is HIDDEN when the
    /// theme provides a `backgroundSpriteTintColor`. Hiding rather than tinting is required
    /// because SpriteKit's colorBlend multiplies tint × texture pixels — cream × dark-sky
    /// texture stays dark. Hiding lets the scene's backgroundColor (set to the cream value)
    /// show through instead. Covers:
    ///   - "Background Scroll"  (TitleScene static sprite in the .sks editor)
    ///   - "background"         (InfiniteSpriteScrollNode tile sprites in GameScene)
    ///   - "Background 01" / "Background" and any other naming variations
    ///
    /// Labels inside a ButtonNode always receive `buttonTextColor` regardless of font size,
    /// preventing the title-accent color from appearing on tinted button backgrounds.
    func applyUITheme(_ theme: UITheme, insideButton: Bool = false) {
        for child in children {
            if let button = child as? ButtonNode {
                button.color                 = theme.buttonTintColor
                button.themeColorBlendFactor = 1.0
                button.colorBlendFactor      = 1.0
                button.applyUITheme(theme, insideButton: true)
            } else {
                // Hide any background-named node so the scene's solid backgroundColor shows
                // through. No SKSpriteNode cast needed — hiding works on any node type.
                if theme.backgroundSpriteTintColor != nil,
                   child.name?.lowercased().hasPrefix("background") == true {
                    child.isHidden = true
                }

                if let label = child as? SKLabelNode {
                    label.fontColor = (insideButton || label.fontSize < 30)
                        ? theme.buttonTextColor
                        : theme.titleTextColor
                }

                child.applyUITheme(theme, insideButton: insideButton)
            }
        }
    }
}

/// Opaque two-tone boundaries keep gameplay shapes readable independently of texture tint.
/// Black/white is 21:1; at least one band contrasts ≥4.58:1 with any solid sRGB backdrop.
/// This is an object-boundary treatment, not a contrast guarantee for every artwork pixel.
extension SKNode {
    func addGameplayBoundary(path: CGPath, filled: Bool = false) {
        for (name, color, width, depth) in [
            ("contrastOuter", UIColor.black, CGFloat(8), CGFloat(0)),
            ("contrastInner", UIColor.white, CGFloat(3), CGFloat(1))
        ] {
            let band = SKShapeNode(path: path)
            band.name = name
            band.strokeColor = color
            band.lineWidth = width
            band.fillColor = filled ? .black : .clear
            band.isAntialiased = true
            band.zPosition = depth
            addChild(band)
        }
    }
}
