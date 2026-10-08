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

/// One menu choice. The scene owns it, so switch scanning works whether or not a view
/// shows the menu; the UIKit button only mirrors its focus and forwards taps.
final class GameMenuItem: FocusScannable {
    let action: MenuAction
    /// The menu this item belongs to; activations from any other phase are ignored.
    let phase: GamePhase
    private weak var scene: GameScene?
    /// Set by the button currently showing this item.
    var onFocusChange: ((Bool) -> Void)?

    init(_ action: MenuAction, phase: GamePhase, scene: GameScene) {
        self.action = action
        self.phase = phase
        self.scene = scene
    }

    var isFocused = false {
        didSet { onFocusChange?(isFocused) }
    }

    var accessibilityScanLabel: String { action.title }

    func scannerActivate() {
        scene?.perform(action, from: phase)
    }
}

/// The Pause and Round Over menus, built in Swift. Text, scores, and choices come from
/// the scene when the menu is built; focus follows the scene's items without polling.
final class GameMenuView: UIView {
    let titleLabel = UILabel()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private(set) var buttons: [GameMenuButton] = []

    /// Called after a choice is acted on, so the host can update without waiting.
    var onAction: (() -> Void)?

    init(game: GameScene, phase: GamePhase, traits: UITraitCollection) {
        super.init(frame: .zero)
        let theme = GameSettings.shared.selectedTheme

        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        addSubview(scroll)
        scroll.addSubview(stack)
        // Centred when the menu fits; scrolls from the top when it doesn't.
        let hug = stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor)
        hug.priority = .defaultLow
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            scroll.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
            stack.centerYAnchor.constraint(equalTo: scroll.contentLayoutGuide.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: scroll.contentLayoutGuide.bottomAnchor),
            hug
        ])

        func addLabel(_ text: String, style: UIFont.TextStyle, into label: UILabel = UILabel()) {
            label.text = text
            label.font = .preferredFont(forTextStyle: style, compatibleWith: traits)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = theme.titleTextColor
            stack.addArrangedSubview(label)
        }

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
        titleLabel.accessibilityTraits = .header

        for item in game.menuItems {
            let button = GameMenuButton(item: item, theme: theme, traits: traits)
            button.addTarget(self, action: #selector(activate(_:)), for: .touchUpInside)
            button.onFocus = { [weak self, weak button] in
                guard let self = self, let button = button else { return }
                self.layoutIfNeeded()
                self.scroll.scrollRectToVisible(button.convert(button.bounds.insetBy(dx: -6, dy: -6), to: self.scroll), animated: false)
            }
            stack.addArrangedSubview(button)
            buttons.append(button)
        }
        accessibilityElements = [scroll]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func activate(_ button: GameMenuButton) {
        button.item.scannerActivate()
        onAction?()
    }
}

/// A menu button that shows its item's scanner focus as a border.
final class GameMenuButton: DynamicTextButton {
    let item: GameMenuItem
    var onFocus: (() -> Void)?

    init(item: GameMenuItem, theme: UITheme, traits: UITraitCollection) {
        self.item = item
        super.init(frame: .zero)
        setTitle(item.action.title, for: .normal)
        accessibilityHint = item.action.hint
        titleLabel?.font = .preferredFont(forTextStyle: .headline, compatibleWith: traits)
        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.numberOfLines = 0
        titleLabel?.textAlignment = .center
        setTitleColor(theme.buttonTextColor, for: .normal)
        backgroundColor = theme.buttonTintColor
        contentEdgeInsets = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        layer.cornerRadius = 12
        layer.borderColor = theme.titleTextColor.cgColor
        heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        // The newest button showing an item takes over its focus updates.
        item.onFocusChange = { [weak self] focused in self?.showFocus(focused) }
        layer.borderWidth = item.isFocused ? 4 : 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func showFocus(_ focused: Bool) {
        layer.borderWidth = focused ? 4 : 0
        if focused { onFocus?() }
    }
}
