import Testing
import SpriteKit
import GameplayKit
import UIKit
@testable import Helichopter

@MainActor @Suite("Unified presentation", .serialized)
struct PresentationTests {
    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    private func capture(_ view: SKView, overlay: SceneTextOverlay, name: String) throws {
        overlay.layoutIfNeeded()
        overlay.layoutIfNeeded()
        let texture = view.scene.flatMap { view.texture(from: $0) }
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { context in
            if let texture = texture { UIImage(cgImage: texture.cgImage()).draw(in: view.bounds) }
            overlay.layer.render(in: context.cgContext)
        }
        Attachment.record(try #require(image.pngData()), named: name + ".png")
    }

    @Test func contrastAndPausePreferencesPersist() {
        let defaults = UserDefaults(suiteName: "PresentationTests.\(UUID())")!
        let settings = GameSettings(defaults: defaults)
        #expect(settings.helicopterOutline)
        #expect(!settings.hideGameWhilePaused)
        settings.helicopterOutline = false
        settings.hideGameWhilePaused = true
        #expect(!GameSettings(defaults: defaults).helicopterOutline)
        #expect(GameSettings(defaults: defaults).hideGameWhilePaused)
    }

    @Test func largestHUDTextFitsAndPauseDoesNotOverlapHint() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        let host = UIViewController()
        host.view = view
        let window = UIWindow(frame: view.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; view.presentScene(nil) }
        let scene = try #require(GameScene(fileNamed: "GameScene"))
        view.presentScene(scene)
        let overlay = SceneTextOverlay(frame: view.bounds)
        view.addSubview(overlay)
        if #available(iOS 17.0, *) {
            overlay.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            overlay.updateTraitsIfNeeded()
        }
        overlay.refresh(in: view)
        overlay.layoutIfNeeded()
        overlay.layoutIfNeeded()
        let pause = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Pause" })
        let hint = try #require(descendants(overlay, UILabel.self).first { $0.text == "CLICK ME TO FLY" })
        let pauseFrame = pause.convert(pause.bounds, to: overlay)
        let hintFrame = hint.convert(hint.bounds, to: overlay)
        #expect(!pauseFrame.intersects(hintFrame))
        #expect(overlay.hitTest(CGPoint(x: pauseFrame.midX, y: pauseFrame.midY), with: nil) === pause)
        #expect(overlay.hitTest(CGPoint(x: 160, y: 550), with: nil) == nil)
        for label in descendants(overlay, UILabel.self) where !label.isHidden && label.bounds.width > 0 {
            let required = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            #expect(label.bounds.height + 2 >= required.height)
        }
        try capture(view, overlay: overlay, name: "Unified-Largest-HUD")
    }

    @Test func singleMenuAndHUDPreserveNavigation() throws {
        let gs = GameSettings.shared
        let outline = gs.helicopterOutline
        let hide = gs.hideGameWhilePaused
        let show = gs.showScore
        let scanning = gs.scanningEnabled
        let guideKey = "onboarding_completed_v1"
        let guideCompleted = UserDefaults.standard.object(forKey: guideKey)
        UserDefaults.standard.set(true, forKey: guideKey)
        gs.scanningEnabled = false
        gs.showScore = true
        defer {
            gs.helicopterOutline = outline
            gs.hideGameWhilePaused = hide
            gs.showScore = show
            gs.scanningEnabled = scanning
            if let guideCompleted = guideCompleted { UserDefaults.standard.set(guideCompleted, forKey: guideKey) }
            else { UserDefaults.standard.removeObject(forKey: guideKey) }
        }
        for archive in ["TitleScene", "TitleScene iPad", "GameScene", "GameScene iPad"] {
            gs.helicopterOutline = false
            gs.hideGameWhilePaused = false
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let scene = try #require(SKScene(fileNamed: archive))
            view.presentScene(scene)
            defer { view.presentScene(nil) }
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            overlay.refresh(in: view)
            overlay.layoutIfNeeded()
            #expect(scene.findAllButtonsInScene().allSatisfy { $0.isPresentedInUIKit && $0.alpha == 0 && !$0.isUserInteractionEnabled })
            try capture(view, overlay: overlay, name: "Unified-" + archive)
            if scene is TitleScene {
                let mascot = try #require(scene.childNode(withName: "Animated Helicopter"))
                #expect(mascot.isHidden && !mascot.hasActions())
                #expect(descendants(overlay, UIImageView.self).count == 1)
                #expect(descendants(overlay, UIButton.self).filter { $0.currentTitle == "Play" }.count == 1)
            }
            if let game = scene as? GameScene {
                let player = try #require(game.sceneAdapter?.playerCharacter as? HelicopterNode)
                #expect(player.childNode(withName: "flightBoundary")?.isHidden == true)
                let pauses = descendants(overlay, UIButton.self).filter { $0.currentTitle == "Pause" }
                #expect(pauses.count == 1)
                game.sceneAdapter?.score = 999999
                overlay.refresh(in: view)
                let best = try #require(descendants(overlay, UILabel.self).first { $0.text == "Best 999999" })
                #expect(!best.isHidden)
                gs.showScore = false
                overlay.refresh(in: view)
                #expect(best.isHidden)
                gs.showScore = true
                let pause = try #require(pauses.first)
                pause.sendActions(for: .touchUpInside)
                #expect(game.stateMachine.currentState is PausedState)
                overlay.refresh(in: view)
                try capture(view, overlay: overlay, name: "Unified-Pause-" + archive)
                #expect(!descendants(overlay, UILabel.self).contains { $0.text == "CLICK ME TO FLY" })
                #expect(overlay.backgroundColor?.cgColor.alpha == 0.25)
                #expect(game.sceneAdapter?.overlay?.backgroundNode.color.cgColor.alpha == 0)
                #expect(!scene.findAllButtonsInScene().contains { $0.buttonIdentifier == .pause })
                let resume = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Resume" })
                resume.sendActions(for: .touchUpInside)
                overlay.refresh(in: view)
                #expect(game.stateMachine.currentState is PlayingState)
                gs.hideGameWhilePaused = true
                #expect(game.stateMachine.enter(PausedState.self))
                overlay.refresh(in: view)
                #expect(overlay.backgroundColor?.cgColor.alpha == 1)
                game.setupOverlayScanner(forceStart: true)
                game.switchPrimaryBegan()
                game.switchPrimaryEnded()
                #expect(game.stateMachine.currentState is PlayingState)
            }
        }
    }
}
