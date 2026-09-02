import SpriteKit
import UIKit

class HelicopterNode: SKSpriteNode, Updatable, Playable, PhysicsContactable {

    // MARK: - Conformance to Playable, Updatable & PhysicsContactable protocols

    var delta: TimeInterval = 0
    var lastUpdateTime: TimeInterval = 0
    var shouldUpdate: Bool = true {
        didSet {
            if shouldUpdate {
                animate(with: animationTimeInterval)
            } else {
                self.removeAllActions()
            }
        }
    }

    var isAffectedByGravity: Bool = true {
        didSet {
            self.physicsBody?.affectedByGravity = isAffectedByGravity
        }
    }

    var shouldAcceptTouches: Bool = true {
        didSet {
            self.isUserInteractionEnabled = shouldAcceptTouches
        }
    }

    var shouldEnablePhysics: Bool = true {
        didSet {
            physicsBody?.collisionBitMask = shouldEnablePhysics ? collisionBitMask : 0
        }
    }

    var collisionBitMask: UInt32 = PhysicsCategories.pipe.rawValue | PhysicsCategories.boundary.rawValue

    // MARK: - Properties

    var flyTextures: [SKTexture]? = nil
    private(set) var animationTimeInterval: TimeInterval = 0
    private let impact = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Initializers

    convenience init(animationTimeInterval: TimeInterval, withTextureAtlas named: String, size: CGSize) {

        var textures = [SKTexture]()

        do {
            textures = try SKTextureAtlas.upload(named: named, beginIndex: 1) { name, index -> String in
                return "r_player\(index)"
            }
        } catch {
            debugPrint(#function + " thrown the error while uploading texture atlas : ", error)
        }

        self.init(texture: textures.first, color: .clear, size: size)
        self.animationTimeInterval = animationTimeInterval

        preparePhysicsBody()
        self.physicsBody?.velocity.dx = 0

        self.flyTextures = textures
        self.texture = textures.first
        self.animate(with: animationTimeInterval)
    }

    // MARK: - Methods

    fileprivate func preparePhysicsBody() {
        // Hitbox radius driven by GameSettings so it can be tuned independently
        let radius = (size.width / 2.0) * GameSettings.shared.hitboxFraction
        physicsBody = SKPhysicsBody(circleOfRadius: radius)

        physicsBody?.categoryBitMask = PhysicsCategories.player.rawValue
        physicsBody?.contactTestBitMask = PhysicsCategories.pipe.rawValue | PhysicsCategories.gap.rawValue | PhysicsCategories.boundary.rawValue
        physicsBody?.collisionBitMask = PhysicsCategories.pipe.rawValue | PhysicsCategories.boundary.rawValue

        physicsBody?.allowsRotation = false
        physicsBody?.restitution = 0.0
    }

    fileprivate func animate(with timing: TimeInterval) {
        guard let walkTextures = flyTextures else {
            return
        }
        let animateAction = SKAction.animate(with: walkTextures, timePerFrame: timing, resize: false, restore: true)
        let foreverAction = SKAction.repeatForever(animateAction)
        self.run(foreverAction)
    }

    // MARK: - Conformance to Updatable protocol

    func update(_ timeInterval: CFTimeInterval) {
        delta = lastUpdateTime == 0.0 ? 0.0 : timeInterval - lastUpdateTime
        lastUpdateTime = timeInterval

        guard let physicsBody = physicsBody else {
            return
        }

        let velocityY = physicsBody.velocity.dy
        let threshold = GameSettings.shared.terminalVelocity

        if velocityY > threshold {
            self.physicsBody?.velocity = CGVector(dx: 0, dy: threshold)
        }

        let velocityValue = velocityY * (velocityY < 0 ? 0.004 : 0.002)
        zRotation = velocityValue.clamp(min: -1, max: 1.0)
    }

}

extension HelicopterNode: Touchable {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !shouldAcceptTouches { return }

        impact.impactOccurred()

        isAffectedByGravity = true
        physicsBody?.applyImpulse(CGVector(dx: 0, dy: GameSettings.shared.flapStrength))
    }
}
