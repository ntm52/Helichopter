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
        for archive in ["GameScene", "GameScene iPad"] {
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let scene = try #require(SKScene(fileNamed: archive))
            #expect(archivedContentIsInvisible(scene))
            view.presentScene(scene)
            defer { view.presentScene(nil) }
            #expect(archivedContentIsInvisible(scene))
            if let game = scene as? GameScene {
                // Pause and Round Over add no SpriteKit content; UIKit draws them.
                for _ in 0..<2 {
                    // Music nodes come and go with play; nothing else may be added.
                    let nodeCount = scene.children.filter { !($0 is SKAudioNode) }.count
                    #expect(game.stateMachine.enter(PausedState.self))
                    #expect(scene.children.filter { !($0 is SKAudioNode) }.count == nodeCount)
                    #expect(archivedContentIsInvisible(scene))
                    #expect(game.stateMachine.enter(PlayingState.self))
                }
                #expect(game.stateMachine.enter(GameOverState.self))
                #expect(archivedContentIsInvisible(scene))
            }
        }
    }

    @Test func menusAreCentredAndHUDStaysAtTop() throws {
        for size in [CGSize(width: 390, height: 844), CGSize(width: 1024, height: 1366)] {
            let home = HomeViewController()
            home.view.frame = CGRect(origin: .zero, size: size)
            home.view.layoutIfNeeded()
            home.view.layoutIfNeeded()
            let homeStack = home.menu.stack.convert(home.menu.stack.bounds, to: home.view)
            #expect(abs(homeStack.midY - home.view.bounds.midY) < 30)
            #expect(homeStack.minY > size.height * 0.15)

            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            func stackFrame() throws -> CGRect {
                overlay.layoutIfNeeded()
                overlay.layoutIfNeeded()
                let stack = try #require(descendants(overlay, UIScrollView.self).first?.subviews.first { $0 is UIStackView })
                return stack.convert(stack.bounds, to: overlay)
            }
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
            #expect(!descendants(overlay, UIButton.self).contains(resume))
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
                #expect(game.flightHintText == expected)
                // First input hides it; a retry restores it for the next run.
                let heli = try #require(game.sceneAdapter?.playerCharacter as? HelicopterNode)
                heli.switchPrimaryBegan()
                heli.switchPrimaryEnded()
                #expect(game.flightHintText == nil)
                #expect(game.stateMachine.enter(GameOverState.self))
                #expect(game.stateMachine.enter(PlayingState.self))
                #expect(game.flightHintText == expected && hint.text == expected)
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
        gs.scanningEnabled = false
        gs.showScore = true
        defer {
            gs.helicopterOutline = outline
            gs.hideGameWhilePaused = hide
            gs.showScore = show
            gs.scanningEnabled = scanning
        }
        for archive in ["GameScene", "GameScene iPad"] {
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
            if let game = scene as? GameScene {
                let player = try #require(game.sceneAdapter?.playerCharacter as? HelicopterNode)
                #expect(player.childNode(withName: "flightBoundary")?.isHidden == true)
                let pauses = descendants(overlay, UIButton.self).filter { $0.currentTitle == "Pause" }
                #expect(pauses.count == 1)
                // Score changes reach the HUD as events; no refresh is needed.
                game.sceneAdapter?.score = 999999
                let best = try #require(descendants(overlay, UILabel.self).first { $0.text == "Best 999999" })
                #expect(!best.isHidden)
                // Show Score is read when the HUD is built (Settings is never open mid-round).
                gs.showScore = false
                #expect(game.stateMachine.enter(PausedState.self))
                #expect(game.stateMachine.enter(PlayingState.self))
                #expect(descendants(overlay, UILabel.self).first { $0.text == "Best 999999" }?.isHidden == true)
                gs.showScore = true
                #expect(game.stateMachine.enter(PausedState.self))
                #expect(game.stateMachine.enter(PlayingState.self))
                let pause = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Pause" })
                pause.sendActions(for: .touchUpInside)
                #expect(game.stateMachine.currentState is PausedState)
                overlay.refresh(in: view)
                try capture(view, overlay: overlay, name: "Unified-Pause-" + archive)
                #expect(!descendants(overlay, UILabel.self).contains { $0.text == game.flightHint?.text })
                #expect(overlay.backgroundColor?.cgColor.alpha == 0.25)
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

    /// Home is one UIKit screen: one mascot, one title, Play, Settings, and How to Play
    /// in scanning order, each labelled. Reduce Motion keeps the mascot still.
    @Test func homeIsOneLabelledScreen() throws {
        let saved = HomeViewController.prefersReducedMotion
        defer { HomeViewController.prefersReducedMotion = saved }
        for reduceMotion in [false, true] {
            HomeViewController.prefersReducedMotion = { reduceMotion }
            let home = HomeViewController()
            home.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            home.view.layoutIfNeeded()
            #expect(descendants(home.view, UIImageView.self).filter { $0 === home.mascot }.count == 1)
            #expect(home.mascot.isAnimating == !reduceMotion)
            #expect(home.mascot.animationImages?.count == (reduceMotion ? nil : 60))
            #expect(home.mascot.image != nil)
            #expect(home.titleLabel.text == "Helichopter" && home.titleLabel.accessibilityTraits.contains(.header))
            #expect(home.menu.buttons.map(\.currentTitle) == ["Play", "Settings", "How to Play"])
            #expect(home.menu.buttons.allSatisfy { !($0.accessibilityHint ?? "").isEmpty })
            #expect(home.scanner.items.map(\.accessibilityScanLabel) == ["Play", "Settings", "How to Play"])
            #expect(home.view.accessibilityViewIsModal)
            #expect(home.announcement as? UILabel === home.titleLabel)
        }
    }
}
