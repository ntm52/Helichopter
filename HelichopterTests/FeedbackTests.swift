import Testing
import UIKit
@testable import Helichopter

/// Plan 03 Stage 7: pressed states and the choose haptic. Calm Mode silences the haptic;
/// Calm Mode and Reduce Motion replace movement with dimming.
@MainActor @Suite("Feedback", .serialized)
struct FeedbackTests {

    /// Runs `work` with movement and Calm Mode set, counting choose haptics instead of playing them.
    private func with(reduceMotion: Bool, calm: Bool, _ work: (() -> Int) throws -> Void) rethrows {
        let saved = (Feedback.prefersReducedMotion, Feedback.playChoose, GameSettings.shared.calmMode)
        defer { (Feedback.prefersReducedMotion, Feedback.playChoose, GameSettings.shared.calmMode) = saved }
        var plays = 0
        Feedback.prefersReducedMotion = { reduceMotion }
        Feedback.playChoose = { plays += 1 }
        GameSettings.shared.calmMode = calm
        try work { plays }
    }

    private var theme: UITheme { GameSettings.shared.selectedTheme }

    private func isDimmed(_ view: UIView?) -> Bool { abs((view?.alpha ?? 1) - 0.6) < 0.001 }

    @Test func pressedButtonSinksOntoItsEdge() {
        with(reduceMotion: false, calm: false) { _ in
            for kind in [ButtonKind.primary, .secondary] {
                let button = ArcadeButton(kind: kind, theme: theme)
                button.setTitle("Play", for: .normal)
                button.setIcon(systemName: "play.fill")
                button.frame = CGRect(x: 0, y: 0, width: 200, height: 62)
                button.layoutIfNeeded()
                let size = button.bounds.size
                button.isHighlighted = true
                #expect(button.isPressedDown)
                #expect(button.layer.sublayerTransform.m42 == Stroke.press)
                // The title stays at full strength, and the button keeps its size and place.
                #expect(button.titleLabel?.alpha == 1 && button.bounds.size == size)
                #expect(Stroke.press < Stroke.edge)
                button.layoutIfNeeded()
                button.isHighlighted = false
                #expect(!button.isPressedDown && CATransform3DIsIdentity(button.layer.sublayerTransform))
            }
            let card = CardButton(theme: theme)
            card.frame = CGRect(x: 0, y: 0, width: 200, height: 120)
            card.isHighlighted = true
            #expect(card.isPressedDown && card.layer.sublayerTransform.m42 == Stroke.press)
            card.isHighlighted = false
            #expect(!card.isPressedDown && CATransform3DIsIdentity(card.layer.sublayerTransform))
        }
    }

    @Test func pressedButtonOnlyDimsWhenMovementIsOff() {
        for (reduceMotion, calm) in [(true, false), (false, true)] {
            with(reduceMotion: reduceMotion, calm: calm) { _ in
                let button = ArcadeButton(kind: .primary, theme: theme)
                button.setTitle("Play", for: .normal)
                button.isHighlighted = true
                #expect(!button.isPressedDown && CATransform3DIsIdentity(button.layer.sublayerTransform))
                #expect(isDimmed(button.titleLabel))
                button.isHighlighted = false
                #expect(button.titleLabel?.alpha == 1)

                let card = CardButton(theme: theme)
                let picture = UIView()
                card.addSubview(picture)
                card.isHighlighted = true
                #expect(!card.isPressedDown && isDimmed(picture))
            }
        }
        // A quiet button has no edge to sink onto, so it always dims.
        with(reduceMotion: false, calm: false) { _ in
            let quiet = ArcadeButton(kind: .quiet, theme: theme)
            quiet.setTitle("More about this", for: .normal)
            quiet.isHighlighted = true
            #expect(!quiet.isPressedDown && isDimmed(quiet.titleLabel))
        }
    }

    @Test func everyKindOfChoicePlaysOneHapticExceptInCalmMode() throws {
        for calm in [false, true] {
            try with(reduceMotion: false, calm: calm) { plays in
                let expected = calm ? 0 : 1
                // A Home choice, by tap and by the scanner's route.
                let home = HomeViewController()
                home.navigate = { _ in }
                home.loadViewIfNeeded()
                var before = plays()
                try #require(home.menu.buttons.first).sendActions(for: .touchUpInside)
                #expect(plays() - before == expected)
                before = plays()
                home.items[1].scannerActivate()
                #expect(plays() - before == expected)

                // Settings: Back, a category card, and a switch flipped by the scanner.
                let settings = SettingsViewController()
                settings.navigate = { _ in }
                settings.loadViewIfNeeded()
                for name in ["Back", "Difficulty"] {
                    before = plays()
                    try #require(settings.panel.control(labelled: name)).sendActions(for: .touchUpInside)
                    #expect(plays() - before == expected, "\(name)")
                }
                let comfort = SettingsViewController(page: .category(.comfort))
                comfort.loadViewIfNeeded()
                let toggle = try #require(comfort.panel.control(labelled: "Calm Mode") as? UISwitch)
                before = plays()
                comfort.panel.activate(toggle)
                // The flip itself changes Calm Mode; the haptic is decided before it.
                #expect(plays() - before == expected)
                comfort.panel.activate(toggle)
            }
        }
    }
}
