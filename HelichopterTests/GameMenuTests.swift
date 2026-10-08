import Testing
import SpriteKit
import GameplayKit
import UIKit
@testable import Helichopter

/// Plan 01 Stage B step 2: Pause and Round Over are built in Swift. These tests never
/// call `refresh` after the first build, so nothing may depend on the 50 ms timer.
@MainActor @Suite("Pause and Round Over menus", .serialized)
struct GameMenuTests {

    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    /// Saves the settings these tests change and puts them back afterwards.
    private func withDefaults(_ work: @MainActor () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let savedBest = defaults.object(forKey: "bestScore")
        let savedLast = defaults.object(forKey: "lastScore")
        let savedMusic = defaults.object(forKey: "isMusicOn")
        let gs = GameSettings.shared
        let savedShow = gs.showScore
        let savedCalm = gs.calmMode
        let savedScanning = gs.scanningEnabled
        let savedHide = gs.hideGameWhilePaused
        defer {
            if let savedBest = savedBest { defaults.set(savedBest, forKey: "bestScore") } else { defaults.removeObject(forKey: "bestScore") }
            if let savedLast = savedLast { defaults.set(savedLast, forKey: "lastScore") } else { defaults.removeObject(forKey: "lastScore") }
            if let savedMusic = savedMusic { defaults.set(savedMusic, forKey: "isMusicOn") } else { defaults.removeObject(forKey: "isMusicOn") }
            gs.showScore = savedShow
            gs.calmMode = savedCalm
            gs.scanningEnabled = savedScanning
            gs.hideGameWhilePaused = savedHide
        }
        defaults.set(false, for: .isMusicOn)
        gs.showScore = true
        gs.calmMode = false
        gs.scanningEnabled = false
        gs.hideGameWhilePaused = false
        try work()
    }

    /// A game on screen with its overlay built once.
    private func makeGame(_ archive: String = "GameScene") throws -> (SKView, GameScene, SceneTextOverlay) {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let game = try #require(GameScene(fileNamed: archive))
        view.presentScene(game)
        let overlay = SceneTextOverlay(frame: view.bounds)
        view.addSubview(overlay)
        overlay.refresh(in: view)
        return (view, game, overlay)
    }

    private func texts(_ overlay: UIView) -> [String] {
        descendants(overlay, UILabel.self).filter { !($0.superview is UIButton) }.compactMap(\.text)
    }

    private func titles(_ overlay: UIView) -> [String] {
        descendants(overlay, UIButton.self).compactMap(\.currentTitle)
    }

    @Test func archivedOverlaysAreGone() {
        for name in ["PauseScene", "PauseScene iPad", "FailedScene", "FailedScene iPad"] {
            #expect(Bundle.main.path(forResource: name, ofType: "sks") == nil, "\(name).sks")
        }
    }

    @Test func pauseMenuShowsTitleAndChoicesInFocusOrder() throws {
        try withDefaults {
            for archive in ["GameScene", "GameScene iPad"] {
                let (view, game, overlay) = try makeGame(archive)
                defer { view.presentScene(nil) }
                game.pauseForInterruption()
                let menu = try #require(overlay.gameMenu)
                #expect(texts(menu) == ["Paused"])
                #expect(titles(overlay) == ["Resume", "Home"])
                #expect(game.menuItems.map(\.action) == [.resume, .home])
                #expect(menu.buttons.map { $0.accessibilityHint } == ["Resumes the game", "Goes to the main menu"])
                #expect(menu.titleLabel.accessibilityTraits.contains(.header))
                #expect(overlay.accessibilityViewIsModal)
                // Pause adds nothing to SpriteKit; the HUD's Pause button is hidden.
                #expect(game.findAllButtonsInScene().isEmpty)
                #expect(overlay.backgroundColor?.cgColor.alpha == 0.25)
            }
        }
    }

    @Test func pauseKeepsSolidBackgroundOption() throws {
        try withDefaults {
            GameSettings.shared.hideGameWhilePaused = true
            let (view, game, overlay) = try makeGame()
            defer { view.presentScene(nil) }
            game.pauseForInterruption()
            #expect(overlay.backgroundColor?.cgColor.alpha == 1)
            #expect(overlay.backgroundColor == GameSettings.shared.selectedTheme.sceneBackgroundColor)
        }
    }

