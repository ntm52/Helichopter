import Foundation
import CoreGraphics

protocol Playable: AnyObject {
    var isAffectedByGravity: Bool { get set }
    var size: CGSize { get set }
}
