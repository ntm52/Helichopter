import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func sceneWillResignActive(_ scene: UIScene) {
        (window?.rootViewController as? RootViewController)?.suspendInput()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        (window?.rootViewController as? RootViewController)?.resumeInput()
    }
}
