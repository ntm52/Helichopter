import Testing
import UIKit
import SpriteKit
import GameplayKit
@testable import Helichopter

/// Draws the menu screens (Home, the Hangar, the Settings menu and each of its pages) to PNG files, in every theme and at the default and largest
/// text sizes, so their looks can be checked by eye (Plan 03, "How to check each stage").
/// Tests cannot judge looks; this only makes the pictures. It is skipped unless a folder
/// is named:
///
///     TEST_RUNNER_SCREEN_SHEET=/some/folder xcodebuild test ... \
///         -only-testing:'HelichopterTests/ScreenSheetTests'
///
/// Each picture is as tall as its whole page, so nothing needs scrolling. There is no
/// safe area, so the top of each screen sits higher than on a device.
@MainActor struct ScreenSheetTests {
    private static let folder = ProcessInfo.processInfo.environment["SCREEN_SHEET"]

    @Test(.enabled(if: folder != nil)) func drawEveryMenuScreen() throws {
        let folder = URL(fileURLWithPath: try #require(Self.folder))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let settings = GameSettings.shared
        let savedTheme = settings.selectedThemeID
        defer { settings.selectedThemeID = savedTheme }

        let widths: [(name: String, width: CGFloat, height: CGFloat)] = [("phone", 402, 874), ("pad", 1024, 1366)]
        let sizes: [(name: String, category: UIContentSizeCategory)] = [("default", .large), ("largest", .accessibilityExtraExtraExtraLarge)]
        var screens: [(name: String, make: () -> UIViewController)] = [
            ("home", { HomeViewController() }), ("settings", { SettingsViewController() }), ("hangar", { HangarViewController() })
        ]
        for (index, category) in SettingsCategory.allCases.enumerated() {
            screens.append(("settings\(index + 1)-\(category)", { SettingsViewController(page: .category(category)) }))
        }
        for page in 0..<3 {
            screens.append(("guide\(page + 1)", {
                let guide = GuideViewController()
                guide.loadViewIfNeeded()
                guide.show(page: page)
                return guide
            }))
        }
        for theme in GameSettings.allThemes {
            settings.selectedThemeID = theme.id
            for device in widths {
                for size in sizes {
                    for screen in screens {
                        let controller = screen.make()
                        controller.traitOverrides.preferredContentSizeCategory = size.category
                        let window = makeTestWindow(frame: CGRect(x: 0, y: 0, width: device.width, height: device.height))
                        window.rootViewController = controller
                        window.isHidden = false
                        window.layoutIfNeeded()
                        // Grow the window to the whole page.
                        let scrolls = descendants(controller.view, UIScrollView.self).filter { $0.contentSize.height > $0.bounds.height }
                        if let scroll = scrolls.max(by: { $0.contentSize.height < $1.contentSize.height }) {
                            window.frame.size.height += scroll.contentSize.height - scroll.bounds.height
                            window.layoutIfNeeded()
                        }
                        // The layer is drawn directly: a window taller than the screen has
                        // nothing on screen for `drawHierarchy` to copy.
                        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
                            window.layer.render(in: context.cgContext)
                        }
                        let name = "\(screen.name)-\(theme.id)-\(device.name)-\(size.name).png"
                        try #require(image.pngData()).write(to: folder.appendingPathComponent(name))
                        window.isHidden = true
                    }
                }
            }
        }
    }

    /// Draws the HUD, Pause, and Round Over as the overlay shows them. SpriteKit's own
    /// drawing (the sky, helicopter, and pipes) does not appear in these pictures.
    @Test(.enabled(if: folder != nil)) func drawThePlayScreens() throws {
        let folder = URL(fileURLWithPath: try #require(Self.folder))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let settings = GameSettings.shared
        let saved = (settings.selectedThemeID, settings.showScore, settings.controlScheme)
        defer { (settings.selectedThemeID, settings.showScore, settings.controlScheme) = saved }
        settings.showScore = true
        settings.controlScheme = .autoHover
        let sizes: [(name: String, category: UIContentSizeCategory)] = [("default", .large), ("largest", .accessibilityExtraExtraExtraLarge)]
        for theme in GameSettings.allThemes {
            settings.selectedThemeID = theme.id
            for size in sizes {
                for phase in ["play", "paused", "roundover"] {
                    let view = SKView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
                    // In a window, so the chosen text size reaches every label.
                    let window = makeTestWindow(frame: view.frame)
                    let host = UIViewController()
                    host.view = view
                    window.rootViewController = host
                    window.isHidden = false
                    defer { window.isHidden = true }
                    let game = try #require(GameScene(fileNamed: "GameScene"))
                    view.presentScene(game)
                    defer { view.presentScene(nil) }
                    let overlay = SceneTextOverlay(frame: view.bounds)
                    view.addSubview(overlay)
                    overlay.traitOverrides.preferredContentSizeCategory = size.category
                    overlay.updateTraitsIfNeeded()
                    overlay.refresh(in: view)
                    game.sceneAdapter?.score = 12
                    if phase == "paused" { game.pauseForInterruption() }
                    if phase == "roundover" { _ = game.stateMachine.enter(GameOverState.self) }
                    overlay.layoutIfNeeded()
                    let image = UIGraphicsImageRenderer(bounds: overlay.bounds).image { context in
                        theme.sceneBackgroundColor.setFill()
                        context.fill(overlay.bounds)
                        overlay.layer.render(in: context.cgContext)
                    }
                    try #require(image.pngData()).write(to: folder.appendingPathComponent("\(phase)-\(theme.id)-phone-\(size.name).png"))
                }
            }
        }
    }

    private func descendants<T: UIView>(_ view: UIView, _ type: T.Type) -> [T] {
        view.subviews.flatMap { ($0 as? T).map { [$0] } ?? [] + descendants($0, type) }
    }
}
