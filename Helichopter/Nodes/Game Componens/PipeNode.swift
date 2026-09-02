import SpriteKit

typealias IsTopPipe = Bool

class PipeNode: SKSpriteNode {

    // MARK: - Initializers

    init?(textures: (pipe: String, cap: String), of size: CGSize, side: IsTopPipe) {

        guard let texture = UIImage(named: textures.pipe)?.cgImage else {
            return nil
        }
        let textureRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        // UIGraphicsImageRenderer renders at screen scale (2x/3x), fixing blurry pipes on retina.
        let renderer = UIGraphicsImageRenderer(size: size)
        let tiledBackground = renderer.image { context in
            context.cgContext.draw(texture, in: textureRect, byTiling: true)
        }

        guard let tiledCGImage = tiledBackground.cgImage else {
            return nil
        }
        let backgroundTexture = SKTexture(cgImage: tiledCGImage)
        let pipe = SKSpriteNode(texture: backgroundTexture)
        pipe.zPosition = 1

        let cap = SKSpriteNode(imageNamed: textures.cap)
        cap.position = CGPoint(x: 0.0, y: side ? -pipe.size.height / 2 + cap.size.height / 2 : pipe.size.height / 2 - cap.size.height / 2)
        cap.size = CGSize(width: pipe.size.width + pipe.size.width / 6, height: cap.size.height)
        cap.zPosition = 5
        pipe.addChild(cap)

        if side {
            let angle: CGFloat = 180.0
            cap.zRotation = angle.toRadians
        }

        super.init(texture: backgroundTexture, color: .clear, size: backgroundTexture.size())

        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.categoryBitMask = PhysicsCategories.pipe.rawValue
        physicsBody?.contactTestBitMask = PhysicsCategories.player.rawValue
        physicsBody?.collisionBitMask = PhysicsCategories.player.rawValue
        physicsBody?.isDynamic = false
        zPosition = 20

        self.addChild(pipe)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
