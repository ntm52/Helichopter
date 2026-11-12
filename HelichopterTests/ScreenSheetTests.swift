import Testing
import UIKit
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

    private func descendants<T: UIView>(_ view: UIView, _ type: T.Type) -> [T] {
        view.subviews.flatMap { ($0 as? T).map { [$0] } ?? [] + descendants($0, type) }
    }
}
