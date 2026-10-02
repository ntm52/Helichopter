import Testing
import UIKit
import SpriteKit
@testable import Helichopter

@MainActor @Suite("Onboarding", .serialized)
struct OnboardingTests {
    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    @Test func firstRunCompletionReplayAndSwitchNavigation() throws {
        let name = "OnboardingTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = GameSettings.shared
        let savedScan = settings.scanScheme
        let savedEnabled = settings.scanningEnabled
        settings.scanScheme = .twoSwitch
        settings.scanningEnabled = false
        defer { settings.scanScheme = savedScan; settings.scanningEnabled = savedEnabled }
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        let title = try #require(TitleScene(fileNamed: "TitleScene"))
        view.presentScene(title)
        defer { view.presentScene(nil) }
        let overlay = SceneTextOverlay(frame: view.bounds)
        overlay.guideDefaults = defaults
        view.addSubview(overlay)
        overlay.refresh(in: view)
        #expect(overlay.guidePage == 0)
        #expect(!defaults.bool(forKey: SceneTextOverlay.guideCompletedKey))
        #expect(!descendants(overlay, UIButton.self).contains { $0.currentTitle == "Play" })
        let scanner = try #require(title.focusScanner)
        scanner.start()
        let read = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Read this step aloud" })
        read.sendActions(for: .touchUpInside)
        #expect(!scanner.isActive)
        for page in 0..<3 {
            if !scanner.isActive { title.switchPrimaryBegan() }
            #expect(scanner.isActive)
            title.switchSecondaryBegan() // Next / Done
            title.switchPrimaryBegan()
            #expect(overlay.guidePage == (page == 2 ? nil : page + 1))
        }
        #expect(defaults.bool(forKey: SceneTextOverlay.guideCompletedKey))
        let help = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "How to Play" })
        help.sendActions(for: .touchUpInside)
        #expect(overlay.guidePage == 0)
        let skip = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Skip guide" })
        skip.sendActions(for: .touchUpInside)
        #expect(overlay.guidePage == nil)
        scanner.stop()
        let nextLaunch = SceneTextOverlay(frame: view.bounds)
        nextLaunch.guideDefaults = defaults
        nextLaunch.refresh(in: view)
        #expect(nextLaunch.guidePage == nil)
        #expect(descendants(nextLaunch, UIButton.self).contains { $0.currentTitle == "How to Play" })
    }

    @Test func largestTextGuideFitsScrollablePhoneAndTablet() throws {
        let name = "OnboardingLayout-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 1024, height: 768)] {
            defaults.removeObject(forKey: SceneTextOverlay.guideCompletedKey)
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let scene = try #require(TitleScene(fileNamed: "TitleScene"))
            view.presentScene(scene)
            defer { view.presentScene(nil) }
            let overlay = SceneTextOverlay(frame: view.bounds)
            overlay.guideDefaults = defaults
            view.addSubview(overlay)
            let window = UIWindow(frame: view.frame)
            let host = UIViewController()
            host.view = view
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            overlay.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            overlay.updateTraitsIfNeeded()
            overlay.refresh(in: view)
            for page in 0..<3 {
                overlay.layoutIfNeeded()
                overlay.layoutIfNeeded()
                for label in descendants(overlay, UILabel.self) where label.superview is UIStackView {
                    #expect(label.adjustsFontForContentSizeCategory)
                    #expect(label.font.pointSize > 30)
                    let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    #expect(label.bounds.height + 2 >= needed.height)
                }
                let image = UIGraphicsImageRenderer(bounds: overlay.bounds).image { overlay.layer.render(in: $0.cgContext) }
                Attachment.record(try #require(image.pngData()), named: "guide-\(Int(size.width))-\(page).png")
                let button = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == (page == 2 ? "Done" : "Next") })
                button.sendActions(for: .touchUpInside)
            }
        }
    }
}