    @Test func roundOverShowsScoresAndCalmWording() throws {
        try withDefaults {
            UserDefaults.standard.set(10, for: .bestScore)
            let (view, game, overlay) = try makeGame()
            defer { view.presentScene(nil) }
            let adapter = try #require(game.sceneAdapter)
            adapter.score = 4
            #expect(game.stateMachine.enter(GameOverState.self))
            #expect(adapter.score == 0)
            #expect(texts(overlay) == ["Round Over", "Best Score: 10", "Current Score: 4"])
            #expect(titles(overlay) == ["Home", "Try Again"])
            #expect(game.menuItems.map(\.action) == [.home, .retry])

            // A new record is saved before the menu reads it.
            try #require(overlay.gameMenu?.buttons.last).sendActions(for: .touchUpInside)
            adapter.score = 12
            GameSettings.shared.calmMode = true
            #expect(game.stateMachine.enter(GameOverState.self))
            #expect(texts(overlay) == ["Well Done!", "Best Score: 12", "Current Score: 12"])

            // Hidden scores stay hidden on Round Over too.
            #expect(game.stateMachine.enter(PlayingState.self))
            GameSettings.shared.showScore = false
            #expect(game.stateMachine.enter(GameOverState.self))
            #expect(texts(overlay) == ["Well Done!"])
        }
    }

    /// The switch scanner moves through the same items the buttons show, and the
    /// focus border follows it with no refresh.
    @Test func scannerFocusShowsOnButtonsWithoutRefresh() throws {
        try withDefaults {
            let (view, game, overlay) = try makeGame()
            defer { view.presentScene(nil) }
            game.pauseForInterruption()
            game.setupOverlayScanner(forceStart: true)
            let scanner = try #require(game.overlayScanner)
            let buttons = try #require(overlay.gameMenu?.buttons)
            #expect(scanner.items.count == buttons.count)
            #expect(zip(scanner.items, buttons).allSatisfy { $0 === $1.item })
            #expect(buttons.map { $0.layer.borderWidth } == [4, 0])
            scanner.secondaryAdvance()
            #expect(buttons.map { $0.layer.borderWidth } == [0, 4])
            scanner.secondaryAdvance()
            game.switchPrimaryBegan()
            game.switchPrimaryEnded()
            #expect(game.stateMachine.currentState is PlayingState)
            #expect(overlay.gameMenu == nil)
            #expect(buttons.allSatisfy { $0.layer.borderWidth == 0 })
        }
    }

    /// A choice left over from a closed menu, or from the other menu, does nothing.
    @Test func staleMenuChoicesAreIgnored() throws {
        try withDefaults {
            let (view, game, overlay) = try makeGame()
            defer { view.presentScene(nil) }
            game.pauseForInterruption()
            let resume = try #require(overlay.gameMenu?.buttons.first)
            resume.sendActions(for: .touchUpInside)
            #expect(game.stateMachine.currentState is PlayingState)
            resume.sendActions(for: .touchUpInside)
            #expect(game.stateMachine.currentState is PlayingState)

            #expect(game.stateMachine.enter(GameOverState.self))
            game.perform(.resume, from: .paused)
            #expect(game.stateMachine.currentState is GameOverState)
            #expect(view.scene === game)
        }
    }

    @Test func homeLeavesTheRound() throws {
        try withDefaults {
            let (view, game, overlay) = try makeGame()
            defer { view.presentScene(nil) }
            #expect(game.stateMachine.enter(GameOverState.self))
            try #require(overlay.gameMenu?.buttons.first).sendActions(for: .touchUpInside)
            // A bare view has no Home screen to show; ScreenTransitionTests covers the app.
            #expect(view.scene == nil)
            #expect(overlay.gameMenu == nil)
        }
    }

    @Test func menusFitAtLargestTextSize() throws {
        try withDefaults {
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
            let game = try #require(GameScene(fileNamed: "GameScene"))
            view.presentScene(game)
            defer { view.presentScene(nil) }
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            overlay.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            overlay.updateTraitsIfNeeded()
            overlay.refresh(in: view)
            let menus: [() -> Void] = [{ game.pauseForInterruption() }, { _ = game.stateMachine.enter(GameOverState.self) }]
            for enter in menus {
                enter()
                let menu = try #require(overlay.gameMenu)
                menu.layoutIfNeeded()
                menu.layoutIfNeeded()
                let labels = descendants(menu, UILabel.self)
                #expect(labels.allSatisfy { $0.adjustsFontForContentSizeCategory })
                for label in labels where label.bounds.width > 0 {
                    let required = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    #expect(label.bounds.height + 2 >= required.height)
                }
                for button in menu.buttons {
                    #expect(button.bounds.width <= menu.bounds.width)
                    #expect(button.bounds.height >= 48)
                }
                if game.stateMachine.currentState is PausedState {
                    #expect(game.stateMachine.enter(PlayingState.self))
                }
            }
        }
    }
}
