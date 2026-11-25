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
    private var tileRows: [UIStackView] = []
    let theme = GameSettings.shared.selectedTheme
    private let traits: UITraitCollection

    /// Called after a button's choice is acted on, so the host can update without waiting.
    var onAction: (() -> Void)?
    /// The card behind the column, when the menu sits on one (Pause and Round Over).
    private(set) var card: SurfaceView?

    /// Scroll down and Scroll up, pinned under the column. A switch user cannot scroll, so
    /// a host whose words may run past the screen scans these first (`scrollItemsIfNeeded`).
    private(set) lazy var scrollItems: [MenuItem] = [
        MenuItem("Scroll down", hint: "Shows the words further down") { [weak self] in
            Feedback.choose()
            self?.scroll.scrollPage(down: true)
        },
        MenuItem("Scroll up", hint: "Shows the words further up") { [weak self] in
            Feedback.choose()
            self?.scroll.scrollPage(down: false)
        }]
    private let scrollBar = UIStackView()
    private var scrollEndsAtBar: NSLayoutConstraint!
    private var scrollEndsAtBottom: NSLayoutConstraint!

    /// The scroll choices if the column is too long for the screen, showing their bar;
    /// otherwise none. Call when scanning starts.
    func scrollItemsIfNeeded() -> [MenuItem] {
        layoutIfNeeded()
        guard scrollBar.isHidden else { return scrollItems }
        guard scroll.overflowsVertically else { return [] }
        if scrollBar.arrangedSubviews.isEmpty {
            for item in scrollItems {
                let button = MenuButton(item: item, theme: theme, traits: traits)
                button.setIcon(systemName: item === scrollItems.first ? "chevron.down" : "chevron.up")
                button.addTarget(self, action: #selector(activate(_:)), for: .touchUpInside)
                scrollBar.addArrangedSubview(button)
            }
        }
        scrollBar.isHidden = false
        scrollEndsAtBottom.isActive = false
        scrollEndsAtBar.isActive = true
        layoutIfNeeded()
        return scrollItems
    }

    /// Takes the scroll choices away again, for a new page or when scanning is over.
    func hideScrollBar() {
        scrollBar.isHidden = true
        scrollEndsAtBar.isActive = false
        scrollEndsAtBottom.isActive = true
    }

    /// `onCard` puts the column on a card, for a menu that floats over the game.
    init(traits: UITraitCollection, onCard: Bool = false) {
        self.traits = traits
        super.init(frame: .zero)
        // Room between the column and the card's edge, on every side.
        let inset = onCard ? Spacing.xl : 0
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = Spacing.l
        addSubview(scroll)
        scroll.addSubview(stack)
        scrollBar.translatesAutoresizingMaskIntoConstraints = false
        scrollBar.distribution = .fillEqually
        scrollBar.spacing = Spacing.m
        scrollBar.isHidden = true
        addSubview(scrollBar)
        scrollEndsAtBottom = scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -Spacing.m)
        scrollEndsAtBar = scroll.bottomAnchor.constraint(equalTo: scrollBar.topAnchor, constant: -Spacing.m)
        // Centred when the menu fits; scrolls from the top when it doesn't.
        let hug = stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor)
        hug.priority = .defaultLow
        // As wide as the screen allows, up to the content width.
        let fill = stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -2 * inset)
        fill.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: Spacing.m),
            scrollEndsAtBottom,
            scrollBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -Spacing.m),
            scrollBar.centerXAnchor.constraint(equalTo: stack.centerXAnchor),
            scrollBar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: Spacing.l),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -Spacing.l),
            scroll.contentLayoutGuide.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: scroll.contentLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maxContentWidth - 2 * inset),
            fill,
            scroll.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
            stack.centerYAnchor.constraint(equalTo: scroll.contentLayoutGuide.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: scroll.contentLayoutGuide.topAnchor, constant: inset),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: scroll.contentLayoutGuide.bottomAnchor, constant: -inset - (onCard ? Stroke.edge : 0)),
            hug
        ])
        if onCard {
            let card = SurfaceView(theme: theme)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.isUserInteractionEnabled = false
            scroll.insertSubview(card, belowSubview: stack)
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: stack.topAnchor, constant: -inset),
                card.bottomAnchor.constraint(equalTo: stack.bottomAnchor, constant: inset + Stroke.edge),
                card.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: -inset),
                card.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: inset)
            ])
            self.card = card
        }
        accessibilityElements = [scroll, scrollBar]
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (menu: MenuStackView, _: UITraitCollection) in
            menu.tileRows.forEach { menu.arrange($0, compatibleWith: menu.traitCollection) }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// A card in the column for running text, so the backdrop never shows through it.
    /// Labels go on it with `addLabel(_:style:on:)`; buttons stay on the page below.
    func addTextCard() -> SurfaceView {
        let surface = SurfaceView(theme: theme)
        surface.content.spacing = Spacing.m
        surface.content.isLayoutMarginsRelativeArrangement = true
        surface.content.layoutMargins = UIEdgeInsets(top: Spacing.l, left: Spacing.l, bottom: Spacing.l, right: Spacing.l)
        stack.addArrangedSubview(surface)
        return surface
    }

    /// `surface` is a card from `addTextCard()`; without one the label joins the column.
    @discardableResult
    func addLabel(_ text: String, style: TypeStyle, alignment: NSTextAlignment = .center,
                  into label: UILabel = UILabel(), on surface: SurfaceView? = nil) -> UILabel {
        label.text = text
        label.font = style.font(compatibleWith: traits)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = alignment
        // On a card, text is in the card's text colour; over the sky, the title colour.
        label.textColor = card == nil && surface == nil ? theme.titleTextColor : theme.textColor
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        if style == .display { label.accessibilityTraits = .header }
        (surface?.content ?? stack).addArrangedSubview(label)
        return label
    }

    @discardableResult
    func addButton(for choice: MenuChoice, kind: ButtonKind = .secondary, size: ButtonSize = .regular,
                   icon: String? = nil) -> MenuButton {
        let button = makeButton(for: choice, kind: kind, size: size)
        if let icon = icon { button.setIcon(systemName: icon) }
        stack.addArrangedSubview(button)
        return button
    }

    /// A column of buttons that the host may turn into a row, by changing the returned
    /// stack's axis, when the screen is short. The scanning order is the order given.
    @discardableResult
    func addButtonGroup(for choices: [(choice: MenuChoice, kind: ButtonKind, icon: String)]) -> UIStackView {
        let group = UIStackView()
        group.axis = .vertical
        group.spacing = Spacing.l
        group.distribution = .fillEqually
        for entry in choices {
            let button = makeButton(for: entry.choice, kind: entry.kind, size: .regular)
            button.setIcon(systemName: entry.icon)
            group.addArrangedSubview(button)
        }
        stack.addArrangedSubview(group)
        return group
    }

    /// A row of equal tiles, each with its icon above its title. At accessibility text
    /// sizes the row becomes a column of full-width buttons with the icon before the title.
    @discardableResult
    func addTileRow(for choices: [(choice: MenuChoice, icon: String)]) -> [MenuButton] {
        let row = UIStackView()
        row.distribution = .fillEqually
        row.alignment = .fill
        let tiles = choices.map { entry -> MenuButton in
            let button = makeButton(for: entry.choice, kind: .secondary, size: .regular)
            button.setIcon(systemName: entry.icon)
            row.addArrangedSubview(button)
            return button
        }
        stack.addArrangedSubview(row)
        tileRows.append(row)
        arrange(row, compatibleWith: traits)
        return tiles
    }

    private func arrange(_ row: UIStackView, compatibleWith traits: UITraitCollection) {
        let column = traits.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = column ? .vertical : .horizontal
        row.spacing = column ? Spacing.l : Spacing.m
        for case let button as ArcadeButton in row.arrangedSubviews {
            button.iconPlacement = column ? .leading : .top
        }
    }

    private func makeButton(for choice: MenuChoice, kind: ButtonKind, size: ButtonSize) -> MenuButton {
        let button = MenuButton(item: choice, kind: kind, size: size, theme: theme, traits: traits)
        button.addTarget(self, action: #selector(activate(_:)), for: .touchUpInside)
        button.onFocus = { [weak self, weak button] in
            guard let self = self, let button = button else { return }
            self.layoutIfNeeded()
            let rect = button.convert(button.bounds.insetBy(dx: -Spacing.s, dy: -Spacing.s), to: self.scroll)
            guard button === self.buttons.first else {
                return self.scroll.scrollRectToVisible(rect, animated: false)
            }
            // Back on the first choice, scroll up as far as keeps it on screen, so a
            // switch user who cannot scroll sees the words above the choices again.
            let highest = max(0, min(rect.maxY - self.scroll.bounds.height,
                                     self.scroll.contentSize.height - self.scroll.bounds.height))
            self.scroll.setContentOffset(CGPoint(x: 0, y: highest), animated: false)
        }
        buttons.append(button)
        return button
    }

    /// Empties the column for a new page and returns to the top.
    func removeAll() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons = []
        tileRows = []
        hideScrollBar()
        scroll.setContentOffset(.zero, animated: false)
    }

    @objc private func activate(_ button: MenuButton) {
        button.item.scannerActivate()
        onAction?()
    }
}

