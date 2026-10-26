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
    /// One flight area, or Up and Down for schemes that split the screen.
    private var flightElements: [FlightAccessibilityElement] = []
    // Stack constraints survive removing the scroll view, so track them per rebuild.
    private var layoutConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (overlay: SceneTextOverlay, _: UITraitCollection) in
            overlay.hudStack?.axis = overlay.traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
        flightElements = []
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
        // Score, best, and Pause share the top row; the hint and banner sit below it,
        // so the hint's fade cannot move or cover Pause.
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
        let score = hudLabel()
        hud.addArrangedSubview(score)
        scoreLabel = score
        let best = hudLabel()
        hud.addArrangedSubview(best)
        bestScoreLabel = best
        let hint = hudLabel()
        stack.addArrangedSubview(hint)
        flightHintLabel = hint
        // Static text; no animation, sound, or input capture, so flight is never interrupted.
        let banner = hudLabel(style: .title2)
        banner.text = "New high score!"
        banner.isHidden = true
        stack.addArrangedSubview(banner)
        newHighScoreLabel = banner
        let pause = DynamicTextButton()
        pause.titleLabel?.font = .preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
        pause.titleLabel?.adjustsFontForContentSizeCategory = true
        pause.titleLabel?.numberOfLines = 0
        pause.titleLabel?.textAlignment = .center
        pause.setTitle("Pause", for: .normal)
        pause.accessibilityHint = "Pauses the game"
        pause.setTitleColor(theme.buttonTextColor, for: .normal)
        pause.backgroundColor = theme.buttonTintColor
        pause.padding = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        pause.layer.cornerRadius = 12
        pause.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        pause.addTarget(self, action: #selector(pauseTapped), for: .touchUpInside)
        // hitTest lets touches outside this control reach the flight surface.
        scroll.isUserInteractionEnabled = true
        hud.addArrangedSubview(pause)
        pause.setContentCompressionResistancePriority(.required, for: .horizontal)
        let scheme = GameSettings.shared.controlScheme
        if scheme.splitsTouchIntoUpAndDown { addUpDownGuide(theme: theme) }
        // Split schemes get Up and Down areas; the others keep one area on the lower half.
        let areas: [FlightAccessibilityElement.Area] = scheme.splitsTouchIntoUpAndDown ? [.up, .down] : [.whole]
        flightElements = areas.map { area in
            let element = FlightAccessibilityElement(accessibilityContainer: self)
            element.game = game
            element.host = self
            element.hud = hud
            element.area = area
            switch area {
            case .whole:
                element.accessibilityLabel = "Helicopter flight control"
                // Voice Control: "Tap Fly" is quicker to say on every flap than the full label.
                element.accessibilityUserInputLabels = ["Fly", "Flap", "Helicopter", "Helicopter flight control"]
            case .up:
                element.accessibilityLabel = "Fly up"
                element.accessibilityUserInputLabels = ["Up", "Fly up", "Fly"]
            case .down:
                element.accessibilityLabel = "Fly down"
                element.accessibilityUserInputLabels = ["Down", "Fly down"]
            }
            element.accessibilityTraits = .button
            if GameSettings.shared.voiceOverDirectTouch {
                // VoiceOver passes touches on the flight area straight through to the scene, so
                // taps and holds fly at once. Silent, so speech never lags behind each flap.
                // Switch Control and Voice Control still activate the element as before.
                element.accessibilityTraits.insert(.allowsDirectInteraction)
                element.accessibilityDirectTouchOptions = .silentOnTouch
            }
            element.accessibilityHint = game.accessibilityFlightHint(down: area == .down)
            element.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "Pause", target: element, selector: #selector(FlightAccessibilityElement.pause))
            ]
            return element
        }
        accessibilityElements = flightElements + [scroll]
        showCurrentHUD(of: game)
        accessibilityViewIsModal = false
        ScreenChangeAnnouncer.post(flightElements.first)
    }

    /// A faint line across the middle with Up and Down beside it, for schemes where the
    /// top half moves up and the bottom half moves down. It never takes a touch.
    private func addUpDownGuide(theme: UITheme) {
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = theme.titleTextColor.withAlphaComponent(0.35)
        line.isUserInteractionEnabled = false
        line.isAccessibilityElement = false
        addSubview(line)
        var constraints = [
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.centerYAnchor.constraint(equalTo: centerYAnchor),
            line.heightAnchor.constraint(equalToConstant: 2)
        ]
        // Beside the right edge, away from the helicopter on the left. The Up and Down
        // areas already speak these words, so VoiceOver skips the labels.
        for (text, above) in [("Up", true), ("Down", false)] {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = text
            label.font = .preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = theme.titleTextColor
            label.backgroundColor = theme.sceneBackgroundColor
            label.isUserInteractionEnabled = false
            label.isAccessibilityElement = false
            addSubview(label)
            constraints += [
                label.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
                above ? label.bottomAnchor.constraint(equalTo: line.topAnchor, constant: -6)
                      : label.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 6)
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }

    @objc private func pauseTapped() {
        guard let view = superview as? SKView, let game = view.scene as? GameScene else { return }
        game.pauseFromHUD()
        // Rebuild now, so a second tap cannot reach a control whose screen has changed.
        refresh(in: view)
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
        // Once faded, the hint keeps its wording so the HUD's layout does not shift.
        flightHintLabel?.text = game.flightHintText
            ?? GameScene.flightHintText(for: GameSettings.shared.controlScheme, voiceOver: UIAccessibility.isVoiceOverRunning)
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

/// UIButton's default intrinsic height does not account for wrapped titles.
class DynamicTextButton: UIButton {
    /// Space around the title. Replaces the deprecated `contentEdgeInsets` without
    /// moving to `UIButton.Configuration`, which would change fonts and colours.
    var padding: UIEdgeInsets = .zero {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        let paddedWidth = base.width + padding.left + padding.right
        guard let label = titleLabel, bounds.width > 0 else {
            return CGSize(width: paddedWidth, height: base.height + padding.top + padding.bottom)
        }
        let width = max(1, bounds.width - padding.left - padding.right)
        let height = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: paddedWidth, height: max(44, height + padding.top + padding.bottom))
    }
    private var previousWidth: CGFloat = 0
    override func layoutSubviews() {
        super.layoutSubviews()
        // Place the title as UIButton placed it inside contentEdgeInsets: whole-point size,
        // centred, origin on the nearest device pixel.
        if let label = titleLabel, padding != .zero {
            let area = bounds.inset(by: padding)
            let fit = label.sizeThatFits(CGSize(width: area.width, height: .greatestFiniteMagnitude))
            let size = CGSize(width: min(fit.width, area.width).rounded(.up), height: fit.height.rounded(.up))
            let scale = max(1, traitCollection.displayScale)
            func pixel(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
            label.frame = CGRect(x: pixel(area.midX - size.width / 2), y: pixel(area.midY - size.height / 2),
                                 width: size.width, height: size.height)
        }
        if previousWidth != bounds.width {
            previousWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }
}

/// A stable proxy on the actual UIKit overlay, independent of SpriteKit hit testing.
final class FlightAccessibilityElement: UIAccessibilityElement {
    /// `whole` is the lower half; `up` runs from below the HUD row to the middle, so the
    /// Pause button stays outside it, and `down` is the lower half.
    enum Area { case whole, up, down }

    weak var game: GameScene?
    weak var host: UIView?
    weak var hud: UIView?
    var area: Area = .whole
    override var accessibilityValue: String? {
        get { game?.accessibilityFlightStatus }
        set { }
    }
    override var accessibilityFrame: CGRect {
        get {
            guard let host = host else { return .zero }
            let middle = host.bounds.height * 0.5
            let rect: CGRect
            if area == .up {
                let top = hud.map { min($0.convert($0.bounds, to: host).maxY, middle) } ?? 0
                rect = CGRect(x: 0, y: top, width: host.bounds.width, height: middle - top)
            } else {
                rect = CGRect(x: 0, y: middle, width: host.bounds.width, height: host.bounds.height - middle)
            }
            return UIAccessibility.convertToScreenCoordinates(rect, in: host)
        }
        set { }
    }
    override func accessibilityActivate() -> Bool { game?.accessibilityFly(down: area == .down) ?? false }
    @objc func pause() -> Bool {
        guard let game = game, game.stateMachine.currentState is PlayingState else { return false }
        game.pauseForInterruption()
        return true
    }
    override func accessibilityPerformEscape() -> Bool { pause() }
}
