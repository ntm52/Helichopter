import UIKit

/// A choice on a UIKit menu. The screen or scene owns it, so switch scanning works with
/// or without a view; a `MenuButton` only mirrors its focus and forwards taps.
protocol MenuChoice: FocusScannable {
    var title: String { get }
    var hint: String { get }
    /// Set by the button currently showing this choice.
    var onFocusChange: ((Bool) -> Void)? { get set }
}

extension MenuChoice {
    var accessibilityScanLabel: String { title }
}

/// A menu choice that runs a closure.
final class MenuItem: MenuChoice {
    let title: String
    let hint: String
    private let action: () -> Void
    var onFocusChange: ((Bool) -> Void)?

    init(_ title: String, hint: String, action: @escaping () -> Void) {
        self.title = title
        self.hint = hint
        self.action = action
    }

    var isFocused = false {
        didSet { onFocusChange?(isFocused) }
    }

    func scannerActivate() { action() }
}

/// A centred column of themed labels and buttons that scrolls from the top when it
/// doesn't fit. Used by Home, the guide, Pause, and Round Over.
class MenuStackView: UIView {
    let scroll = UIScrollView()
    let stack = UIStackView()
    private(set) var buttons: [MenuButton] = []
    let theme = GameSettings.shared.selectedTheme
    private let traits: UITraitCollection

    /// Called after a button's choice is acted on, so the host can update without waiting.
    var onAction: (() -> Void)?

    init(traits: UITraitCollection) {
        self.traits = traits
        super.init(frame: .zero)
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
        accessibilityElements = [scroll]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult
    func addLabel(_ text: String, style: UIFont.TextStyle, alignment: NSTextAlignment = .center,
                  into label: UILabel = UILabel()) -> UILabel {
        label.text = text
        label.font = .preferredFont(forTextStyle: style, compatibleWith: traits)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = alignment
        label.textColor = theme.titleTextColor
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        if style == .title1 { label.accessibilityTraits = .header }
        stack.addArrangedSubview(label)
        return label
    }

    @discardableResult
    func addButton(for choice: MenuChoice) -> MenuButton {
        let button = MenuButton(item: choice, theme: theme, traits: traits)
        button.addTarget(self, action: #selector(activate(_:)), for: .touchUpInside)
        button.onFocus = { [weak self, weak button] in
            guard let self = self, let button = button else { return }
            self.layoutIfNeeded()
            self.scroll.scrollRectToVisible(button.convert(button.bounds.insetBy(dx: -6, dy: -6), to: self.scroll), animated: false)
        }
        stack.addArrangedSubview(button)
        buttons.append(button)
        return button
    }

    /// Empties the column for a new page and returns to the top.
    func removeAll() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons = []
        scroll.setContentOffset(.zero, animated: false)
    }

    @objc private func activate(_ button: MenuButton) {
        button.item.scannerActivate()
        onAction?()
    }
}

/// A menu button that shows its choice's scanner focus as a border.
final class MenuButton: DynamicTextButton {
    let item: MenuChoice
    var onFocus: (() -> Void)?

    init(item: MenuChoice, theme: UITheme, traits: UITraitCollection) {
        self.item = item
        super.init(frame: .zero)
        setTitle(item.title, for: .normal)
        accessibilityHint = item.hint
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
        // The newest button showing a choice takes over its focus updates.
        item.onFocusChange = { [weak self] focused in self?.showFocus(focused) }
        layer.borderWidth = item.isFocused ? 4 : 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func showFocus(_ focused: Bool) {
        layer.borderWidth = focused ? 4 : 0
        if focused { onFocus?() }
    }
}

/// The menu backdrop: the starry sky pinned to the top, or the theme's solid colour.
final class BackdropView: UIView {
    private(set) var sky: UIImageView?

    init(theme: UITheme) {
        super.init(frame: .zero)
        backgroundColor = theme.sceneBackgroundColor
        clipsToBounds = true
        guard theme.backgroundSpriteTintColor == nil, let image = UIImage(named: "Background"),
              image.size.width > 0 else { return }
        let sky = UIImageView(image: image)
        sky.translatesAutoresizingMaskIntoConstraints = false
        sky.isAccessibilityElement = false
        addSubview(sky)
        // Fill the width and keep the top, as the old title scene did; the tall image
        // always reaches the bottom of any window shape the app supports.
        NSLayoutConstraint.activate([
            sky.topAnchor.constraint(equalTo: topAnchor),
            sky.leadingAnchor.constraint(equalTo: leadingAnchor),
            sky.trailingAnchor.constraint(equalTo: trailingAnchor),
            sky.heightAnchor.constraint(equalTo: sky.widthAnchor, multiplier: image.size.height / image.size.width)
        ])
        self.sky = sky
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// A UIKit screen shown by `RootViewController.present(_:)` in place of a scene:
/// Home, the guide, and Settings. The root controller installs it, freezes its
/// scanners during the fade, and forwards switch input to it.
class ScreenViewController: UIViewController, ScreenTransitionScanning, SwitchInputReceivable {
    /// Where choices that change screens go. In the app, the root controller.
    lazy var navigate: (Screen) -> Void = { [weak self] screen in
        (self?.parent as? RootViewController)?.present(screen)
    }

    /// True while this screen is fading in or out; choices are ignored then.
    var isChangingScreen: Bool { (parent as? RootViewController)?.isChangingScreen == true }

    /// The element VoiceOver moves to when this screen appears.
    var announcement: Any? { nil }

    /// Called by the root controller once this screen is installed.
    func screenDidAppear() {
        ScreenChangeAnnouncer.post(announcement)
    }

    /// Called by the root controller before this screen is removed.
    func screenWillDisappear() { }

    var scannersDuringTransition: [FocusScanner] { [] }

    func switchPrimaryBegan() { }
    func switchPrimaryEnded() { }
    func switchSecondaryBegan() { }
    func switchSecondaryEnded() { }
}

/// A UIKit menu screen: a backdrop, a menu column, and a switch scanner over the
/// screen's own choices.
class MenuViewController: ScreenViewController {
    let scanner = FocusScanner()
    private(set) var menu: MenuStackView!
    private let selection = UISelectionFeedbackGenerator()

    override func loadView() {
        let backdrop = BackdropView(theme: GameSettings.shared.selectedTheme)
        let menu = MenuStackView(traits: traitCollection)
        menu.frame = backdrop.bounds
        menu.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.addSubview(menu)
        backdrop.accessibilityElements = [menu]
        // Only this screen is read, never the empty SpriteKit view underneath.
        backdrop.accessibilityViewIsModal = true
        self.menu = menu
        view = backdrop
        buildMenu()
    }

    /// Subclasses fill `menu` and set `scanner.items`.
    func buildMenu() { }

    /// A choice that is ignored while a screen change is fading in or out.
    func item(_ title: String, hint: String, action: @escaping () -> Void) -> MenuItem {
        MenuItem(title, hint: hint) { [weak self] in
            guard let self = self, !self.isChangingScreen else { return }
            self.selection.selectionChanged()
            action()
        }
    }

    override func screenDidAppear() {
        // Auto-start only for switch users; anyone else starts with a first switch press.
        if GameSettings.shared.scanningEnabled { scanner.start() }
        super.screenDidAppear()
    }

    override func screenWillDisappear() {
        scanner.stop()
    }

    override var scannersDuringTransition: [FocusScanner] { [scanner] }

    override func switchPrimaryBegan() { scanner.primaryActivate() }
    override func switchSecondaryBegan() { scanner.secondaryAdvance() }
}