/// A menu button that shows its choice's scanner focus as a border and a brighter face.
final class MenuButton: ArcadeButton {
    let item: MenuChoice
    var onFocus: (() -> Void)?

    init(item: MenuChoice, kind: ButtonKind = .secondary, size: ButtonSize = .regular,
         theme: UITheme, traits: UITraitCollection) {
        self.item = item
        super.init(kind: kind, size: size, theme: theme, traits: traits)
        setTitle(item.title, for: .normal)
        accessibilityHint = item.hint
        // The newest button showing a choice takes over its focus updates.
        item.onFocusChange = { [weak self] focused in self?.showFocus(focused) }
        layer.borderWidth = item.isFocused ? Stroke.focus : 0
        showsFocus = item.isFocused
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func showFocus(_ focused: Bool) {
        layer.borderWidth = focused ? Stroke.focus : 0
        showsFocus = focused
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

    /// The part of the screen that settles into place as the screen fades in: its
    /// content, never its backdrop. Nil for a screen that only fades.
    var settlingContent: UIView? { nil }

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
            Feedback.choose()
            action()
        }
    }

    /// Starts or stops the menu theme after the music setting changes. In the app, the
    /// root controller's player; tests replace it.
    lazy var applyMusicSetting: () -> Void = { [weak self] in
        (self?.parent as? RootViewController)?.menuMusic.play()
    }

