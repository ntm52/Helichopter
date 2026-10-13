import CoreGraphics

extension CGFloat {
    
    // MARK: - Methods
    
    func clamp(min: CGFloat, max: CGFloat) -> CGFloat {
        if (self > max) {
            return max
        } else if (self < min) {
            return min
        } else {
            return self
        }
    }
    
    static func range(min: CGFloat, max: CGFloat) -> CGFloat {
        CGFloat.random(in: min...max)
    }
}
