import SpriteKit
import UIKit

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
