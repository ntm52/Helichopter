import Testing
import SpriteKit
import GameplayKit
import UIKit
@testable import Helichopter

/// Plan 01 Stage B step 1: the gameplay HUD changes only when `GameScene` reports a
/// change. These tests build the HUD once and never call `refresh` or run a timer.
@MainActor @Suite("Event-driven HUD", .serialized)
struct HUDEventTests {

    private final class Spy: GameSceneHUDDelegate {
        var events: [String] = []
        func scoreDidChange(_ score: Int) { events.append("score \(score)") }
        func bestScoreDidChange(_ best: Int) { events.append("best \(best)") }
        func stateDidChange(_ phase: GamePhase) { events.append("state \(phase)") }
        func flightHintDidChange(_ text: String?) { events.append(text == nil ? "hint hidden" : "hint shown") }
        func newHighScoreDidChange(_ isShowing: Bool) { events.append("celebrate \(isShowing)") }
    }

    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    /// Saves the defaults these tests change and puts them back afterwards.
    private func withDefaults(_ work: @MainActor () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let savedBest = defaults.object(forKey: "bestScore")
        let savedMusic = defaults.object(forKey: "isMusicOn")
        let savedShow = GameSettings.shared.showScore
        let savedScanning = GameSettings.shared.scanningEnabled
        defer {
            if let savedBest = savedBest { defaults.set(savedBest, forKey: "bestScore") } else { defaults.removeObject(forKey: "bestScore") }
            if let savedMusic = savedMusic { defaults.set(savedMusic, forKey: "isMusicOn") } else { defaults.removeObject(forKey: "isMusicOn") }
            GameSettings.shared.showScore = savedShow
            GameSettings.shared.scanningEnabled = savedScanning
        }
        defaults.set(false, for: .isMusicOn)
        GameSettings.shared.showScore = true
        GameSettings.shared.scanningEnabled = false
        try await work()
    }

    @Test func sceneReportsEveryHUDChange() async throws {
        try await withDefaults {
            UserDefaults.standard.set(1, for: .bestScore)
            let game = try #require(GameScene(fileNamed: "GameScene"))
            let adapter = try #require(game.sceneAdapter)
            let heli = try #require(adapter.playerCharacter as? HelicopterNode)
            let spy = Spy()
            game.hudDelegate = spy

            heli.switchPrimaryBegan()
            heli.switchPrimaryEnded()
            #expect(spy.events == ["hint hidden"])

            spy.events = []
            adapter.scorePoint()
            #expect(spy.events == ["score 1"])
            spy.events = []
            adapter.scorePoint()
            #expect(spy.events == ["score 2", "best 2", "celebrate true"])

            spy.events = []
            #expect(game.stateMachine.enter(PausedState.self))
            #expect(game.stateMachine.enter(PlayingState.self))
            #expect(spy.events == ["state paused", "state playing"])

            spy.events = []
            #expect(game.stateMachine.enter(GameOverState.self))
            #expect(spy.events == ["score 0", "state roundOver"])

            // A retry shows the hint again and ends any celebration before play resumes.
            spy.events = []
            #expect(game.stateMachine.enter(PlayingState.self))
            #expect(spy.events == ["celebrate false", "hint shown", "state playing"])
        }
    }

    @Test func celebrationEndsOnItsOwn() async throws {
        try await withDefaults {
            UserDefaults.standard.set(1, for: .bestScore)
            let game = try #require(GameScene(fileNamed: "GameScene"))
            let adapter = try #require(game.sceneAdapter)
            let spy = Spy()
            game.hudDelegate = spy
            adapter.scorePoint()
            adapter.scorePoint()
            #expect(spy.events.last == "celebrate true")
            try await Task.sleep(for: .seconds(GameSceneAdapter.newHighScoreDisplayDuration + 0.3))
            #expect(spy.events.last == "celebrate false")
            #expect(!adapter.isShowingNewHighScore)
        }
    }

    /// The HUD is built once; score, hint, Pause, and Round Over then follow the game
    /// with no refresh call and no timer.
    @Test func hudFollowsGameWithoutRefresh() async throws {
        try await withDefaults {
            UserDefaults.standard.set(0, for: .bestScore)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let game = try #require(GameScene(fileNamed: "GameScene"))
            view.presentScene(game)
            defer { view.presentScene(nil) }
            let overlay = SceneTextOverlay(frame: view.bounds)
            view.addSubview(overlay)
            overlay.refresh(in: view)
            #expect(game.hudDelegate === overlay)

            let adapter = try #require(game.sceneAdapter)
            let heli = try #require(adapter.playerCharacter as? HelicopterNode)
            @MainActor func label(_ text: String) -> UILabel? { descendants(overlay, UILabel.self).first { $0.text == text } }
            @MainActor func button(_ title: String) -> UIButton? { descendants(overlay, UIButton.self).first { $0.currentTitle == title } }

            let hintText = try #require(game.flightHintText)
            let hint = try #require(label(hintText))
            #expect(hint.alpha == 1)
            #expect(label("Score 0")?.isHidden == false)
            heli.switchPrimaryBegan()
            heli.switchPrimaryEnded()
            #expect(hint.alpha == 0)

            adapter.scorePoint()
            adapter.scorePoint()
            #expect(label("Score 2") != nil && label("Best 2") != nil)

            // Interruptions and hold-to-pause have no button tap to trigger a rebuild.
            game.pauseForInterruption()
            #expect(button("Resume") != nil && button("Pause") == nil)
            try #require(button("Resume")).sendActions(for: .touchUpInside)
            #expect(button("Pause") != nil && label("Score 2") != nil)
            #expect(label(hintText)?.alpha == 0)

            #expect(game.stateMachine.enter(GameOverState.self))
            #expect(button("Try Again") != nil && button("Pause") == nil)
            try #require(button("Try Again")).sendActions(for: .touchUpInside)
            #expect(button("Pause") != nil && label("Score 0") != nil && label("Best 2") != nil)
            #expect(label(hintText)?.alpha == 1)
        }
    }
}
