import UIKit

/// A window in the test host's scene. `UIWindow(frame:)` is deprecated, and a window
/// needs a scene to be shown.
@MainActor func makeTestWindow(frame: CGRect) -> UIWindow {
    let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first!
    let window = UIWindow(windowScene: scene)
    window.frame = frame
    return window
}
