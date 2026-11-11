import SpriteKit

typealias IsTopPipe = Bool

class PipeNode: SKSpriteNode {

    /// The name of each sprite that draws the pipe's body.
    static let bodyName = "pipeBody"

    // MARK: - Initializers

    /// - Parameters:
    ///   - tintColor: Palette color blended onto the white/grayscale Phase 6 art.
    ///   - blendFactor: `SKSpriteNode.colorBlendFactor`. 0 = original art, 1 = solid tint.
    init?(skin: Cosmetic, of size: CGSize, side: IsTopPipe,
          tintColor: UIColor = .white, blendFactor: CGFloat = 0.0) {

        // Outer node is a physics-only container — visuals live in the body and cap children.
        super.init(texture: nil, color: .clear, size: size)

        let bodyTexture = SKTexture(imageNamed: skin.pipeTextureName)
        // The art's height at the pipe's width, for art that keeps its shape.
        let artHeight = size.width * bodyTexture.size().height / max(bodyTexture.size().width, 1)

        if skin.repeatsPipeArt, artHeight > 0 {
            // A pattern must not stretch, so each piece shows as much of the art as it is
            // tall. The art is taller than any pipe in the bundled layouts, so one piece is
            // usual; a taller pipe repeats the art, which is drawn to join without a seam.
            var filled: CGFloat = 0
            while filled < size.height {
                let pieceHeight = min(artHeight, size.height - filled)
                let crop = CGRect(x: 0, y: 0, width: 1, height: pieceHeight / artHeight)
                let piece = SKSpriteNode(texture: SKTexture(rect: crop, in: bodyTexture), color: tintColor,
                                         size: CGSize(width: size.width, height: pieceHeight))
                piece.name = Self.bodyName
                piece.colorBlendFactor = blendFactor
                piece.position = CGPoint(x: 0, y: -size.height / 2 + filled + pieceHeight / 2)
                piece.zPosition = 1
                addChild(piece)
                filled += pieceHeight
            }
        } else {
            // 9-slice stretching: top and bottom 1/6 of the texture are pixel-perfect
            // (decorative edge detail); the middle 4/6 stretches to any pipe height.
            // Phase 6 pipe art is 60×120 px with the fixed bands occupying 20 px each.
            let body = SKSpriteNode(texture: bodyTexture, color: tintColor, size: size)
            body.name = Self.bodyName
            body.colorBlendFactor = blendFactor
            body.centerRect = CGRect(x: 0.0, y: 1.0 / 6.0, width: 1.0, height: 4.0 / 6.0)
            body.zPosition = 1
            addChild(body)
        }

        let capTexture = SKTexture(imageNamed: skin.capTextureName)
        // Cap width scales proportionally from the designed texture ratio (cap 80px / body 60px).
        let capWidth  = size.width * (capTexture.size().width / bodyTexture.size().width)
        let capHeight = capTexture.size().height
        let cap = SKSpriteNode(texture: capTexture, color: tintColor,
                               size: CGSize(width: capWidth, height: capHeight))
        cap.colorBlendFactor = blendFactor
        cap.position = CGPoint(
            x: 0.0,
            y: side ? -(size.height / 2.0) + capHeight / 2.0
                     :  (size.height / 2.0) - capHeight / 2.0
        )
        if side { cap.zRotation = .pi }
        cap.zPosition = 5
        addChild(cap)

        // Trace the combined body/cap silhouette so no seam crosses the opening.
        let halfBody = size.width / 2
        let halfCap = capWidth / 2
        let halfHeight = size.height / 2
        let shoulder = halfHeight - capHeight
        let points = [CGPoint(x: -halfBody, y: -halfHeight),
                      CGPoint(x: halfBody, y: -halfHeight),
                      CGPoint(x: halfBody, y: shoulder),
                      CGPoint(x: halfCap, y: shoulder),
                      CGPoint(x: halfCap, y: halfHeight),
                      CGPoint(x: -halfCap, y: halfHeight),
                      CGPoint(x: -halfCap, y: shoulder),
                      CGPoint(x: -halfBody, y: shoulder)]
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.x, y: side ? -$0.y : $0.y) })
        path.closeSubpath()
        let boundary = SKNode()
        boundary.name = "pipeBoundary"
        boundary.zPosition = 10
        boundary.addGameplayBoundary(path: path)
        addChild(boundary)

        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.categoryBitMask    = PhysicsCategories.pipe.rawValue
        physicsBody?.contactTestBitMask = PhysicsCategories.player.rawValue
        physicsBody?.collisionBitMask   = PhysicsCategories.player.rawValue
        physicsBody?.isDynamic = false
        zPosition = 20
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
