import UIKit

/// What a Pause or Round Over menu choice does.
enum MenuAction: Equatable {
    case resume, retry, home

    var title: String {
        switch self {
        case .resume: return "Resume"
        case .retry: return "Try Again"
        case .home: return "Home"
        }
    }

    var hint: String {
        switch self {
        case .resume: return "Resumes the game"
        case .retry: return "Starts a new game"
        case .home: return "Goes to the main menu"
        }
    }

    /// The SF Symbol shown with the title. Decoration only.
    var symbolName: String {
        switch self {
        case .resume: return "play.fill"
        case .retry: return "arrow.counterclockwise"
        case .home: return "house.fill"
        }
    }

    /// Resume and Try Again carry on playing, so each is its menu's one primary button.
    var buttonKind: ButtonKind { self == .home ? .secondary : .primary }
}

/// One Pause or Round Over choice. The scene owns it, so switch scanning works whether
/// or not a view shows the menu.
final class GameMenuItem: MenuChoice {
    let action: MenuAction
    /// The menu this item belongs to; activations from any other phase are ignored.
    let phase: GamePhase
    private weak var scene: GameScene?
    var onFocusChange: ((Bool) -> Void)?

    init(_ action: MenuAction, phase: GamePhase, scene: GameScene) {
        self.action = action
        self.phase = phase
        self.scene = scene
    }

    var isFocused = false {
        didSet { onFocusChange?(isFocused) }
    }

    var title: String { action.title }
    var hint: String { action.hint }

    func scannerActivate() {
        scene?.perform(action, from: phase)
    }
}

/// The Pause and Round Over menus, built in Swift: a card in the middle of the screen
/// with a title, the round's score on Round Over, and the choices. Text, scores, and
/// choices come from the scene when the menu is built; focus follows the scene's items
/// without polling.
final class GameMenuView: MenuStackView {
    let titleLabel = UILabel()
    /// The round's score, shown large on Round Over.
    private(set) var scoreLabel: UILabel?
    private(set) var bestLabel: UILabel?

    init(game: GameScene, phase: GamePhase, traits: UITraitCollection) {
        super.init(traits: traits, onCard: true)
        switch phase {
        case .paused:
            addLabel("Paused", style: .display, into: titleLabel)
        case .roundOver:
            addLabel(GameSettings.shared.calmMode ? "Well Done!" : "Round Over", style: .display, into: titleLabel)
            if GameSettings.shared.showScore, let adapter = game.sceneAdapter {
                // A small "Score" over the number; VoiceOver reads the number's full name.
                let caption = addLabel("Score", style: .caption)
                caption.textColor = theme.secondaryTextColor
                caption.isAccessibilityElement = false
                stack.setCustomSpacing(0, after: caption)
                let score = addLabel("\(adapter.roundScore)", style: .wordmark)
                score.textColor = theme.accentTextColor
                score.accessibilityLabel = "Current Score: \(adapter.roundScore)"
                scoreLabel = score
                let best = UserDefaults.standard.integer(for: .bestScore)
                bestLabel = addLabel("Best \(best)", style: .body)
                bestLabel?.accessibilityLabel = "Best Score: \(best)"
            }
        case .playing:
            break
        }
        if let last = stack.arrangedSubviews.last { stack.setCustomSpacing(Spacing.xl, after: last) }
        game.menuItems.forEach { addButton(for: $0, kind: $0.action.buttonKind, icon: $0.action.symbolName) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
