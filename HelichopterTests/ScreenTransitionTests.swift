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
    private func withController(scanning: Bool = false,
                                _ work: (GameViewController, SKView, () -> Int) async throws -> Void) async throws {
        let defaults = UserDefaults.standard
        let guideKey = SceneTextOverlay.guideCompletedKey
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
        defaults.set(true, forKey: guideKey)
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

    /// Straight after each navigation exactly one menu is live, and the UIKit overlay
    /// already describes the scene SpriteKit shows: no waiting for the refresh timer.
    @Test func eachNavigationShowsOneCurrentScreen() async throws {
        try await withController { controller, skView, posts in
            let overlay = controller.sceneTextOverlay
            func expectCurrent() {
                #expect(overlay.hostScene === skView.scene)
            }
            #expect(skView.scene is TitleScene)
            expectCurrent()

            // Home → Settings
            var before = posts()
            try button(.settings, in: skView.scene).scannerActivate()
            #expect(skView.scene is SettingsScene)
            expectCurrent()
            #expect(overlay.isHidden)
            #expect(settingsPanels(in: skView).count == 1)
            try await waitForTransition(controller)
            #expect(posts() - before == 1)
            #expect(skView.subviews.allSatisfy { $0 === overlay || $0 is SettingsOverlayView })

            // Settings → Home
            before = posts()
            try #require(settingsPanels(in: skView).first).onBack?()
            #expect(skView.scene is TitleScene)
            expectCurrent()
            #expect(!overlay.isHidden)
            #expect(settingsPanels(in: skView).isEmpty)
            try await waitForTransition(controller)
            #expect(posts() - before == 1)

            // Home → Play
            before = posts()
            try button(.play, in: skView.scene).scannerActivate()
            let game = try #require(skView.scene as? GameScene)
            expectCurrent()
            #expect(!overlay.isHidden)
            #expect(settingsPanels(in: skView).isEmpty)
            #expect(overlay.subviewsOfType(UIButton.self).filter { $0.currentTitle == "Pause" }.count == 1)
            try await waitForTransition(controller)
            #expect(posts() - before == 1)

            // Pause → Home
            try button(.pause, in: game).scannerActivate()
            #expect(game.stateMachine.currentState is PausedState)
            controller.refreshSceneText()
            before = posts()
            try button(.home, in: game).scannerActivate()
            #expect(skView.scene is TitleScene)
            expectCurrent()
            #expect(!overlay.subviewsOfType(UIButton.self).contains { $0.currentTitle == "Resume" })
            try await waitForTransition(controller)
            #expect(posts() - before == 1)
            #expect(skView.subviews == [overlay])
        }
    }

    /// Taps, switches, scanners, and a second navigation are all ignored while the old
    /// screen fades, so a double-tap can never act on a screen that is leaving.
    @Test func inputDuringTransitionIsIgnored() async throws {
        try await withController(scanning: true) { controller, skView, _ in
            try button(.play, in: skView.scene).scannerActivate()
            let game = try #require(skView.scene as? GameScene)
            #expect(controller.isChangingScreen)
            #expect(!skView.isUserInteractionEnabled)

            try button(.pause, in: game).scannerActivate()
            #expect(game.stateMachine.currentState is PlayingState)

            controller.present(try #require(TitleScene(fileNamed: Scenes.title.getName())))
            #expect(skView.scene === game)

            try await waitForTransition(controller)
            #expect(skView.isUserInteractionEnabled)
            try button(.pause, in: game).scannerActivate()
            #expect(game.stateMachine.currentState is PausedState)

            // A scanner on the incoming screen is frozen until the fade ends.
            try button(.home, in: game).scannerActivate()
            let title = try #require(skView.scene as? TitleScene)
            let scanner = try #require(title.focusScanner)
            #expect(scanner.isActive && scanner.isSuspended)
            let focused = scanner.currentIndex
            scanner.secondaryAdvance()
            #expect(scanner.currentIndex == focused)
            try await waitForTransition(controller)
            #expect(scanner.isActive && !scanner.isSuspended)
        }
    }

    /// The plan's fallback image must contain the SpriteKit layer, not just UIKit.
    @Test func compositeSnapshotIncludesSpriteKit() async throws {
        try await withController { controller, skView, _ in
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
            controller.present(try #require(SettingsScene(fileNamed: Scenes.setting.getName())),
                               transition: .preferred(reduceMotion: true))
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