    /// The Music button, at the end of the column. It turns the music setting (also in
    /// Settings → Sound) off or on, so VoiceOver and spoken steps can be heard over it.
    @discardableResult
    func addMusicButton(kind: ButtonKind) -> MenuButton {
        weak var button: MenuButton?
        let choice = MusicChoice { [weak self] in
            guard let self = self, !self.isChangingScreen else { return }
            Feedback.choose()
            MusicChoice.isOn.toggle()
            self.applyMusicSetting()
            button?.showMusicState()
        }
        let made = menu.addButton(for: choice, kind: kind, icon: choice.icon)
        made.showMusicState()
        button = made
        return made
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

    override var settlingContent: UIView? { menu }

    override func switchPrimaryBegan() { scanner.primaryActivate() }
    override func switchSecondaryBegan() { scanner.secondaryAdvance() }
}

/// The Music choice on Home and in the guide. Its title says whether music is playing.
final class MusicChoice: MenuChoice {
    /// The music setting, shared with the Music switch in Settings → Sound and the game.
    static var isOn: Bool {
        get { UserDefaults.standard.bool(for: .isMusicOn) }
        set { UserDefaults.standard.set(newValue, for: .isMusicOn) }
    }

    var title: String { Self.isOn ? "Music On" : "Music Off" }
    var hint: String { Self.isOn ? "Turns the music off" : "Turns the music on" }
    var icon: String { Self.isOn ? "speaker.wave.2.fill" : "speaker.slash.fill" }
    var onFocusChange: ((Bool) -> Void)?
    var isFocused = false {
        didSet { onFocusChange?(isFocused) }
    }
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func scannerActivate() { action() }
}

extension MenuButton {
    /// Shows a Music button's current state: its title (also its spoken name), icon,
    /// and hint. Voice Control also knows it as plain "Music", whichever state it is in.
    func showMusicState() {
        guard let music = item as? MusicChoice else { return }
        setTitle(music.title, for: .normal)
        setIcon(systemName: music.icon)
        accessibilityHint = music.hint
        accessibilityUserInputLabels = [music.title, "Music"]
    }
}
