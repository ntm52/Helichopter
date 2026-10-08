import Testing
import UIKit
import SpriteKit
@testable import Helichopter

@MainActor @Suite("Onboarding", .serialized)
struct OnboardingTests {
    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    private func button(_ title: String, in controller: UIViewController) throws -> UIButton {
        try #require(descendants(controller.view, UIButton.self).first { $0.currentTitle == title })
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
        #expect(!GuideViewController.isCompleted(in: defaults))

        let guide = GuideViewController(defaults: defaults)
        var requested: [Screen] = []
        guide.navigate = { requested.append($0) }
        guide.loadViewIfNeeded()
        guide.screenDidAppear()
        defer { guide.screenWillDisappear() }
        #expect(guide.page == 0)
        #expect(descendants(guide.view, UIButton.self).map(\.currentTitle) == ["Read this step aloud", "Next", "Skip guide"])
        #expect(guide.headingLabel?.accessibilityTraits.contains(.header) == true)
        #expect(guide.scanner.items.count == guide.menu.buttons.count)

        // Reading aloud pauses scanning; the next switch press resumes it.
        let scanner = guide.scanner
        scanner.start()
        try button("Read this step aloud", in: guide).sendActions(for: .touchUpInside)
        #expect(!scanner.isActive)
        for page in 0..<3 {
            if !scanner.isActive { guide.switchPrimaryBegan() }
            #expect(scanner.isActive)
            guide.switchSecondaryBegan() // Next / Done
            guide.switchPrimaryBegan()
            if page < 2 {
                #expect(guide.page == page + 1)
                #expect(scanner.isActive && scanner.currentIndex == 0)
                #expect(descendants(guide.view, UIButton.self).contains { $0.currentTitle == "Back" })
            }
        }
        #expect(guide.page == 2)
        #expect(GuideViewController.isCompleted(in: defaults))
        guard case .home? = requested.last else { Issue.record("Done must go Home"); return }

        // Back returns a page; Skip finishes from anywhere.
        guide.show(page: 1)
        try button("Back", in: guide).sendActions(for: .touchUpInside)
        #expect(guide.page == 0)
        requested = []
        try button("Skip guide", in: guide).sendActions(for: .touchUpInside)
        guard case .home? = requested.last else { Issue.record("Skip must go Home"); return }

        // How to Play on Home replays the guide.
        let home = HomeViewController()
        home.navigate = { requested.append($0) }
        home.loadViewIfNeeded()
        try button("How to Play", in: home).sendActions(for: .touchUpInside)
        guard case .guide? = requested.last else { Issue.record("How to Play must open the guide"); return }
    }

    @Test func largestTextGuideFitsScrollablePhoneAndTablet() throws {
        let name = "OnboardingLayout-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 1024, height: 768)] {
            let guide = GuideViewController(defaults: defaults)
            guide.navigate = { _ in }
            guide.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = guide
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            for page in 0..<3 {
                guide.view.layoutIfNeeded()
                guide.view.layoutIfNeeded()
                for label in descendants(guide.view, UILabel.self) where label.superview is UIStackView {
                    #expect(label.adjustsFontForContentSizeCategory)
                    #expect(label.font.pointSize > 30)
                    let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    #expect(label.bounds.height + 2 >= needed.height)
                }
                let image = UIGraphicsImageRenderer(bounds: guide.view.bounds).image { guide.view.layer.render(in: $0.cgContext) }
                Attachment.record(try #require(image.pngData()), named: "guide-\(Int(size.width))-\(page).png")
                if page < 2 { try button("Next", in: guide).sendActions(for: .touchUpInside) }
                #expect(guide.page == min(page + 1, 2))
            }
        }
    }
}
