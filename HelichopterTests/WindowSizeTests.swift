import Testing
import SpriteKit
import UIKit
@testable import Helichopter

/// iPadOS 26 resizable windows mean the app can no longer assume full-screen
/// portrait/landscape sizes. Gameplay and menus must stay usable at any window shape.
@MainActor @Suite("Window sizes", .serialized)
struct WindowSizeTests {
    static let sizes: [CGSize] = [
        CGSize(width: 402, height: 874),   // iPhone 17
        CGSize(width: 375, height: 667),   // iPhone SE
        CGSize(width: 820, height: 1180),  // iPad full screen, portrait
        CGSize(width: 1180, height: 820),  // iPad full screen, landscape
        CGSize(width: 400, height: 1000),  // narrow iPad window
        CGSize(width: 600, height: 760),   // small iPad window
        CGSize(width: 1000, height: 420),  // short, wide iPad window
        CGSize(width: 320, height: 480)    // smallest window
    ]

    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    @Test func phoneAndFullScreenIPadKeepFillingTheScreen() throws {
        let phone = try #require(GameScene(fileNamed: "GameScene"))
        let pad = try #require(GameScene(fileNamed: "GameScene iPad"))
        #expect(GameViewController.scaleMode(for: phone, in: CGSize(width: 402, height: 874)) == .aspectFill)
        #expect(GameViewController.scaleMode(for: pad, in: CGSize(width: 820, height: 1180)) == .aspectFill)
        #expect(GameViewController.scaleMode(for: pad, in: CGSize(width: 1180, height: 820)) == .aspectFit)
    }

    @Test func helicopterCeilingAndFloorStayVisibleAtEveryWindowSize() throws {
        for archive in ["GameScene", "GameScene iPad"] {
            for size in Self.sizes {
                let view = SKView(frame: CGRect(origin: .zero, size: size))
                let game = try #require(GameScene(fileNamed: archive))
                game.scaleMode = GameViewController.scaleMode(for: game, in: size)
                view.presentScene(game)
                defer { view.presentScene(nil) }
                let bounds = view.bounds.insetBy(dx: -0.5, dy: -0.5)
                let heli = try #require(game.sceneAdapter?.playerCharacter as? HelicopterNode)
                let frame = heli.frame
                for corner in [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.maxY)] {
                    #expect(bounds.contains(view.convert(corner, from: game)),
                            "\(archive) at \(size): helicopter clipped")
                }
                // The full flight height (ceiling and floor boundaries) must be on screen.
                let top = view.convert(CGPoint(x: game.size.width / 2, y: game.size.height), from: game)
                let bottom = view.convert(CGPoint(x: game.size.width / 2, y: 0), from: game)
                #expect(bounds.contains(top) && bounds.contains(bottom), "\(archive) at \(size): ceiling or floor cropped")
            }
        }
    }

    @Test func menusAndHUDFitEveryWindowSize() throws {
        let suite = "WindowSizeTests-\(UUID())"
        let guideDefaults = try #require(UserDefaults(suiteName: suite))
        defer { guideDefaults.removePersistentDomain(forName: suite) }
        for size in Self.sizes {
            for screen in [HomeViewController() as MenuViewController, GuideViewController(defaults: guideDefaults)] {
                screen.view.frame = CGRect(origin: .zero, size: size)
                screen.view.layoutIfNeeded()
                screen.view.layoutIfNeeded()
                #expect(!screen.menu.buttons.isEmpty)
                for button in screen.menu.buttons {
                    let frame = button.convert(button.bounds, to: screen.view)
                    // Horizontally inside the window; tall menus may scroll vertically.
                    #expect(frame.minX >= 0 && frame.maxX <= size.width + 0.5,
                            "\(type(of: screen)) at \(size): \(button.currentTitle ?? "") off screen")
                    #expect(frame.height >= 44, "\(type(of: screen)) at \(size): \(button.currentTitle ?? "") too small to tap")
                }
                // The backdrop reaches the bottom of every window shape.
                if let sky = (screen.view as? BackdropView)?.sky {
                    #expect(sky.frame.maxY >= size.height, "\(type(of: screen)) at \(size): sky stops short")
                }
            }
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            for archive in ["GameScene"] {
                let scene = try #require(SKScene(fileNamed: archive))
                view.presentScene(scene)
                overlay.refresh(in: view)
                overlay.layoutIfNeeded()
                overlay.layoutIfNeeded()
                let buttons = descendants(overlay, UIButton.self)
                #expect(!buttons.isEmpty)
                for button in buttons {
                    let frame = button.convert(button.bounds, to: overlay)
                    // Horizontally inside the window; tall menus may scroll vertically.
                    #expect(frame.minX >= 0 && frame.maxX <= size.width + 0.5,
                            "\(archive) at \(size): \(button.currentTitle ?? "") off screen")
                    #expect(frame.height >= 44, "\(archive) at \(size): \(button.currentTitle ?? "") too small to tap")
                }
                if scene is GameScene {
                    let pause = try #require(buttons.first { $0.currentTitle == "Pause" })
                    #expect(overlay.bounds.contains(pause.convert(pause.bounds, to: overlay)), "Pause hidden at \(size)")
                }
            }
            view.presentScene(nil)
        }
    }

    @Test func settingsPanelFitsEveryWindowSize() throws {
        for size in Self.sizes {
            let screen = SettingsViewController()
            screen.view.frame = CGRect(origin: .zero, size: size)
            let panel = try #require(screen.panel)
            panel.layoutIfNeeded()
            panel.layoutIfNeeded()
            for control in descendants(panel, UIControl.self) where !(control.superview is UIControl) {
                guard !control.isHidden, control.bounds.width > 0,
                      !(sequence(first: control.superview, next: { $0?.superview }).contains { $0 is UIScrollView && $0 !== panel.subviews.first { $0 is UIScrollView } })
                else { continue }
                let frame = control.convert(control.bounds, to: panel)
                #expect(frame.minX >= -0.5 && frame.maxX <= size.width + 0.5,
                        "Settings at \(size): \(control.accessibilityLabel ?? "\(type(of: control))") off screen")
            }
        }
    }
}
