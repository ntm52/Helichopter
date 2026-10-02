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
    private var newHighScoreLabel: UILabel?
    private weak var hudStack: UIStackView?
    private var flightElement: FlightAccessibilityElement?
    // Stack constraints survive removing the scroll view, so track them per rebuild.
    private var layoutConstraints: [NSLayoutConstraint] = []
    static let guideCompletedKey = "onboarding_completed_v1"
    var guideDefaults = UserDefaults.standard
    private(set) var guidePage: Int?


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
            if hostScene !== scene {
                guidePage = scene is TitleScene && !guideDefaults.bool(forKey: Self.guideCompletedKey) ? 0 : nil
            }
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
            let celebrate = game.sceneAdapter?.isShowingNewHighScore == true
                && game.stateMachine.currentState is PlayingState
            if newHighScoreLabel?.isHidden == celebrate { newHighScoreLabel?.isHidden = !celebrate }
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
        newHighScoreLabel = nil
        let isPaused = (scene as? GameScene)?.stateMachine.currentState is PausedState
        backgroundColor = isPaused
            ? (GameSettings.shared.hideGameWhilePaused ? theme.sceneBackgroundColor : UIColor.black.withAlphaComponent(0.25))
            : (menu && !(scene is TitleScene) ? theme.sceneBackgroundColor : .clear)
        // The archive supplies actions and text only; never draw a second menu.
        // Scenes and overlays also suppress at load, so this only covers late additions.
        scene.suppressArchivedPresentation()
        (scene as? GameScene)?.sceneAdapter?.overlay?.suppressArchivedPresentation()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = menu ? 16 : 8
        scroll.isUserInteractionEnabled = menu
        addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.deactivate(layoutConstraints)
        layoutConstraints = [
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ]
        if menu {
            // Menus centre vertically when they fit and scroll from the top when they don't.
            let hug = stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor)
            hug.priority = .defaultLow
            layoutConstraints += [
                scroll.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
                stack.centerYAnchor.constraint(equalTo: scroll.contentLayoutGuide.centerYAnchor),
                stack.topAnchor.constraint(greaterThanOrEqualTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: scroll.contentLayoutGuide.bottomAnchor),
                hug
            ]
        } else {
            // The gameplay HUD stays pinned to the top, clear of the flight area.
            layoutConstraints += [
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor)
            ]
        }
        NSLayoutConstraint.activate(layoutConstraints)
        if let title = scene as? TitleScene, let page = guidePage {
            buildGuide(page: page, scene: title)
            return
        }
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
        if !menu, scene is GameScene {
            // Static text; no animation, sound, or input capture, so flight is never interrupted.
            let banner = UILabel()
            banner.text = "New high score!"
            banner.font = .preferredFont(forTextStyle: .title2, compatibleWith: traitCollection)
            banner.adjustsFontForContentSizeCategory = true
            banner.numberOfLines = 0
            banner.textAlignment = .center
            banner.textColor = theme.titleTextColor
            banner.backgroundColor = theme.sceneBackgroundColor
            banner.isHidden = true
            stack.addArrangedSubview(banner)
            newHighScoreLabel = banner
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
        if let title = scene as? TitleScene {
            let scanner = title.focusScanner
            let wasScanning = scanner?.isActive == true
            scanner?.stop()
            let help = guideButton("How to Play") { [weak self, weak title] in
                guard let self = self, let title = title else { return }
                self.guidePage = 0
                self.rebuild(scene: title, root: title)
            }
            scanner?.items = title.findAllButtonsInScene() + [help]
            if wasScanning { scanner?.start() }
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

    private func guideLabel(_ text: String, style: UIFont.TextStyle) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style, compatibleWith: traitCollection)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = GameSettings.shared.selectedTheme.titleTextColor
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        if style == .title1 { label.accessibilityTraits = .header }
        stack.addArrangedSubview(label)
        return label
    }

    @discardableResult
    private func guideButton(_ title: String, action: @escaping () -> Void) -> GuideButton {
        let button = GuideButton(frame: .zero)
        button.action = action
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        let theme = GameSettings.shared.selectedTheme
        button.setTitleColor(theme.buttonTextColor, for: .normal)
        button.backgroundColor = theme.buttonTintColor
        button.layer.cornerRadius = 12
        button.layer.borderColor = theme.titleTextColor.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.onFocus = { [weak self, weak button] in
            guard let self = self, let button = button else { return }
            self.layoutIfNeeded()
            self.scroll.scrollRectToVisible(button.convert(button.bounds.insetBy(dx: -6, dy: -6), to: self.scroll), animated: false)
        }
        stack.addArrangedSubview(button)
        return button
    }

    static func flightInstructions(for scheme: ControlScheme) -> String {
        switch scheme {
        case .tapFlap:
            return "Tap the screen or press your primary switch to rise. Between taps, the helicopter falls. With VoiceOver, double-tap to rise."
        case .holdHover:
            return "Hold the screen or your primary switch to rise. Release to fall gently. With VoiceOver, double-tap to switch between rising and falling."
        case .autoHover:
            return "The helicopter hovers automatically. Tap the screen or press your primary switch to nudge up; use your secondary switch to nudge down. With VoiceOver, double-tap to nudge up or use the Move down action."
        case .twoSwitchUD:
            return "Hold your primary switch to move up or your secondary switch to move down. Release to settle. Touching the screen also moves up. With VoiceOver, double-tap to toggle moving up or use Move down to toggle moving down."
        }
    }

    private func navigateGuide(to page: Int?, scene: TitleScene) {
        guidePage = page
        if page == nil { guideDefaults.set(true, forKey: Self.guideCompletedKey) }
        rebuild(scene: scene, root: scene)
    }

    private func buildGuide(page: Int, scene: TitleScene) {
        let scanner = scene.focusScanner
        let wasScanning = scanner?.isActive == true
        scanner?.stop()
        flightElement = nil
        accessibilityViewIsModal = true
        accessibilityElements = [scroll]
        scroll.setContentOffset(.zero, animated: false)
        let settings = GameSettings.shared
        let pages: [(String, String)] = [
            ("Your flight controls", "Fly through the gaps between pipes.\n\n" + Self.flightInstructions(for: settings.controlScheme) + "\n\nYou can change controls in Settings → Switch Access."),
            ("Go at your own pace", "No-fail mode is currently \(settings.noFailMode ? "on: bumps let you keep flying" : "off: a collision ends the round, and you can retry"). Change it in Settings → Comfort.\n\nTap Pause during flight, or hold your primary switch for \(String(format: "%.0f", settings.switchPauseHoldDuration)) seconds. With VoiceOver, use the Pause action or the escape gesture. Choose Resume when ready.\n\nSettings → Difficulty Preset offers Gentle, Standard, and Challenge. Start with Gentle for wider gaps and slower pipes."),
            ("Switches and menus", "Press your primary switch (Space or Enter on a keyboard) to start menu scanning, then press it again to choose the highlighted item. \(settings.scanScheme == .autoScan ? "Your menus currently advance automatically." : "Your menus currently wait for your secondary switch to advance.") Use your secondary switch (2 or an arrow key other than Up) to move to the next item.\n\nSettings → Switch Access lets you choose automatic or two-switch scanning, scan timing, and the hold-to-pause delay.\n\nThis guide waits for you. Replay it anytime with How to Play on the home screen.")
        ]
        let content = pages[page]
        let heading = guideLabel(content.0, style: .title1)
        _ = guideLabel("Step \(page + 1) of \(pages.count)", style: .subheadline)
        _ = guideLabel(content.1, style: .body)
        var items: [FocusScannable] = []
        // Switch users can hear the full instructions without navigating static text.
        let read = guideButton("Read this step aloud") { [weak scanner] in
            scanner?.readInstructions(content.0 + ". " + content.1 + " Press your switch to resume menu scanning.")
        }
        items.append(read)
        items.append(guideButton(page == pages.count - 1 ? "Done" : "Next") { [weak self, weak scene] in
            guard let self = self, let scene = scene else { return }
            self.navigateGuide(to: page == pages.count - 1 ? nil : page + 1, scene: scene)
        })
        if page > 0 {
            items.append(guideButton("Back") { [weak self, weak scene] in
                guard let self = self, let scene = scene else { return }
                self.navigateGuide(to: page - 1, scene: scene)
            })
        }
        items.append(guideButton("Skip guide") { [weak self, weak scene] in
            guard let self = self, let scene = scene else { return }
            self.navigateGuide(to: nil, scene: scene)
        })
        scanner?.items = items
        if wasScanning { scanner?.start() }
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }
}

private final class GuideButton: DynamicTextButton, FocusScannable {
    var action: (() -> Void)?
    var onFocus: (() -> Void)?
    private var scanFocused = false
    override var isFocused: Bool {
        get { scanFocused }
        set {
            scanFocused = newValue
            layer.borderWidth = newValue ? 4 : 0
            if newValue { onFocus?() }
        }
    }
    var accessibilityScanLabel: String { currentTitle ?? "" }
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(scannerActivate), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc func scannerActivate() { action?() }
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
        // Rebuild now rather than on the next timer tick, so a second tap cannot
        // reach a control whose menu has already closed.
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

extension SceneOverlay {
    func suppressArchivedPresentation() {
        contentNode.texture = nil
        contentNode.color = .clear
        backgroundNode.color = .clear
        contentNode.suppressArchivedPresentation()
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
