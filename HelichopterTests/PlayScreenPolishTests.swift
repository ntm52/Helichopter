import Testing
import SpriteKit
import UIKit
@testable import Helichopter

/// Plan 03 Stage 5: Score and Best as chips, Pause with a picture at the trailing edge.
@MainActor @Suite("Play screen polish", .serialized)
struct PlayScreenPolishTests {

    /// The HUD in a window, so text-size changes reach it as they do in the app.
    private func makeHUD(_ category: UIContentSizeCategory, width: CGFloat = 390) throws -> (SKView, SceneTextOverlay) {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: width, height: 844))
        let window = makeTestWindow(frame: view.frame)
        let host = UIViewController()
        host.view = view
        window.rootViewController = host
        window.isHidden = false
        windows.append(window)
        let game = try #require(GameScene(fileNamed: "GameScene"))
        view.presentScene(game)
        let overlay = SceneTextOverlay(frame: view.bounds)
        view.addSubview(overlay)
        // The text size must be in place before the HUD is built.
        overlay.traitOverrides.preferredContentSizeCategory = category
        overlay.updateTraitsIfNeeded()
        overlay.refresh(in: view)
        overlay.layoutIfNeeded()
        return (view, overlay)
    }

    private final class Windows { var all: [UIWindow] = []; deinit { let all = all; Task { @MainActor in all.forEach { $0.isHidden = true } } } }
    private let holder = Windows()
    private var windows: [UIWindow] {
        get { holder.all }
        nonmutating set { holder.all = newValue }
    }

    private func frame(_ view: UIView, in overlay: UIView) -> CGRect { view.convert(view.bounds, to: overlay) }

    @Test func chipsLeadAndPauseTrails() throws {
        let saved = GameSettings.shared.showScore
        defer { GameSettings.shared.showScore = saved }
        GameSettings.shared.showScore = true
        for width in [CGFloat(375), 390, 1024] {
            let (view, overlay) = try makeHUD(.large, width: width)
            defer { view.presentScene(nil) }
            let score = frame(try #require(overlay.scoreChip), in: overlay)
            let best = frame(try #require(overlay.bestScoreChip), in: overlay)
            let pauseButton = try #require(overlay.pauseButton)
            let pause = frame(pauseButton, in: overlay)
            // One row: Score, Best, a gap, then Pause against the trailing margin.
            #expect(score.minX == Spacing.l && score.maxX < best.minX && best.maxX < pause.minX)
            #expect(abs(pause.maxX - (width - Spacing.l)) < 0.5)
            #expect(score.minY == best.minY && score.minY == pause.minY)
            // Pause is as large a target as any button, but no longer a slab across the screen.
            #expect(pause.height >= Layout.minButtonHeight && pause.width >= 100 && pause.width < width / 2)
            #expect(pauseButton.currentTitle == "Pause" && pauseButton.kind == .secondary)
            #expect(pauseButton.subviews.contains { ($0 as? UIImageView)?.image != nil })
            // Only Pause takes touches; a touch on a chip or below the HUD flies.
            #expect(overlay.hitTest(CGPoint(x: pause.midX, y: pause.midY), with: nil) === pauseButton)
            #expect(overlay.hitTest(CGPoint(x: score.midX, y: score.midY), with: nil) == nil)
            #expect(overlay.hitTest(CGPoint(x: width / 2, y: 600), with: nil) == nil)
        }
    }

    /// At accessibility text sizes Pause has a row of its own, above the chips.
    @Test func pauseSitsAboveChipsAtLargeTextSizes() throws {
        let saved = GameSettings.shared.showScore
        defer { GameSettings.shared.showScore = saved }
        GameSettings.shared.showScore = true
        let (view, overlay) = try makeHUD(.accessibilityExtraExtraExtraLarge, width: 375)
        defer { view.presentScene(nil) }
        let score = frame(try #require(overlay.scoreChip), in: overlay)
        let best = frame(try #require(overlay.bestScoreChip), in: overlay)
        let pause = frame(try #require(overlay.pauseButton), in: overlay)
        #expect(pause.maxY <= score.minY && score.minY == best.minY)
        for item in [score, best, pause] {
            #expect(item.minX >= 0 && item.maxX <= 375, "\(item) is on screen")
        }
        // The layout follows a text-size change without a rebuild.
        overlay.traitOverrides.preferredContentSizeCategory = .large
        overlay.updateTraitsIfNeeded()
        overlay.layoutIfNeeded()
        #expect(frame(try #require(overlay.pauseButton), in: overlay).minY == frame(try #require(overlay.scoreChip), in: overlay).minY)
    }

    /// A chip is one thing to VoiceOver, read as "Score 3".
    @Test func chipReadsAsOne() {
        let chip = ScoreChip(name: "Score", theme: GameSettings.shared.selectedTheme, traits: nil)
        chip.value = 3
        #expect(chip.isAccessibilityElement && chip.accessibilityLabel == "Score 3")
        #expect(chip.backgroundColor == GameSettings.shared.selectedTheme.cardColor)
    }
}
