import Testing
import SpriteKit
import GameplayKit
import UIKit
@testable import Helichopter

@MainActor @Suite("Dynamic Type", .serialized)
struct DynamicTypeTests {
    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    private func capture(_ view: UIView, name: String) throws {
        view.layoutIfNeeded()
        view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { view.layer.render(in: $0.cgContext) }
        Attachment.record(try #require(image.pngData()), named: name + ".png")
        try image.pngData()?.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name + ".png"))
    }

    @Test func settingsTextScalesAndControlsRemainReachable() throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 1024, height: 768)] {
            let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
            let panel = SettingsOverlayView(frame: CGRect(origin: .zero, size: size),
                                            theme: GameSettings.shared.selectedTheme, fontTraits: traits)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            let host = UIViewController()
            host.view = panel
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            if #available(iOS 17.0, *) {
                panel.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            }
            if #available(iOS 17.0, *) { panel.updateTraitsIfNeeded() }
            panel.layoutIfNeeded()
            panel.layoutIfNeeded()
            let labels = descendants(panel, UILabel.self)
            // UIKit owns segmented-control internals; their font is explicitly scaled
            // by Settings and is not an automatically adjusting UILabel.
            for label in labels where !(label.text ?? "").isEmpty {
                var ancestor = label.superview
                var inSegment = false
                while let current = ancestor {
                    if current is UISegmentedControl { inSegment = true }
                    ancestor = current.superview
                }
                if !inSegment {
                    #expect(label.adjustsFontForContentSizeCategory, "Unscaled label: \(label.text ?? "")")
                }
            }
            let title = try #require(labels.first { $0.text == "Settings" })
            #expect(title.font.pointSize > 26)
            for label in labels where label.superview is UIStackView && label.bounds.width > 0 {
                let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                #expect(label.bounds.height + 2 >= needed.height, "Clipped: \(label.text ?? "")")
            }
            panel.startScanning(focusing: "Menu Theme")
            panel.primaryActivate()
            #expect(panel.switchScanner.items.count == GameSettings.allThemes.count + 1)
            try capture(panel, name: "Dynamic-settings-choices-\(Int(size.width))")
            panel.stopScanning()
        }
    }

    @Test func menusAndHUDUseScalableTextAndPreserveActions() throws {
        let saved = GameSettings.shared.scanningEnabled
        GameSettings.shared.scanningEnabled = false
        defer { GameSettings.shared.scanningEnabled = saved }
        for archive in ["TitleScene", "TitleScene iPad", "GameScene", "GameScene iPad"] {
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
            let scene = try #require(SKScene(fileNamed: archive))
            scene.scaleMode = .aspectFit
            view.presentScene(scene)
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            defer { view.presentScene(nil) }
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                if #available(iOS 17.0, *) { overlay.traitOverrides.preferredContentSizeCategory = category }
                overlay.refresh(in: view)
                overlay.layoutIfNeeded()
                overlay.layoutIfNeeded()
                let labels = descendants(overlay, UILabel.self)
                #expect(!labels.isEmpty)
                #expect(labels.allSatisfy { $0.adjustsFontForContentSizeCategory })
                try capture(overlay, name: "Dynamic-\(archive)-\(category.rawValue)")
            }
            if let game = scene as? GameScene {
                #expect(overlay.hitTest(CGPoint(x: 160, y: 500), with: nil) == nil)
                #expect(game.stateMachine.enter(PausedState.self))
                overlay.refresh(in: view)
                try capture(overlay, name: "Dynamic-pause-\(archive)")
                let resume = try #require(descendants(overlay, UIButton.self).first { $0.currentTitle == "Resume" })
                resume.sendActions(for: .touchUpInside)
                #expect(game.stateMachine.currentState is PlayingState)
                game.sceneAdapter?.score = 123456
                #expect(game.stateMachine.enter(GameOverState.self))
                overlay.refresh(in: view)
                try capture(overlay, name: "Dynamic-round-over-\(archive)")
                #expect(descendants(overlay, UILabel.self).contains { $0.text?.contains("123456") == true })
            }
        }
    }
}

@MainActor @Suite("VoiceOver flight", .serialized)
struct VoiceOverFlightTests {
    @Test func flightProxyControlsEverySchemeAndPauses() throws {
        let savedScheme = GameSettings.shared.controlScheme
        let savedScan = GameSettings.shared.scanningEnabled
        GameSettings.shared.scanningEnabled = false
        defer {
            GameSettings.shared.controlScheme = savedScheme
            GameSettings.shared.scanningEnabled = savedScan
        }
        for scheme in [ControlScheme.tapFlap, .holdHover, .autoHover, .twoSwitchUD] {
            GameSettings.shared.controlScheme = scheme
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let scene = try #require(GameScene(fileNamed: "GameScene"))
            view.presentScene(scene)
            defer { view.presentScene(nil) }
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            overlay.refresh(in: view)
            let proxy = try #require(overlay.accessibilityElements?.first as? FlightAccessibilityElement)
            let player = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
            #expect(proxy.accessibilityValue == "Ready to fly")
            #expect(proxy.accessibilityActivate())
            #expect(player.onFirstInput == nil)
            #expect(scene.action(forKey: "Pipe Action") != nil)
            overlay.refresh(in: view)
            #expect(overlay.accessibilityElements?.first as? FlightAccessibilityElement === proxy)
            switch scheme {
            case .tapFlap:
                #expect(player.isAffectedByGravity)
                #expect(!proxy.moveDown())
            case .holdHover:
                #expect(player.isHoveringHeld)
                #expect(proxy.accessibilityActivate())
                #expect(!player.isHoveringHeld)
            case .autoHover:
                #expect(!player.isAffectedByGravity)
                #expect(proxy.moveDown())
            case .twoSwitchUD:
                #expect(player.isTwoSwitchUpHeld)
                #expect(proxy.moveDown())
                #expect(!player.isTwoSwitchUpHeld && player.isTwoSwitchDownHeld)
                #expect(proxy.moveDown())
                #expect(!player.isTwoSwitchDownHeld)
            }
            #expect(proxy.accessibilityPerformEscape())
            #expect(scene.stateMachine.currentState is PausedState)
            #expect(!player.isHoveringHeld && !player.isTwoSwitchUpHeld && !player.isTwoSwitchDownHeld)
            #expect(!proxy.accessibilityActivate())
            overlay.refresh(in: view)
            #expect(!(overlay.accessibilityElements?.first is FlightAccessibilityElement))
        }
    }

    @Test func guidanceUsesNearestGapAndPlayerClearance() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scene = try #require(GameScene(fileNamed: "GameScene"))
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let player = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
        player.onFirstInput = nil
        #expect(scene.accessibilityFlightStatus.contains("Clear ahead"))
        let pipe = SKNode()
        pipe.name = "pipe"
        let gap = SKSpriteNode(color: .clear, size: CGSize(width: 20, height: 200))
        gap.position = CGPoint(x: player.position.x + 100, y: 400)
        gap.physicsBody = SKPhysicsBody(rectangleOf: gap.size)
        gap.physicsBody?.categoryBitMask = PhysicsCategories.gap.rawValue
        pipe.addChild(gap)
        scene.addChild(pipe)
        player.position.y = 250
        #expect(scene.accessibilityFlightStatus.contains("Move up"))
        player.position.y = 400
        #expect(scene.accessibilityFlightStatus.contains("Aligned with gap"))
        player.position.y = 550
        #expect(scene.accessibilityFlightStatus.contains("Move down"))
        pipe.position.x = -scene.size.width * 2
        #expect(scene.accessibilityFlightStatus.contains("Clear ahead"))
    }
}
