import Testing
import SpriteKit
import GameplayKit
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
        // A short, wide window gets the wide layout, made to its own shape.
        #expect(GameLayout.best(for: CGSize(width: 1000, height: 420)) == .wide)
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
        let pages: [SettingsPage] = [.menu] + SettingsCategory.allCases.map { .category($0) }
        for size in Self.sizes { for page in pages {
            let screen = SettingsViewController(page: page)
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
        } }
    }

    /// A phone in landscape (2026-11-17): the app turns with it, and play fills the
    /// screen with a wide scene instead of a narrow strip between bars.
    @Test func landscapePhoneGetsAWideSceneThatFillsTheScreen() throws {
        #expect(RootViewController().supportedInterfaceOrientations == .allButUpsideDown)
        let phones = [CGSize(width: 874, height: 402), CGSize(width: 667, height: 375), CGSize(width: 956, height: 440)]
        for window in phones {
            #expect(GameLayout.best(for: window) == .wide, "\(window)")
            let inset = UIEdgeInsets(top: 0, left: 62, bottom: 21, right: 62)
            let game = try #require(GameLayout.wide.makeScene(for: window, safeArea: inset))
            // The window's own shape, so nothing is cut off and there are no bars.
            #expect(game.size.height == GameLayout.wideHeight)
            #expect(abs(game.size.width / game.size.height - window.width / window.height) < 0.01, "\(window)")
            #expect(GameLayout(sceneSize: game.size) == .wide)
            // As large on screen as in portrait on the same phone.
            #expect(abs(window.height / game.size.height - window.height / GameLayout.phone.sceneSize.width) < 0.001)
            // The helicopter starts clear of the camera housing, with the ceiling and floor in the scene.
            let player = try #require(game.sceneAdapter?.playerCharacter)
            let pointsPerUnit = window.height / game.size.height
            #expect((player.position.x - player.size.width / 2) * pointsPerUnit >= inset.left, "\(window)")
            #expect(player.position.y == game.size.height / 2)
            #expect(game.physicsBody != nil)
            // Pipes fit the shorter scene, with a gap the helicopter can pass.
            let parts = try #require(PipeFactory.standardPipeParts(for: game.size))
            #expect(parts.threshold.size.height >= player.size.height)
            #expect(parts.top.size.height + parts.bottom.size.height + parts.threshold.size.height <= game.size.height + 1)
        }
        // The size override is used once, not left for the next scene.
        #expect(GameScene.pendingShape == nil)
        #expect(try #require(GameLayout.phone.makeScene()).size == GameLayout.phone.sceneSize)
        // A full-screen iPad in landscape keeps its own scene, as before.
        #expect(GameLayout.best(for: CGSize(width: 1180, height: 820)) == .pad)
        #expect(GameLayout.best(for: CGSize(width: 1366, height: 1024)) == .pad)
    }

    /// Pipes move at their portrait speed in a wide scene; they only have further to go.
    @Test func pipesKeepTheirPortraitSpeedInAWideScene() {
        let portrait = GameLayout.phone.sceneSize
        let wide = CGSize(width: 1630, height: 750)
        #expect(PipeFactory.crossingDuration(7, sceneSize: portrait) == 7)
        #expect(PipeFactory.crossingDuration(7, sceneSize: GameLayout.pad.sceneSize) == 7)
        let speed = { (size: CGSize) in Double(size.width + PipeFactory.pipeWidth) / PipeFactory.crossingDuration(7, sceneSize: size) }
        #expect(abs(speed(wide) - speed(portrait)) < 0.001)
    }

    /// A short screen has no room for Home's mascot; without it every choice fits.
    @Test func homeFitsAPhoneInLandscape() {
        let home = HomeViewController()
        home.view.frame = CGRect(x: 0, y: 0, width: 874, height: 402)
        home.view.layoutIfNeeded()
        #expect(home.mascot.isHidden)
        #expect(!home.menu.scroll.overflowsVertically)
        #expect(home.menu.buttons.count == 4)
        home.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        home.view.layoutIfNeeded()
        #expect(!home.mascot.isHidden)
    }

    /// On a phone on its side, at the largest text size: the HUD is one row, the hint
    /// stays below the waiting helicopter, and Up stays clear of Pause.
    @Test func landscapeHUDFitsAtTheLargestTextSize() throws {
        let gs = GameSettings.shared
        let saved = (gs.controlScheme, gs.showScore)
        defer { (gs.controlScheme, gs.showScore) = saved }
        gs.controlScheme = .autoHover
        gs.showScore = true
        let size = CGSize(width: 874, height: 402)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = makeTestWindow(frame: view.frame)
        let host = UIViewController()
        host.view = view
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        let game = try #require(GameLayout.wide.makeScene(for: size))
        view.presentScene(game)
        defer { view.presentScene(nil) }
        let overlay = SceneTextOverlay(frame: view.bounds)
        view.addSubview(overlay)
        overlay.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        overlay.updateTraitsIfNeeded()
        overlay.refresh(in: view)
        overlay.layoutIfNeeded()
        let pause = try #require(overlay.pauseButton)
        let pauseFrame = pause.convert(pause.bounds, to: overlay)
        let hint = try #require(overlay.flightHintLabel)
        let hintFrame = hint.convert(hint.bounds, to: overlay)
        // The helicopter waits at mid-height, half a scene unit of 100 either side.
        let helicopterBottom = size.height / 2 + 50 * size.height / game.size.height
        #expect(hintFrame.minY > helicopterBottom)
        #expect(hint.font.pointSize <= SceneTextOverlay.wideHintPointSize)
        #expect(overlay.upDownLabels.count == 2)
        // The test window keeps a portrait phone's top inset; a phone on its side has none.
        let inset = overlay.safeAreaInsets.top
        for label in overlay.upDownLabels {
            #expect(!label.convert(label.bounds, to: overlay).intersects(pauseFrame.offsetBy(dx: 0, dy: -inset)),
                    "\(label.convert(label.bounds, to: overlay)) \(pauseFrame) inset \(inset) font \(label.font.pointSize)")
        }
        // One row: Pause is level with the chips, at the trailing edge.
        let chip = try #require(overlay.scoreChip)
        #expect(pauseFrame.minX > size.width / 2)
        #expect(abs(chip.convert(chip.bounds, to: overlay).minY - pauseFrame.minY) < 1)
    }

    /// Pause and Round Over show their choices side by side on a short screen, so the
    /// whole menu fits; at accessibility text sizes they stay a column and scroll.
    @Test func gameMenusFitAPhoneInLandscape() throws {
        let game = try #require(GameLayout.wide.makeScene(for: CGSize(width: 874, height: 402)))
        _ = game.stateMachine.enter(GameOverState.self)
        let menu = GameMenuView(game: game, phase: .roundOver, traits: UITraitCollection(preferredContentSizeCategory: .large))
        menu.frame = CGRect(x: 0, y: 0, width: 874, height: 402)
        menu.layoutIfNeeded()
        #expect(menu.choices.axis == .horizontal)
        #expect(menu.buttons.map(\.currentTitle) == ["Home", "Try Again"])
        #expect(Set(menu.buttons.map { $0.frame.minY }).count == 1)
        menu.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        menu.layoutIfNeeded()
        #expect(menu.choices.axis == .vertical)
    }
}
