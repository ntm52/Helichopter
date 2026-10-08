import Testing
import SpriteKit
import GameplayKit
import UIKit
@testable import Helichopter

/// Plan 01 Stage A: every screen change goes through one helper that moves SpriteKit
/// and UIKit together, holds input, and announces the new screen once.
@MainActor @Suite("Screen transitions", .serialized)
struct ScreenTransitionTests {

    /// Runs `work` with the real storyboard controller in its own window, guide finished,
    /// and every `screenChanged` post counted instead of sent.
    private func withController(scanning: Bool = false, guideDone: Bool = true,
                                _ work: (GameViewController, SKView, () -> Int) async throws -> Void) async throws {
        let defaults = UserDefaults.standard
        let guideKey = GuideViewController.completedKey
        let savedGuide = defaults.object(forKey: guideKey)
        let savedScanning = GameSettings.shared.scanningEnabled
        let savedTheme = GameSettings.shared.selectedThemeID
        let savedMusic = defaults.object(forKey: "isMusicOn")
        let savedPoster = ScreenChangeAnnouncer.poster
        var posts = 0
        defer {
            if let savedGuide = savedGuide { defaults.set(savedGuide, forKey: guideKey) } else { defaults.removeObject(forKey: guideKey) }
            if let savedMusic = savedMusic { defaults.set(savedMusic, forKey: "isMusicOn") } else { defaults.removeObject(forKey: "isMusicOn") }
            GameSettings.shared.scanningEnabled = savedScanning
            GameSettings.shared.selectedThemeID = savedTheme
            ScreenChangeAnnouncer.poster = savedPoster
        }
        defaults.set(guideDone, forKey: guideKey)
        defaults.set(false, for: .isMusicOn)
        GameSettings.shared.scanningEnabled = scanning
        GameSettings.shared.selectedThemeID = "nightSky"
        ScreenChangeAnnouncer.poster = { _ in posts += 1 }

        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: GameViewController.self))
        let controller = try #require(storyboard.instantiateInitialViewController() as? GameViewController)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; (controller.view as? SKView)?.presentScene(nil) }
        let skView = try #require(controller.view as? SKView)
        // Let the window draw once, as it has on device before any button can be pressed.
        try await Task.sleep(for: .milliseconds(150))
        try await work(controller, skView, { posts })
    }

    private func waitForTransition(_ controller: GameViewController) async throws {
        for _ in 0..<40 where controller.isChangingScreen {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!controller.isChangingScreen)
    }

    private func button(_ id: ButtonIdentifier, in scene: SKScene?) throws -> ButtonNode {
        try #require(scene?.findAllButtonsInScene().first { $0.buttonIdentifier == id })
    }

    private func menuItem(_ action: MenuAction, in game: GameScene) throws -> GameMenuItem {
        try #require(game.menuItems.first { $0.action == action })
    }

    private func homeItem(_ action: HomeAction, in controller: GameViewController) throws -> MenuItem {
        let home = try #require(controller.menuScreen as? HomeViewController)
        return try #require(home.items.first { $0.title == action.title })
    }

    private func guideItem(_ title: String, in controller: GameViewController) throws -> MenuItem {
        let guide = try #require(controller.menuScreen as? GuideViewController)
        return try #require(guide.scanner.items.compactMap { $0 as? MenuItem }.first { $0.title == title })
    }

    private func settingsPanels(in view: UIView) -> [SettingsOverlayView] {
        view.subviews.compactMap { $0 as? SettingsOverlayView }
    }

    /// No code except the helper may call `presentScene`, or that screen change would
    /// bypass the snapshot and bring back the double page.
    @Test func onlyTheHelperPresentsScenes() throws {
        let appSources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Helichopter")
        let files = try #require(FileManager.default.enumerator(at: appSources, includingPropertiesForKeys: nil))
        var callers: [String: Int] = [:]
        var swiftFiles = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            swiftFiles += 1
            let source = try String(contentsOf: url, encoding: .utf8)
            let count = source.components(separatedBy: ".presentScene(").count - 1
            if count > 0 { callers[url.lastPathComponent] = count }
        }
        #expect(swiftFiles > 20)
        // One direct swap for bare views, one animated swap.
        #expect(callers == ["GameViewController.swift": 2])
    }

    /// Straight after each navigation exactly one screen is live: Home and the guide are
    /// UIKit screens over an empty SpriteKit view, and the overlay already describes
    /// the scene SpriteKit shows, with no refresh timer.
    @Test func eachNavigationShowsOneCurrentScreen() async throws {
        try await withController { controller, skView, posts in
            let overlay = controller.sceneTextOverlay
            func expectCurrent() {
                #expect(overlay.hostScene === skView.scene)
            }
            func expectHome() {
                #expect(controller.menuScreen is HomeViewController)
                #expect(skView.scene == nil)
                #expect(overlay.isHidden)
                #expect(controller.children.count == 1)
            }
            expectHome()
            expectCurrent()

            // Home → How to Play → Home
            var before = posts()
            try homeItem(.howToPlay, in: controller).scannerActivate()
            #expect(controller.menuScreen is GuideViewController)
            #expect(controller.children.count == 1 && skView.scene == nil)
            try await waitForTransition(controller)
            #expect(posts() - before == 1)
            before = posts()
            try guideItem("Skip guide", in: controller).scannerActivate()
            expectHome()
            try await waitForTransition(controller)
            #expect(posts() - before == 1)

            // Home → Settings
            before = posts()
            try homeItem(.settings, in: controller).scannerActivate()
            #expect(skView.scene is SettingsScene)
            #expect(controller.menuScreen == nil && controller.children.isEmpty)
            expectCurrent()
            #expect(overlay.isHidden)
            #expect(settingsPanels(in: skView).count == 1)
            try await waitForTransition(controller)
            #expect(posts() - before == 1)
            #expect(skView.subviews.allSatisfy { $0 === overlay || $0 is SettingsOverlayView })

            // Settings → Home
            before = posts()
            try #require(settingsPanels(in: skView).first).onBack?()
            expectHome()
            expectCurrent()
            #expect(settingsPanels(in: skView).isEmpty)
            try await waitForTransition(controller)
            #expect(posts() - before == 1)

            // Home → Play
            before = posts()
            try homeItem(.play, in: controller).scannerActivate()
            let game = try #require(skView.scene as? GameScene)
            #expect(controller.menuScreen == nil && controller.children.isEmpty)
            expectCurrent()
            #expect(!overlay.isHidden)
            #expect(settingsPanels(in: skView).isEmpty)
            #expect(overlay.subviewsOfType(UIButton.self).filter { $0.currentTitle == "Pause" }.count == 1)
            try await waitForTransition(controller)
            #expect(posts() - before == 1)

            // Pause → Home, with no refresh between: the HUD follows the scene's events.
            try button(.pause, in: game).scannerActivate()
            #expect(game.stateMachine.currentState is PausedState)
            #expect(overlay.gameMenu != nil)
            before = posts()
            try menuItem(.home, in: game).scannerActivate()
            expectHome()
            expectCurrent()
            #expect(overlay.gameMenu == nil)
            try await waitForTransition(controller)
            #expect(posts() - before == 1)
            let home = try #require(controller.menuScreen)
            #expect(skView.subviews.count == 2 && skView.subviews.first === overlay && skView.subviews.last === home.view)
        }
    }

    /// A player who has not finished the guide starts there; finishing it saves the
    /// 2.0 key and goes Home, and the next launch starts on Home.
    @Test func firstLaunchShowsTheGuideUntilFinished() async throws {
        try await withController(guideDone: false) { controller, skView, posts in
            let guide = try #require(controller.menuScreen as? GuideViewController)
            #expect(skView.scene == nil && controller.sceneTextOverlay.isHidden)
            #expect(guide.page == 0)
            try guideItem("Next", in: controller).scannerActivate()
            #expect(guide.page == 1 && controller.menuScreen === guide)
            #expect(!GuideViewController.isCompleted())
            try guideItem("Skip guide", in: controller).scannerActivate()
            #expect(GuideViewController.isCompleted())
            #expect(controller.menuScreen is HomeViewController)
            try await waitForTransition(controller)
        }
        try await withController { controller, _, _ in
            #expect(controller.menuScreen is HomeViewController)
        }
    }

    /// Switch, keyboard, and controller input goes to the UIKit screen when one shows.
    @Test func switchInputReachesHomeScanner() async throws {
        let savedScheme = GameSettings.shared.scanScheme
        defer { GameSettings.shared.scanScheme = savedScheme }
        GameSettings.shared.scanScheme = .twoSwitch
        try await withController { controller, _, _ in
            let home = try #require(controller.menuScreen as? HomeViewController)
            #expect(!home.scanner.isActive)
            home.switchPrimaryBegan()
            #expect(home.scanner.isActive && home.items[0].isFocused)
            #expect(home.menu.buttons[0].layer.borderWidth == 4)
            home.switchSecondaryBegan()
            #expect(home.items[1].isFocused && home.menu.buttons[1].layer.borderWidth == 4)
            #expect(home.menu.buttons[0].layer.borderWidth == 0)
            home.switchSecondaryBegan()
            home.switchPrimaryBegan() // How to Play
            #expect(controller.menuScreen is GuideViewController)
            #expect(!home.scanner.isActive)
            try await waitForTransition(controller)
        }
    }

    /// Taps, switches, scanners, and a second navigation are all ignored while the old
    /// screen fades, so a double-tap can never act on a screen that is leaving.
    @Test func inputDuringTransitionIsIgnored() async throws {
        try await withController(scanning: true) { controller, skView, _ in
            try homeItem(.play, in: controller).scannerActivate()
            let game = try #require(skView.scene as? GameScene)
            #expect(controller.isChangingScreen)
            #expect(!skView.isUserInteractionEnabled)

            try button(.pause, in: game).scannerActivate()
            #expect(game.stateMachine.currentState is PlayingState)

            controller.present(.home)
            #expect(skView.scene === game && controller.menuScreen == nil)

            try await waitForTransition(controller)
            #expect(skView.isUserInteractionEnabled)
            try button(.pause, in: game).scannerActivate()
            #expect(game.stateMachine.currentState is PausedState)

            // A scanner on the incoming screen is frozen until the fade ends.
            try menuItem(.home, in: game).scannerActivate()
            let home = try #require(controller.menuScreen as? HomeViewController)
            let scanner = home.scanner
            #expect(scanner.isActive && scanner.isSuspended)
            let focused = scanner.currentIndex
            scanner.secondaryAdvance()
            #expect(scanner.currentIndex == focused)
            // A Home choice made (e.g. by VoiceOver) while Home fades in is ignored.
            home.items[0].scannerActivate()
            #expect(controller.menuScreen === home && skView.scene == nil)
            try await waitForTransition(controller)
            #expect(scanner.isActive && !scanner.isSuspended)
        }
    }

    /// The plan's fallback image must contain the SpriteKit layer, not just UIKit.
    @Test func compositeSnapshotIncludesSpriteKit() async throws {
        try await withController { controller, skView, _ in
            controller.present(.scene(try #require(GameScene(fileNamed: Scenes.game.getName()))), transition: .instant)
            controller.sceneTextOverlay.isHidden = true
            let image = try #require(GameViewController.compositeSnapshot(of: skView)?.cgImage)
            #expect(image.width > 0)
            // The starfield has bright stars over a dark sky: some pixel must be near white.
            let data = try #require(image.dataProvider?.data as Data?)
            let bytesPerPixel = image.bitsPerPixel / 8
            var bright = 0
            for offset in stride(from: 0, to: data.count - 3, by: bytesPerPixel * 7)
                where data[offset] > 200 && data[offset + 1] > 200 && data[offset + 2] > 200 {
                bright += 1
            }
            #expect(bright > 0)
            controller.sceneTextOverlay.isHidden = false
        }
    }

    /// Reduce Motion and Prefer Cross-Fade Transitions get a short fade with no movement.
    @Test func reduceMotionSelectsTheNoMovementStyle() async throws {
        #expect(ScreenTransition.preferred(reduceMotion: true) == .crossFade(duration: ScreenTransition.reducedMotionDuration))
        #expect(ScreenTransition.reducedMotionDuration < ScreenTransition.standardDuration)
        #expect(ScreenTransition.preferred(reduceMotion: false) == .crossFade(duration: ScreenTransition.standardDuration))

        // The snapshot only fades: it never leaves its place or changes size.
        try await withController { controller, skView, _ in
            let home = try #require(controller.menuScreen)
            controller.present(.scene(try #require(SettingsScene(fileNamed: Scenes.setting.getName()))),
                               transition: .preferred(reduceMotion: true))
            #expect(home.view.superview == nil)
            let snapshot = try #require(skView.subviews.last)
            #expect(!(snapshot is SettingsOverlayView) && snapshot !== controller.sceneTextOverlay)
            #expect(snapshot.frame == skView.bounds)
            #expect(snapshot.transform == .identity)
            #expect(snapshot.layer.animationKeys()?.allSatisfy { $0 == "opacity" } == true)
            try await waitForTransition(controller)
        }
    }
}

private extension UIView {
    func subviewsOfType<T: UIView>(_ type: T.Type) -> [T] {
        subviews.flatMap { ($0 as? T).map { [$0] } ?? [] + $0.subviewsOfType(type) }
    }
}
