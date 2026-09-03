import Foundation

/// Defines a set of physics categories for in-game physics-enabled objects
struct PhysicsCategories : OptionSet {
    let rawValue : UInt32
    
    static let boundary     = PhysicsCategories(rawValue: 1 << 0)
    static let player       = PhysicsCategories(rawValue: 1 << 1)
    static let pipe         = PhysicsCategories(rawValue: 1 << 2)
    static let gap          = PhysicsCategories(rawValue: 1 << 3)
}
