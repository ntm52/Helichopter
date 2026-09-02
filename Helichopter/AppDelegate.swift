import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Setting.registerDefaults()
        _ = GameSettings.shared  // initialises the shared instance and runs legacy migration
        return true
    }
}
