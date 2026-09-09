import UIKit
import SpriteKit

/// UIKit owns visible text in points, independent of the archived scene's scale.
/// SpriteKit buttons remain the action/scanner model so all input routes agree.
final class SceneTextOverlay: UIView {
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var links: [(ButtonNode, UIButton)] = []
    private var labels: [(SKLabelNode, UILabel)] = []
    private weak var source: SKNode?
    private weak var hostScene: SKScene?
    private var menu = false
    private var bestScoreLabel: UILabel?
    private weak var hudStack: UIStackView?
    private var flightElement: FlightAccessibilityElement?

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        hudStack?.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return !menu && (hit === self || hit === scroll || hit === stack || hit is UIStackView || hit is UILabel) ? nil : hit
    }

    func refresh(in view: SKView) {
        guard let scene = view.scene, !(scene is SettingsScene) else {
            isHidden = true
            source = nil
            links = []
            labels = []
            return
        }
        isHidden = false
        let root = (scene as? GameScene)?.sceneAdapter?.overlay?.contentNode ?? scene
        let isMenu = scene is TitleScene || root !== scene
        if source !== root || hostScene !== scene {
            source = root
            hostScene = scene
            menu = isMenu
            rebuild(scene: scene, root: root)
        }
        for (node, label) in labels {
            if label.text != node.text { label.text = node.text }
            var visible = true
            var alpha: CGFloat = 1
            var ancestor: SKNode? = node
            while let item = ancestor {
                visible = visible && !item.isHidden
                alpha *= item.alpha
                ancestor = item.parent
            }
            label.isHidden = !visible
            label.alpha = alpha
        }
        if let game = scene as? GameScene, !menu {
            let best = "Best \(max(game.sceneAdapter?.score ?? 0, UserDefaults.standard.integer(for: .bestScore)))"
            if bestScoreLabel?.text != best { bestScoreLabel?.text = best }
            bestScoreLabel?.isHidden = !GameSettings.shared.showScore
        }
        flightElement?.accessibilityHint = (scene as? GameScene)?.accessibilityFlightHint
        for (node, button) in links {
            let focused = node.isFocused
            if focused && button.layer.borderWidth == 0 {
                layoutIfNeeded()
                scroll.scrollRectToVisible(button.convert(button.bounds.insetBy(dx: -6, dy: -6), to: scroll), animated: false)
            }
            button.layer.borderWidth = focused ? 4 : 0
        }
    }

    private func rebuild(scene: SKScene, root: SKNode) {
        subviews.forEach { $0.removeFromSuperview() }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        links = []
        labels = []
        let theme = GameSettings.shared.selectedTheme
        bestScoreLabel = nil
        let isPaused = (scene as? GameScene)?.stateMachine.currentState is PausedState
        backgroundColor = isPaused
            ? (GameSettings.shared.hideGameWhilePaused ? theme.sceneBackgroundColor : UIColor.black.withAlphaComponent(0.25))
            : (menu && !(scene is TitleScene) ? theme.sceneBackgroundColor : .clear)
        // The archive supplies actions and text only; never draw a second menu.
        if let content = root as? SKSpriteNode, root !== scene {
            content.texture = nil
            content.color = .clear
            (scene as? GameScene)?.sceneAdapter?.overlay?.backgroundNode.color = .clear
        }
        if scene is TitleScene {
            let mascot = scene.childNode(withName: "Animated Helicopter")
            mascot?.removeAllActions()
            mascot?.isHidden = true
        }
        root.enumerateChildNodes(withName: "//*") { node, _ in
            if let label = node as? SKLabelNode { label.fontColor = .clear }
        }
        for button in scene.findAllButtonsInScene() { button.isPresentedInUIKit = true }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = menu ? 16 : 8
        scroll.isUserInteractionEnabled = menu
        addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        if scene is TitleScene {
            let art = UIImageView(image: UIImage(cgImage: SKTextureAtlas(named: "Helicopter Player").textureNamed("r_player1").cgImage()))
            if !UIAccessibility.isReduceMotionEnabled {
                let atlas = SKTextureAtlas(named: "Helicopter Player")
                art.animationImages = (1...60).map { UIImage(cgImage: atlas.textureNamed("r_player\($0)").cgImage()) }
                art.animationDuration = 1
                art.startAnimating()
            }
            art.contentMode = .scaleAspectFit
            art.heightAnchor.constraint(equalToConstant: 110).isActive = true
            stack.addArrangedSubview(art)
        }
        var textNodes: [SKLabelNode] = []
        root.enumerateChildNodes(withName: "//*") { node, _ in
            // SpriteKit's // search can escape the receiver and include the host scene.
            guard node.inParentHierarchy(root), let label = node as? SKLabelNode else { return }
            var parent = label.parent
            while let item = parent, item !== root {
                if item is ButtonNode { return }
                parent = item.parent
            }
            textNodes.append(label)
        }
        textNodes.sort { $0.convert(.zero, to: scene).y > $1.convert(.zero, to: scene).y }
        // Controls precede the hint so its fade cannot move or cover Pause.
        let hud = UIStackView()
        hud.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        hudStack = hud
        hud.spacing = 12
        hud.alignment = .fill
        if !menu { stack.addArrangedSubview(hud) }
        for node in textNodes {
            let label = UILabel()
            label.font = .preferredFont(forTextStyle: menu && labels.isEmpty ? .title1 : .body, compatibleWith: traitCollection)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = theme.titleTextColor
            if !menu {
                // Keep archived hint alpha/actions and score updates as the source of truth.
                node.fontColor = .clear
                label.backgroundColor = theme.sceneBackgroundColor
                label.isUserInteractionEnabled = false
            }
            if !menu && node.name == "Score Label" {
                hud.addArrangedSubview(label)
                let best = UILabel()
                best.font = .preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
                best.adjustsFontForContentSizeCategory = true
                best.numberOfLines = 0
                best.textColor = theme.titleTextColor
                best.backgroundColor = theme.sceneBackgroundColor
                hud.addArrangedSubview(best)
                bestScoreLabel = best
            } else {
                stack.addArrangedSubview(label)
            }
            labels.append((node, label))
        }
        for node in scene.findAllButtonsInScene() {
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
            button.layer.borderColor = theme.titleTextColor.cgColor
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            if menu {
                stack.addArrangedSubview(button)
            } else {
                // hitTest lets touches outside this control reach the flight surface.
                scroll.isUserInteractionEnabled = true
                hud.addArrangedSubview(button)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
            }
            links.append((node, button))
        }
        flightElement = nil
        if !menu, let game = scene as? GameScene {
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
        } else {
            accessibilityElements = [scroll]
        }
        accessibilityViewIsModal = menu
        UIAccessibility.post(notification: .screenChanged, argument: flightElement)

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
    @objc private func activate() { node?.scannerActivate() }
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
