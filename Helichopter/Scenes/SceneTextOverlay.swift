import UIKit
import SpriteKit

/// The gameplay HUD and the host for the Pause and Round Over menus. UIKit owns visible
/// text in points, independent of the archived scene's scale; it changes only on
/// screen changes and `GameSceneHUDDelegate` calls, never on a timer.
final class SceneTextOverlay: UIView {
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    /// The scene this overlay was last built for; must match `SKView.scene` after a refresh.
    private(set) weak var hostScene: SKScene?
    /// True while Pause or Round Over fills the overlay.
    private var menu = false
    /// The game phase the overlay was built for; Pause and Round Over replace the HUD.
    private var builtPhase: GamePhase?
    /// The Pause or Round Over menu, while one is showing.
    private(set) var gameMenu: GameMenuView?
    private var scoreLabel: UILabel?
    private var bestScoreLabel: UILabel?
    private var newHighScoreLabel: UILabel?
    private var flightHintLabel: UILabel?
    private weak var hudStack: UIStackView?
    private var flightElement: FlightAccessibilityElement?
    // Stack constraints survive removing the scroll view, so track them per rebuild.
    private var layoutConstraints: [NSLayoutConstraint] = []

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        hudStack?.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return !menu && (hit === self || hit === scroll || hit === stack || hit is UIStackView || hit is UILabel) ? nil : hit
    }

    /// Shows the HUD or game menu for the view's scene; hidden for any other screen.
    /// Rebuilds only when the scene or game phase has changed.
    func refresh(in view: SKView) {
        guard let game = view.scene as? GameScene else {
            // Nothing from a departed game may linger behind Home, the guide, or Settings.
            if hostScene is GameScene || gameMenu != nil || !subviews.isEmpty { clear() }
            isHidden = true
            hostScene = view.scene
            return
        }
        isHidden = false
        guard hostScene !== game || builtPhase != game.phase else { return }
        hostScene = game
        builtPhase = game.phase
        menu = game.phase != .playing
        rebuild(game: game)
    }

    private func clear() {
        subviews.forEach { $0.removeFromSuperview() }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        scoreLabel = nil
        bestScoreLabel = nil
        newHighScoreLabel = nil
        flightHintLabel = nil
        gameMenu = nil
        flightElement = nil
        builtPhase = nil
        accessibilityElements = nil
        accessibilityViewIsModal = false
    }

    private func rebuild(game: GameScene) {
        clear()
        builtPhase = game.phase
        let theme = GameSettings.shared.selectedTheme
        let isPaused = game.stateMachine.currentState is PausedState
        backgroundColor = isPaused
            ? (GameSettings.shared.hideGameWhilePaused ? theme.sceneBackgroundColor : UIColor.black.withAlphaComponent(0.25))
            : (menu ? theme.sceneBackgroundColor : .clear)
        // The archive supplies actions and text only; never draw a second HUD.
        // Scenes also suppress at load, so this only covers late additions.
        game.suppressArchivedPresentation()
        game.hudDelegate = self
        if menu {
            buildGameMenu(for: game)
            return
        }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        scroll.isUserInteractionEnabled = false
        addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.deactivate(layoutConstraints)
        // The gameplay HUD stays pinned to the top, clear of the flight area.
        layoutConstraints = [
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor)
        ]
        NSLayoutConstraint.activate(layoutConstraints)
        var textNodes: [SKLabelNode] = []
        game.enumerateChildNodes(withName: "//*") { node, _ in
            guard let label = node as? SKLabelNode else { return }
            var parent = label.parent
            while let item = parent, item !== game {
                if item is ButtonNode { return }
                parent = item.parent
            }
            textNodes.append(label)
        }
        textNodes.sort { $0.convert(.zero, to: game).y > $1.convert(.zero, to: game).y }
        // Controls precede the hint so its fade cannot move or cover Pause.
        let hud = UIStackView()
        hud.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        hudStack = hud
        hud.spacing = 12
        hud.alignment = .fill
        stack.addArrangedSubview(hud)
        func hudLabel(style: UIFont.TextStyle = .body) -> UILabel {
            let label = UILabel()
            label.font = .preferredFont(forTextStyle: style, compatibleWith: traitCollection)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = theme.titleTextColor
            label.backgroundColor = theme.sceneBackgroundColor
            label.isUserInteractionEnabled = false
            return label
        }
        for node in textNodes {
            // Keep archived hint alpha/actions and score updates as the source of truth.
            node.fontColor = .clear
            let label = hudLabel()
            if node.name == GameScene.flightHintName { flightHintLabel = label }
            if node.name == "Score Label" {
                scoreLabel = label
                hud.addArrangedSubview(label)
                let best = hudLabel()
                hud.addArrangedSubview(best)
                bestScoreLabel = best
            } else {
                stack.addArrangedSubview(label)
            }
        }
        // Static text; no animation, sound, or input capture, so flight is never interrupted.
        let banner = hudLabel(style: .title2)
        banner.text = "New high score!"
        banner.isHidden = true
        stack.addArrangedSubview(banner)
        newHighScoreLabel = banner
        for node in game.findAllButtonsInScene() {
            let button = SceneTextButton(node: node)
            button.titleLabel?.font = .preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
            button.setTitle(node.accessibilityScanLabel, for: .normal)
            button.accessibilityHint = node.accessibilityScanHint
            button.setTitleColor(theme.buttonTextColor, for: .normal)
            button.backgroundColor = theme.buttonTintColor
            button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
            button.layer.cornerRadius = 12
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            // hitTest lets touches outside this control reach the flight surface.
            scroll.isUserInteractionEnabled = true
            hud.addArrangedSubview(button)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        let element = FlightAccessibilityElement(accessibilityContainer: self)
        element.game = game
        element.host = self
        element.accessibilityLabel = "Helicopter flight control"
        element.accessibilityTraits = .button
        element.accessibilityHint = game.accessibilityFlightHint
        var actions: [UIAccessibilityCustomAction] = []
        if GameSettings.shared.controlScheme != .tapFlap {
            actions.append(UIAccessibilityCustomAction(name: "Move down", target: element, selector: #selector(FlightAccessibilityElement.moveDown)))
        }
        actions.append(UIAccessibilityCustomAction(name: "Pause", target: element, selector: #selector(FlightAccessibilityElement.pause)))
        element.accessibilityCustomActions = actions
        flightElement = element
        accessibilityElements = [element, scroll]
        showCurrentHUD(of: game)
        accessibilityViewIsModal = false
        ScreenChangeAnnouncer.post(element)
    }

    /// Pause and Round Over are built in Swift and fill the overlay.
    private func buildGameMenu(for game: GameScene) {
        let menuView = GameMenuView(game: game, phase: game.phase, traits: traitCollection)
        menuView.frame = bounds
        menuView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Update at once, so a second tap cannot reach a menu that has closed.
        menuView.onAction = { [weak self] in
            guard let self = self, let view = self.superview as? SKView else { return }
            self.refresh(in: view)
        }
        addSubview(menuView)
        gameMenu = menuView
        accessibilityElements = [menuView]
        accessibilityViewIsModal = true
        ScreenChangeAnnouncer.post(menuView.titleLabel)
    }

    /// Fills a freshly built HUD from the scene once; after that only delegate calls change it.
    private func showCurrentHUD(of game: GameScene) {
        guard let adapter = game.sceneAdapter else { return }
        scoreDidChange(adapter.score)
        bestScoreDidChange(adapter.bestScore)
        newHighScoreDidChange(adapter.isShowingNewHighScore)
        flightHintLabel?.text = game.flightHintText ?? game.flightHint?.text
        flightHintLabel?.alpha = game.flightHintText == nil ? 0 : 1
    }
}

extension SceneTextOverlay: GameSceneHUDDelegate {
    func scoreDidChange(_ score: Int) {
        scoreLabel?.text = "Score \(score)"
        scoreLabel?.isHidden = !GameSettings.shared.showScore
    }

    func bestScoreDidChange(_ best: Int) {
        bestScoreLabel?.text = "Best \(best)"
        bestScoreLabel?.isHidden = !GameSettings.shared.showScore
    }

    func newHighScoreDidChange(_ isShowing: Bool) {
        newHighScoreLabel?.isHidden = !isShowing
    }

    func flightHintDidChange(_ text: String?) {
        guard let label = flightHintLabel else { return }
        label.layer.removeAllAnimations()
        if let text = text {
            label.text = text
            label.alpha = 1
        } else {
            UIView.animate(withDuration: 0.5) { label.alpha = 0 }
        }
    }

    /// Pause and Round Over replace the HUD at once, without waiting for any timer.
    func stateDidChange(_ phase: GamePhase) {
        guard let view = superview as? SKView, let scene = hostScene, view.scene === scene else { return }
        refresh(in: view)
    }
}

private final class SceneTextButton: DynamicTextButton {
    private weak var node: ButtonNode?
    init(node: ButtonNode) {
        self.node = node
        super.init(frame: .zero)
        addTarget(self, action: #selector(activate), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func activate() {
        node?.scannerActivate()
        // Rebuild now, so a second tap cannot reach a control whose screen has changed.
        if let overlay = superview(of: SceneTextOverlay.self), let view = overlay.superview as? SKView {
            overlay.refresh(in: view)
        }
    }
}

private extension UIView {
    func superview<T: UIView>(of type: T.Type) -> T? {
        superview.flatMap { $0 as? T ?? $0.superview(of: type) }
    }
}

extension SKNode {
    /// UIKit draws visible menus and HUD text; archived buttons and labels remain
    /// invisible action/text models. Scenes call this when loaded and after theming,
    /// so no frame ever shows both the archived and UIKit versions.
    func suppressArchivedPresentation() {
        for child in children {
            if let button = child as? ButtonNode { button.isPresentedInUIKit = true }
            if let label = child as? SKLabelNode { label.fontColor = .clear }
            child.suppressArchivedPresentation()
        }
    }
}

/// UIButton's default intrinsic height does not account for wrapped titles.
class DynamicTextButton: UIButton {
    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        guard let label = titleLabel, bounds.width > 0 else { return base }
        let width = max(1, bounds.width - contentEdgeInsets.left - contentEdgeInsets.right)
        let height = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: base.width, height: max(44, height + contentEdgeInsets.top + contentEdgeInsets.bottom))
    }
    private var previousWidth: CGFloat = 0
    override func layoutSubviews() {
        super.layoutSubviews()
        if previousWidth != bounds.width {
            previousWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }
}

/// A stable proxy on the actual UIKit overlay, independent of SpriteKit hit testing.
final class FlightAccessibilityElement: UIAccessibilityElement {
    weak var game: GameScene?
    weak var host: UIView?
    override var accessibilityValue: String? {
        get { game?.accessibilityFlightStatus }
        set { }
    }
    override var accessibilityFrame: CGRect {
        get {
            guard let host = host else { return .zero }
            let rect = CGRect(x: 0, y: host.bounds.height * 0.5,
                              width: host.bounds.width, height: host.bounds.height * 0.5)
            return UIAccessibility.convertToScreenCoordinates(rect, in: host)
        }
        set { }
    }
    override func accessibilityActivate() -> Bool { game?.accessibilityFly() ?? false }
    @objc func moveDown() -> Bool { game?.accessibilityFly(down: true) ?? false }
    @objc func pause() -> Bool {
        guard let game = game, game.stateMachine.currentState is PlayingState else { return false }
        game.pauseForInterruption()
        return true
    }
    override func accessibilityPerformEscape() -> Bool { pause() }
}
