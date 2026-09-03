import SpriteKit

/// Allows to quickly enable/disable collision detection for physics-enabled conformances
protocol PhysicsContactable {
    var shouldEnablePhysics: Bool { get set }
    var collisionBitMask: UInt32 { get }
}
