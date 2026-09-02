import Foundation

protocol Updatable: AnyObject {

    // MARK: - Properties

    var delta: TimeInterval { get }
    var lastUpdateTime: TimeInterval { get }
    var shouldUpdate: Bool { get set }

    // MARK: - Methods

    func update(_ currentTime: TimeInterval)
}

extension Updatable {

    func computeUpdatable(currentTime: TimeInterval) -> (delta: TimeInterval, lastUpdateTime: TimeInterval) {
        let delta = (self.lastUpdateTime == 0.0) ? 0.0 : currentTime - self.lastUpdateTime
        let lastUpdateTime = currentTime
        return (delta: delta, lastUpdateTime: lastUpdateTime)
    }
}
