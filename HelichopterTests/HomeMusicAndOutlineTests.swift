import Testing
import UIKit
import SpriteKit
@testable import Helichopter

/// The owner's three requests of 2026-11-24: the outline on Parchment is a ring, not a
/// black disc; Home opens quickly; and music can be turned off on Home and in the guide.
@MainActor struct HomeMusicAndOutlineTests {

    private func withMusic(_ on: Bool, _ body: () throws -> Void) rethrows {
        let saved = UserDefaults.standard.object(forKey: "isMusicOn")
        defer {
            if let saved = saved { UserDefaults.standard.set(saved, forKey: "isMusicOn") }
            else { UserDefaults.standard.removeObject(forKey: "isMusicOn") }
        }
        MusicChoice.isOn = on
        try body()
    }

    private func outlineBands(theme: String) throws -> [SKShapeNode] {
        let gs = GameSettings.shared
        let saved = (gs.selectedThemeID, gs.helicopterOutline)
        defer { (gs.selectedThemeID, gs.helicopterOutline) = saved }
        gs.selectedThemeID = theme
        gs.helicopterOutline = true
        let node = HelicopterNode(animationTimeInterval: 1.0 / 60, skin: gs.selectedHelicopterSkin,
                                  size: CGSize(width: 100, height: 100))
        let boundary = try #require(node.childNode(withName: "flightBoundary"))
        #expect(!boundary.isHidden)
        return boundary.children.compactMap { $0 as? SKShapeNode }
    }

    @Test func parchmentOutlineIsARingOnly() throws {
        let bands = try outlineBands(theme: "parchment")
        #expect(bands.count == 2)
        #expect(bands.allSatisfy { $0.fillColor.cgColor.alpha == 0 }, "Parchment must show the ring, not a black disc")
        #expect(bands.allSatisfy { $0.strokeColor.cgColor.alpha == 1 && $0.lineWidth > 0 })
    }

    @Test func darkThemesKeepTheirFilledOutline() throws {
        for theme in ["nightSky", "neonNight"] {
            let bands = try outlineBands(theme: theme)
            #expect(bands.allSatisfy { band in
                var white: CGFloat = 1, alpha: CGFloat = 0
                band.fillColor.getWhite(&white, alpha: &alpha)
                return white == 0 && alpha == 1
            }, "\(theme)")
        }
    }

    /// The mascot's 60 frames used to come from SpriteKit textures, about 80 ms each, so
    /// Home took about a second to open on a phone and five in the test simulator.
    @Test func homeOpensQuickly() {
        let window = makeTestWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        // The first Home warms the asset catalog's cache, as launch does in the app.
        window.rootViewController = HomeViewController()
        window.rootViewController?.view.layoutIfNeeded()
        let start = CFAbsoluteTimeGetCurrent()
        let home = HomeViewController()
        window.rootViewController = home
        home.view.layoutIfNeeded()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        #expect(elapsed < 0.5, "Home took \(Int(elapsed * 1000)) ms to build")
        #expect(home.mascot.animationImages?.count == Cosmetic.helicopterFrameCount)
    }

    /// The faster frames are the same pictures at the same size as the SpriteKit ones.
    @Test func mascotFramesMatchTheGameTextures() throws {
        for skin in [CosmeticsCatalog.classicHelicopter, GameSettings.shared.selectedHelicopterSkin] {
            for index in [1, 30, 60] {
                let fast = skin.helicopterImage(frame: index)
                let texture = SKTextureAtlas(named: skin.assetName).textureNamed(skin.helicopterFrameName(index)).cgImage()
                #expect(fast.size == CGSize(width: texture.width, height: texture.height), "\(skin.id) \(index)")
                #expect(fast.scale == 1)
            }
        }
    }

    @Test func homeHasAMusicButtonLast() throws {
        try withMusic(true) {
            let home = HomeViewController()
            var applied = 0
            home.applyMusicSetting = { applied += 1 }
            home.loadViewIfNeeded()
            let button = try #require(home.menu.buttons.last)
            #expect(button.kind == .quiet)
            #expect(button.currentTitle == "Music On")
            #expect(button.accessibilityUserInputLabels == ["Music On", "Music"])
            #expect(button.accessibilityHint == "Turns the music off")
            // Scanned after the four Home choices, which keep their order.
            #expect(home.scanner.items.count == HomeAction.allCases.count + 1)
            #expect(home.scanner.items.last === button.item)

            button.item.scannerActivate()
            #expect(!MusicChoice.isOn && applied == 1)
            #expect(button.currentTitle == "Music Off" && button.accessibilityHint == "Turns the music on")
            #expect(button.accessibilityUserInputLabels == ["Music Off", "Music"])
            #expect(button.item.accessibilityScanLabel == "Music Off")
            button.item.scannerActivate()
            #expect(MusicChoice.isOn && applied == 2 && button.currentTitle == "Music On")
        }
    }

    @Test func everyGuideStepHasAMusicButton() throws {
        let suite = "HomeMusicAndOutlineTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try withMusic(false) {
            let guide = GuideViewController(defaults: defaults)
            var applied = 0
            guide.applyMusicSetting = { applied += 1 }
            guide.loadViewIfNeeded()
            for page in 0..<GuideViewController.pages().count {
                guide.show(page: page)
                // Third, after Next, in the column and in scan order.
                let button = guide.menu.buttons[2]
                #expect(guide.menu.buttons[1].kind == .primary)
                #expect(button.item is MusicChoice && button.kind == .secondary, "step \(page + 1)")
                #expect(guide.scanner.items[2] === button.item)
                #expect(guide.scanner.items.count == guide.menu.buttons.count)
            }
            let button = guide.menu.buttons[2]
            #expect(button.currentTitle == "Music Off")
            button.item.scannerActivate()
            #expect(MusicChoice.isOn && applied == 1 && button.currentTitle == "Music On")
        }
    }

    /// The root controller's player follows the setting the button changes.
    @Test func menuMusicFollowsTheSetting() {
        withMusic(true) {
            let music = MenuMusic()
            music.play()
            #expect(music.isPlaying)
            MusicChoice.isOn = false
            music.play()
            #expect(!music.isPlaying)
            MusicChoice.isOn = true
            music.play()
            #expect(music.isPlaying)
            music.stop()
            #expect(!music.isPlaying)
        }
    }
}
