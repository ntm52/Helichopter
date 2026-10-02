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

    private func archivedContentIsInvisible(_ root: SKNode) -> Bool {
        var visible: [String] = []
        func walk(_ node: SKNode) {
            for child in node.children {
                if let button = child as? ButtonNode, !(button.isPresentedInUIKit && button.alpha == 0) {
                    visible.append("button \(button.name ?? "")")
                }
                if let label = child as? SKLabelNode, (label.fontColor?.cgColor.alpha ?? 0) > 0 {
                    visible.append("label \(label.text ?? "")")
                }
                walk(child)
            }
        }
        walk(root)
        if !visible.isEmpty { Issue.record("Archived content would render: \(visible)") }
        return visible.isEmpty
    }

    /// Before UIKit's first refresh (e.g. during a scene transition), archived menus,
    /// labels, and the Pause sprite must already be hidden so two versions never overlap.
    @Test func archivedScenesNeverRenderBeforeUIKitRefresh() throws {
        for archive in ["TitleScene", "TitleScene iPad", "GameScene", "GameScene iPad"] {
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let scene = try #require(SKScene(fileNamed: archive))
            #expect(archivedContentIsInvisible(scene))
            view.presentScene(scene)
            defer { view.presentScene(nil) }
            #expect(archivedContentIsInvisible(scene))
            if scene is TitleScene {
                #expect(scene.childNode(withName: "Animated Helicopter")?.isHidden == true)
            }
            if let game = scene as? GameScene {
                // Re-theming on every pause must not resurrect the archived pause menu.
                for _ in 0..<2 {
                    #expect(game.stateMachine.enter(PausedState.self))
                    let overlay = try #require(game.sceneAdapter?.overlay)
                    #expect(overlay.backgroundNode.color.cgColor.alpha == 0)
                    #expect(overlay.contentNode.texture == nil)
                    #expect(archivedContentIsInvisible(scene))
                    #expect(game.stateMachine.enter(PlayingState.self))
                }
                #expect(game.stateMachine.enter(GameOverState.self))
                #expect(archivedContentIsInvisible(scene))
            }
        }
        let settings = try #require(SettingsScene(fileNamed: "SettingsScene"))
        #expect(settings.children.allSatisfy { $0.isHidden })
    }

    @Test func menusAreCentredAndHUDStaysAtTop() throws {
        let guideKey = "onboarding_completed_v1"
        let guideCompleted = UserDefaults.standard.object(forKey: guideKey)
        UserDefaults.standard.set(true, forKey: guideKey)
        defer {
            if let guideCompleted = guideCompleted { UserDefaults.standard.set(guideCompleted, forKey: guideKey) }
            else { UserDefaults.standard.removeObject(forKey: guideKey) }
        }
        for size in [CGSize(width: 390, height: 844), CGSize(width: 1024, height: 1366)] {
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            func stackFrame() throws -> CGRect {
                overlay.layoutIfNeeded()
                overlay.layoutIfNeeded()
                let stack = try #require(descendants(overlay, UIScrollView.self).first?.subviews.first { $0 is UIStackView })
                return stack.convert(stack.bounds, to: overlay)
            }
            let title = try #require(TitleScene(fileNamed: "TitleScene"))
            view.presentScene(title)
            overlay.refresh(in: view)
            let menu = try stackFrame()
            #expect(abs(menu.midY - overlay.bounds.midY) < 30)
            #expect(menu.minY > overlay.bounds.height * 0.15)

            let game = try #require(GameScene(fileNamed: "GameScene"))
            view.presentScene(game)
            overlay.refresh(in: view)
            #expect(try stackFrame().minY < 40)
            #expect(descendants(overlay, UIButton.self).filter { $0.currentTitle == "Pause" }.count == 1)

            let pause = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Pause" })
            pause.sendActions(for: .touchUpInside)
            #expect(game.stateMachine.currentState is PausedState)
            let paused = try stackFrame()
            #expect(abs(paused.midY - overlay.bounds.midY) < 30)
            #expect(!descendants(overlay, UIButton.self).contains { $0.currentTitle == "Pause" })

            // A repeated tap on a menu that already closed must be ignored, not crash.
            let resume = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Resume" })
            resume.sendActions(for: .touchUpInside)
            #expect(game.stateMachine.currentState is PlayingState)
            #expect(resume.superview == nil)
            resume.sendActions(for: .touchUpInside)
            #expect(game.stateMachine.currentState is PlayingState)
            #expect(try stackFrame().minY < 40)
            view.presentScene(nil)
        }
    }

    @Test func flightHintMatchesSchemeAndResetsEachRun() throws {
        let gs = GameSettings.shared
        let saved = gs.controlScheme
        defer { gs.controlScheme = saved }
        var texts = Set<String>()
        for scheme in [ControlScheme.tapFlap, .holdHover, .autoHover, .twoSwitchUD] {
            gs.controlScheme = scheme
            for archive in ["GameScene", "GameScene iPad"] {
                let game = try #require(GameScene(fileNamed: archive))
                let hint = try #require(game.flightHint)
                let expected = GameScene.flightHintText(for: scheme, voiceOver: UIAccessibility.isVoiceOverRunning)
                #expect(hint.text == expected)
                #expect(!expected.localizedCaseInsensitiveContains("click"))
                texts.insert(GameScene.flightHintText(for: scheme, voiceOver: false))
                // First input fades it; a retry restores it for the next run.
                let heli = try #require(game.sceneAdapter?.playerCharacter as? HelicopterNode)
                heli.switchPrimaryBegan()
                heli.switchPrimaryEnded()
                #expect(hint.hasActions())
                #expect(game.stateMachine.enter(GameOverState.self))
                #expect(game.stateMachine.enter(PlayingState.self))
                #expect(hint.alpha == 1 && !hint.hasActions() && hint.text == expected)
            }
        }
        #expect(texts.count == 4)
        #expect(GameScene.flightHintText(for: .tapFlap, voiceOver: true).contains("Double-tap"))
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
        overlay.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        overlay.updateTraitsIfNeeded()
        overlay.refresh(in: view)
        overlay.layoutIfNeeded()
        overlay.layoutIfNeeded()
        let pause = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Pause" })
        let hintText = try #require(scene.flightHint?.text)
        let hint = try #require(descendants(overlay, UILabel.self).first { $0.text == hintText })
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
                #expect(!descendants(overlay, UILabel.self).contains { $0.text == game.flightHint?.text })
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
