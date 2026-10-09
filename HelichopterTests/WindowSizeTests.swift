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
        #expect(RootViewController.scaleMode(for: phone, in: CGSize(width: 402, height: 874)) == .aspectFill)
        #expect(RootViewController.scaleMode(for: pad, in: CGSize(width: 820, height: 1180)) == .aspectFill)
        #expect(RootViewController.scaleMode(for: pad, in: CGSize(width: 1180, height: 820)) == .aspectFit)
    }

    @Test func layoutSizesMatchTheirArchives() throws {
        for layout in GameLayout.allCases {
            let scene = try #require(layout.makeScene())
            #expect(scene.size == layout.sceneSize, "\(layout)")
            #expect(GameLayout(sceneSize: scene.size) == layout)
            let scroller = try #require(scene.sceneAdapter?.infiniteBackgroundNode)
            let tile = try #require(scroller.tiles.first)
            // The background scale follows the layout, not the device.
            #expect(abs(tile.xScale - CGFloat(layout.backgroundScale)) < 0.001, "\(layout)")
        }
    }

    /// Narrow iPad windows (Split View, Slide Over, Stage Manager) get the phone layout,
    /// which shows a larger game with smaller bars. Phones and full-screen iPads keep
    /// the layout they always had.
    @Test func narrowWindowsGetTheLargerPhoneLayout() throws {
        #expect(GameLayout.best(for: CGSize(width: 402, height: 874)) == .phone)
        #expect(GameLayout.best(for: CGSize(width: 375, height: 667)) == .phone)
        #expect(GameLayout.best(for: CGSize(width: 820, height: 1180)) == .pad)
        #expect(GameLayout.best(for: CGSize(width: 1180, height: 820)) == .pad)
        #expect(GameLayout.best(for: CGSize(width: 1000, height: 420)) == .pad)
        for narrow in [CGSize(width: 400, height: 1000), CGSize(width: 375, height: 1024),
                       CGSize(width: 320, height: 1180), CGSize(width: 507, height: 1180)] {
            #expect(GameLayout.best(for: narrow) == .phone, "\(narrow)")
            func pointsPerUnit(_ layout: GameLayout) -> CGFloat {
                min(narrow.width / layout.sceneSize.width, narrow.height / layout.sceneSize.height)
            }
            // The game is drawn larger, not just placed differently.
            #expect(pointsPerUnit(.phone) > pointsPerUnit(.pad) * 1.3, "\(narrow)")
        }
        for size in Self.sizes {
            let chosen = GameLayout.best(for: size)
            for layout in GameLayout.allCases {
                #expect(chosen.coverage(of: size) + 0.011 >= layout.coverage(of: size), "\(size)")
            }
        }
        // No size yet (before layout): keep the device's usual layout.
        #expect(GameLayout.best(for: .zero) == GameLayout.deviceDefault)
    }

    @Test func helicopterCeilingAndFloorStayVisibleAtEveryWindowSize() throws {
        for archive in ["GameScene", "GameScene iPad"] {
            for size in Self.sizes {
                let view = SKView(frame: CGRect(origin: .zero, size: size))
                let game = try #require(GameScene(fileNamed: archive))
                game.scaleMode = RootViewController.scaleMode(for: game, in: size)
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
