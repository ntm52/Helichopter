import SpriteKit

typealias IsTopPipe = Bool

class PipeNode: SKSpriteNode {

    // MARK: - Initializers

    /// - Parameters:
    ///   - tintColor: Palette color blended onto the white/grayscale Phase 6 art.
    ///   - blendFactor: `SKSpriteNode.colorBlendFactor`. 0 = original art, 1 = solid tint.
    init?(textures: (pipe: String, cap: String), of size: CGSize, side: IsTopPipe,
          tintColor: UIColor = .white, blendFactor: CGFloat = 0.0) {

        // Outer node is a physics-only container — visuals live in the body and cap children.
        super.init(texture: nil, color: .clear, size: size)

        let bodyTexture = SKTexture(imageNamed: textures.pipe)

        // 9-slice stretching: top and bottom 1/6 of the texture are pixel-perfect
        // (decorative edge detail); the middle 4/6 stretches to any pipe height.
        // Phase 6 pipe art is 60×120 px with the fixed bands occupying 20 px each.
        let body = SKSpriteNode(texture: bodyTexture, color: tintColor, size: size)
        body.colorBlendFactor = blendFactor
        body.centerRect = CGRect(x: 0.0, y: 1.0 / 6.0, width: 1.0, height: 4.0 / 6.0)
        body.zPosition = 1
        addChild(body)

        let capTexture = SKTexture(imageNamed: textures.cap)
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
