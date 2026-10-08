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

/// The Pause and Round Over menus, built in Swift. Text, scores, and choices come from
/// the scene when the menu is built; focus follows the scene's items without polling.
final class GameMenuView: MenuStackView {
    let titleLabel = UILabel()

    init(game: GameScene, phase: GamePhase, traits: UITraitCollection) {
        super.init(traits: traits)
        switch phase {
        case .paused:
            addLabel("Paused", style: .title1, into: titleLabel)
        case .roundOver:
            addLabel(GameSettings.shared.calmMode ? "Well Done!" : "Round Over", style: .title1, into: titleLabel)
            if GameSettings.shared.showScore, let adapter = game.sceneAdapter {
                addLabel("Best Score: \(UserDefaults.standard.integer(for: .bestScore))", style: .body)
                addLabel("Current Score: \(adapter.roundScore)", style: .body)
            }
        case .playing:
            break
        }
        game.menuItems.forEach { addButton(for: $0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
