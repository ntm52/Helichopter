import UIKit

// MARK: - Control target helpers
// These wrappers let closures work as addTarget selectors while keeping a strong
// reference alive via ScrollingPanelView.controlTargets.

final class ButtonTarget: NSObject {
    private let f: () -> Void
    init(_ f: @escaping () -> Void) { self.f = f }
    @objc func tapped() {
        Feedback.choose()
        f()
    }
}

// MARK: - Theme-derived colour tokens

/// The panel colours shared by Settings and the Hangar, derived from the active UITheme
/// so panels follow the player's chosen theme.
struct SettingsStyle {
    let bg: UIColor               // panel background
    let accent: UIColor           // accent-coloured text: section headings, quiet buttons
    let accentFill: UIColor       // slider and switch tracks, chosen cards
    let text: UIColor             // primary label text
    let sub: UIColor              // secondary / detail text
    let rowBg: UIColor            // individual row backgrounds
    let div: UIColor              // dividers and outlines
    let track: UIColor            // the unfilled part of a slider's track, on a row
    let focus: UIColor            // the scanner's focus ring

    init(theme: UITheme) {
        bg = theme.sceneBackgroundColor.withAlphaComponent(0.97)
        accent = theme.accentTextColor
        accentFill = theme.accentColor
        text = theme.textColor
        sub = theme.secondaryTextColor
        rowBg = theme.cardColor
        div = theme.inkColor
        track = theme.secondaryTextColor
        focus = theme.focusColor
    }
}

private final class PanelScanItem: FocusScannable {
    weak var control: UIControl?
    private let focus: (UIControl, Bool) -> Void
    private let activate: (UIControl) -> Void

    init(control: UIControl, focus: @escaping (UIControl, Bool) -> Void,
         activate: @escaping (UIControl) -> Void) {
        self.control = control
        self.focus = focus
        self.activate = activate
    }

    var isFocused = false {
        didSet { if let control = control { focus(control, isFocused) } }
    }

    var accessibilityScanLabel: String {
        guard let control = control else { return "" }
        let label = control.accessibilityLabel ?? (control as? UIButton)?.currentTitle ?? ""
        if let toggle = control as? UISwitch { return "\(label), \(toggle.isOn ? "On" : "Off")" }
        if let slider = control as? UISlider { return "\(label), \(slider.spokenValue). Select to adjust." }
        // The chosen card or choice says so, as VoiceOver does: "Classic Pipes, Equipped".
        if let value = control.accessibilityValue, !value.isEmpty { return "\(label), \(value)" }
        if control.accessibilityTraits.contains(.selected) { return "\(label), selected" }
        return label
    }

    func scannerActivate() {
        if let control = control { activate(control) }
    }
}

// MARK: - ScrollingPanelView
// A titled page with a Back button and a scrolling column of rows, scanned control by
// control. Settings and the Hangar subclass it and fill `stack` in `buildSections()`.

class ScrollingPanelView: UIView {

    /// The heading beside Back, for a panel that always has the same one.
    class var title: String { "" }
    /// The heading beside Back.
    var title: String { Self.title }
    /// What VoiceOver says Back does.
    var backHint: String { "Goes to the home screen" }

    let fontTraits: UITraitCollection?
    let theme: UITheme
    let style: SettingsStyle
    /// True on a wide, short screen (a phone on its side): rows and page items go two to
    /// a line, read and scanned left to right, then down.
    let usesColumns: Bool

    var onBack: (() -> Void)?
    /// Asks the host to rebuild the panel: theme, preset, lock, reset, or text size changed.
    var onThemeChanged: (() -> Void)?

    let switchScanner = FocusScanner()
    private let focusRing = UIView()
    private(set) weak var focusedControl: UIControl?
    private var navigationItems: [FocusScannable] = []

    // Retain targets so addTarget's weak reference doesn't dangle.
    var controlTargets: [NSObject] = []

    private let scrollView = UIScrollView()
    /// The page: section headings, cards, and buttons, top to bottom.
    let stack = UIStackView()
    /// Back and the title.
    private(set) var header: UIStackView!
    /// The card that `appendRow` is filling; a section heading or a page button ends it.
    private var openCard: SurfaceView?
    /// In columns, the line on the open card waiting for its second row.
    private var openRowPair: ColumnPair?
    /// In columns, the line on the page waiting for its second item.
    private var openPagePair: ColumnPair?

    // MARK: - Initialization

    required init(frame: CGRect, theme: UITheme, fontTraits: UITraitCollection? = nil, columns: Bool = false) {
        self.fontTraits = fontTraits
        self.theme = theme
        style = SettingsStyle(theme: theme)
        usesColumns = columns
        super.init(frame: frame)
        buildUI()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (panel: ScrollingPanelView, previous: UITraitCollection) in
            if (panel.fontTraits ?? previous).preferredContentSizeCategory != panel.traitCollection.preferredContentSizeCategory {
                panel.onThemeChanged?()
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Subclasses add their rows to `stack`.
    func buildSections() { }

    /// The narrowest a column may be: about a portrait phone's card.
    static let minColumnWidth: CGFloat = 300

    /// Whether a screen of this size has room for two columns side by side. Only a screen
    /// wider than tall, and never at accessibility text sizes, where a row needs the width.
    static func fitsColumns(in size: CGSize, safeArea: UIEdgeInsets, traits: UITraitCollection) -> Bool {
        guard !traits.preferredContentSizeCategory.isAccessibilityCategory, size.width > size.height else { return false }
        let usable = size.width - safeArea.left - safeArea.right - 2 * Spacing.l
        return usable >= 2 * minColumnWidth + Spacing.l
    }

    /// How wide the page may grow: one column, or two with a gap.
    private var maxWidth: CGFloat { usesColumns ? 2 * Layout.maxContentWidth + Spacing.l : Layout.maxContentWidth }

    /// True while a page covers the list; a rebuild reopens it.
    var isAdjusting: Bool { false }

    /// Where VoiceOver goes once a rebuilt panel has faded in.
    var announcementAfterRebuild: Any? { self }

    // MARK: - Switch scanning

    /// The label of the control the scanner is on, so a rebuilt panel can return to it.
    var focusedSetting: String? {
        focusedControl?.accessibilityLabel ?? (focusedControl as? UIButton)?.currentTitle
    }

    /// The part of the panel the scanner moves through: all of it, or a page covering it.
    var scanRoot: UIView { self }

    /// Opens the page that covered a rebuilt panel again, for a player who is not scanning.
    func reopenAdjustment(labelled label: String?) { }

    /// Controls the scanner passes over, because another control on the row does their job.
    let scanSkipped = NSHashTable<UIControl>.weakObjects()

    /// Called before the scanner lists its controls, so a page can show ones only it needs.
    func prepareToScan() { }

    func startScanning(focusing label: String? = nil) {
        switchScanner.stop()
        prepareToScan()
        navigationItems = controls(in: scanRoot).filter { !scanSkipped.contains($0) }.map { scanItem(for: $0) }
        switchScanner.items = navigationItems
        let index = navigationItems.firstIndex {
            let control = ($0 as? PanelScanItem)?.control
            return label != nil && (control?.accessibilityLabel ?? (control as? UIButton)?.currentTitle) == label
        } ?? 0
        switchScanner.start(at: index)
    }

    func stopScanning() { switchScanner.stop() }

    /// The control with this spoken name, if the panel has one.
    func control(labelled label: String) -> UIControl? {
        controls(in: self).first { ($0.accessibilityLabel ?? ($0 as? UIButton)?.currentTitle) == label }
    }

    func primaryActivate() {
        if !switchScanner.isActive { startScanning() }
        else { switchScanner.primaryActivate() }
    }

    func secondaryAdvance() {
        if !switchScanner.isActive { startScanning() }
        else { switchScanner.secondaryAdvance() }
    }

    func controls(in view: UIView) -> [UIControl] {
        guard !view.isHidden, view.isUserInteractionEnabled else { return [] }
        if let control = view as? UIControl { return control.isEnabled ? [control] : [] }
        return view.subviews.flatMap { controls(in: $0) }
    }

    func scanItem(for control: UIControl) -> FocusScannable {
        PanelScanItem(control: control, focus: { [weak self] control, focused in
            guard let self = self else { return }
            self.focusRing.isHidden = !focused
            if focused {
                self.focusedControl = control
                self.layoutIfNeeded()
                // Scroll both the palette strip and the outer panel when necessary.
                var ancestor = control.superview
                while let view = ancestor {
                    if let scroll = view as? UIScrollView {
                        scroll.scrollRectToVisible(control.convert(control.bounds.insetBy(dx: -Spacing.s, dy: -Spacing.s), to: scroll), animated: false)
                    }
                    ancestor = view.superview
                }
                self.updateFocusRing()
            }
        }, activate: { [weak self] control in
            self?.activate(control)
        })
    }

    /// What a scanner selection does: switches flip, other controls are tapped.
    func activate(_ control: UIControl) {
        if let toggle = control as? UISwitch {
            // A touched switch gives the system's own haptic; a scanned one has only this.
            Feedback.choose()
            toggle.setOn(!toggle.isOn, animated: false)
            toggle.sendActions(for: .valueChanged)
        } else {
            control.sendActions(for: .touchUpInside)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateFocusRing()
    }

    private func updateFocusRing() {
        guard let control = focusedControl, switchScanner.isActive else { return }
        focusRing.frame = control.convert(control.bounds, to: self).insetBy(dx: -Stroke.focus, dy: -Stroke.focus)
        bringSubviewToFront(focusRing)
    }

    var scrollPosition: CGPoint { scrollView.contentOffset }

    func restoreScrollPosition(_ offset: CGPoint) {
        layoutIfNeeded()
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        scrollView.contentOffset = CGPoint(x: 0, y: min(max(0, offset.y), maxY))
    }

    // MARK: - Layout

    private func buildUI() {
        backgroundColor = style.bg

        let traits = fontTraits ?? traitCollection
        let backBtn = panelButton("Back", icon: "chevron.left", target: self, action: #selector(backTapped))
        backBtn.accessibilityLabel = "Back"
        backBtn.accessibilityHint = backHint
        backBtn.setContentHuggingPriority(.required, for: .horizontal)
        backBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
        let titleLbl = makeLabel(title, style: .display, color: style.text)
        titleLbl.accessibilityTraits = .header
        // Back sits before the title; at accessibility text sizes the title goes below it.
        let stacked = traits.preferredContentSizeCategory.isAccessibilityCategory
        let header = UIStackView(arrangedSubviews: [backBtn, titleLbl])
        header.axis = stacked ? .vertical : .horizontal
        header.alignment = stacked ? .leading : .center
        header.spacing = stacked ? Spacing.s : Spacing.l
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: Spacing.s, left: Spacing.l, bottom: Spacing.m, right: Spacing.l)
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        self.header = header

        let headerDiv = hairline()
        addSubview(headerDiv)

        scrollView.alwaysBounceVertical        = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis    = .vertical
        stack.spacing = Spacing.l
        // Cards and buttons keep a margin from the screen edges.
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 0, left: Spacing.l, bottom: 0, right: Spacing.l)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        // As wide as the screen allows, up to the content width.
        let fill = stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        fill.priority = UILayoutPriority(999)
        // The header lines up with the column of cards below it.
        let headerFill = header.widthAnchor.constraint(equalTo: widthAnchor)
        headerFill.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            header.centerXAnchor.constraint(equalTo: centerXAnchor),
            header.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            // Clear of the camera housing on a phone on its side.
            header.widthAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.widthAnchor),
            headerFill,

            headerDiv.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            headerDiv.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerDiv.trailingAnchor.constraint(equalTo: trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Spacing.l),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            stack.widthAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.widthAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Spacing.xxl),
            fill,
        ])

        buildSections()
        closeLines()
        focusRing.isUserInteractionEnabled = false
        focusRing.accessibilityElementsHidden = true
        focusRing.layer.borderWidth = Stroke.focus
        focusRing.layer.borderColor = style.focus.cgColor
        focusRing.layer.cornerRadius = Radius.control
        focusRing.isHidden = true
        addSubview(focusRing)
    }

    @objc private func backTapped() {
        Feedback.choose()
        onBack?()
    }

    /// VoiceOver's escape gesture (a two-finger scrub) goes back, as Back does.
    override func accessibilityPerformEscape() -> Bool {
        guard onBack != nil else { return false }
        backTapped()
        return true
    }
}

// MARK: - Shared row builders

extension ScrollingPanelView {

    /// Starts a section: a heading, then whatever is added until the next heading.
    func sectionHeader(_ title: String) {
        closeLines()
        openCard = nil
        if let last = stack.arrangedSubviews.last { stack.setCustomSpacing(Spacing.xl, after: last) }
        let lbl = makeLabel(title, style: .heading, color: style.accent)
        // VoiceOver's heading rotor jumps between sections.
        lbl.accessibilityTraits = .header
        stack.addArrangedSubview(lbl)
        stack.setCustomSpacing(Spacing.s, after: lbl)
    }

    /// Disables every control in `rows` and dims them: VoiceOver says "dimmed" and
    /// Voice Control and the scanner skip them.
    func lock(_ rows: [UIView]) {
        for row in rows {
            controls(in: row).forEach { $0.isEnabled = false }
            row.isUserInteractionEnabled = false
            row.alpha = 0.5
        }
    }

    func font(_ style: TypeStyle) -> UIFont {
        style.font(compatibleWith: fontTraits ?? traitCollection)
    }

    func makeLabel(_ labelText: String, style: TypeStyle, color: UIColor) -> UILabel {
        let l = WrappingPanelLabel()
        l.setContentCompressionResistancePriority(.required, for: .vertical)
        l.text      = labelText
        l.textColor = color
        l.adjustsFontForContentSizeCategory = true
        l.font = font(style)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    /// A secondary button, with an optional SF Symbol before its title.
    func panelButton(_ title: String, icon: String? = nil, kind: ButtonKind = .secondary,
                     target: Any, action: Selector) -> ArcadeButton {
        let btn = ArcadeButton(kind: kind, theme: theme, traits: fontTraits ?? traitCollection)
        btn.setTitle(title, for: .normal)
        if let icon = icon { btn.setIcon(systemName: icon) }
        btn.addTarget(target, action: action, for: .touchUpInside)
        return btn
    }

    /// A row of plain text on a card, such as "Locked by a caregiver".
    func noteRow(_ text: String) {
        let row = UIView()
        let label = makeLabel(text, style: .body, color: style.text)
        row.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: row.topAnchor, constant: Spacing.m),
            label.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -Spacing.m),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Spacing.l),
            label.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Spacing.l),
        ])
        appendRow(row)
    }

    func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = style.div
        v.heightAnchor.constraint(equalToConstant: Stroke.divider).isActive = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    /// Adds a row to the section's card, starting the card if this is its first row.
    /// In columns, rows go two to a line on the card.
    func appendRow(_ row: UIView) {
        if let pair = openRowPair {
            pair.fill(row)
            openRowPair = nil
            return
        }
        closePagePair()
        var item = row
        if usesColumns {
            let pair = ColumnPair(first: row, divider: style.div)
            openRowPair = pair
            item = pair
        }
        let card: SurfaceView
        if let open = openCard {
            card = open
            card.content.addArrangedSubview(hairline())
        } else {
            card = SurfaceView(theme: theme)
            stack.addArrangedSubview(card)
            openCard = card
        }
        card.content.addArrangedSubview(item)
    }

    /// Ends the section's card, so the next row starts a new one.
    func endCard() {
        closeRowPair()
        openCard = nil
    }

    /// Adds something that stands on the page by itself, outside any card: a button or
    /// a row of cards. In columns, items go two to a line unless `spansColumns`.
    func appendToPage(_ view: UIView, spansColumns: Bool = false) {
        endCard()
        if usesColumns && !spansColumns {
            if let pair = openPagePair {
                pair.fill(view)
                openPagePair = nil
            } else {
                let pair = ColumnPair(first: view, divider: nil)
                openPagePair = pair
                stack.addArrangedSubview(pair)
            }
            return
        }
        closePagePair()
        stack.addArrangedSubview(view)
    }

    /// A line left with one item lets it take the whole width.
    private func closeRowPair() {
        openRowPair?.finish()
        openRowPair = nil
    }

    private func closePagePair() {
        openPagePair?.finish()
        openPagePair = nil
    }

    func closeLines() {
        closeRowPair()
        closePagePair()
    }
}

/// Two things side by side, equally wide. Rows on a card get a dividing line and keep to
/// the top, so a short row does not stretch to match a tall one; things on the page are as
/// tall as each other. With only one thing, `finish` lets it take the whole width.
final class ColumnPair: UIStackView {
    private(set) var items: [UIView] = []
    private var placeholder: UIView? = UIView()
    private var divider: UIView?
    private let topAligned: Bool

    init(first: UIView, divider colour: UIColor?) {
        topAligned = colour != nil
        super.init(frame: .zero)
        axis = .horizontal
        alignment = .fill
        spacing = topAligned ? 0 : Spacing.l
        translatesAutoresizingMaskIntoConstraints = false
        add(first)
        if let colour = colour {
            let line = UIView()
            line.backgroundColor = colour
            line.isAccessibilityElement = false
            line.widthAnchor.constraint(equalToConstant: Stroke.divider).isActive = true
            addArrangedSubview(line)
            divider = line
        }
        if let placeholder = placeholder {
            addArrangedSubview(placeholder)
            placeholder.widthAnchor.constraint(equalTo: arrangedSubviews[0].widthAnchor).isActive = true
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func fill(_ second: UIView) {
        placeholder?.removeFromSuperview()
        placeholder = nil
        add(second)
        arrangedSubviews.last!.widthAnchor.constraint(equalTo: arrangedSubviews[0].widthAnchor).isActive = true
    }

    func finish() {
        guard let placeholder = placeholder else { return }
        placeholder.removeFromSuperview()
        divider?.removeFromSuperview()
        self.placeholder = nil
    }

    private func add(_ view: UIView) {
        items.append(view)
        guard topAligned else { return addArrangedSubview(view) }
        let cell = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(view)
        let hug = view.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
        hug.priority = .defaultLow
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: cell.topAnchor),
            view.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            view.bottomAnchor.constraint(lessThanOrEqualTo: cell.bottomAnchor),
            hug,
        ])
        addArrangedSubview(cell)
    }
}

extension UIScrollView {
    /// True when there is more below or above than fits, so someone must scroll to read it.
    var overflowsVertically: Bool {
        bounds.height > 0 && contentSize.height > bounds.height + 1
    }

    /// Moves most of a screenful down or up, keeping a little of the last view in sight.
    func scrollPage(down: Bool) {
        let step = bounds.height * 0.8 * (down ? 1 : -1)
        let lowest = max(0, contentSize.height - bounds.height)
        setContentOffset(CGPoint(x: contentOffset.x, y: min(lowest, max(0, contentOffset.y + step))), animated: false)
    }
}

/// Nested stacks need the resolved width when calculating multiline label height.
private final class WrappingPanelLabel: UILabel {
    override var bounds: CGRect {
        didSet {
            if bounds.width > 0 && preferredMaxLayoutWidth != bounds.width {
                preferredMaxLayoutWidth = bounds.width
                invalidateIntrinsicContentSize()
            }
        }
    }
}

// MARK: - PanelScreenViewController

/// A screen that hosts one scrolling panel, and swaps in a fresh one when the theme,
/// a preset, the lock, Reset, or the text size changes, keeping the scroll position,
/// scanner focus, and any open adjustment page.
class PanelScreenViewController<Panel: ScrollingPanelView>: ScreenViewController {
    private(set) var panel: Panel!

    /// VoiceOver lands on the control named by `focusOnAppear`, or on the panel.
    override var announcement: Any? { focusOnAppear.flatMap { panel.control(labelled: $0) } ?? panel }

    override var settlingContent: UIView? { panel }

    /// Where Back goes.
    var backDestination: Screen { .home }

    /// The control the scanner and VoiceOver start on, by its spoken name; nil for the first.
    var focusOnAppear: String? { nil }

    /// Makes the panel. Subclasses whose panel needs more than a theme override this.
    func createPanel(frame: CGRect, theme: UITheme, fontTraits: UITraitCollection, columns: Bool) -> Panel {
        Panel(frame: frame, theme: theme, fontTraits: fontTraits, columns: columns)
    }

    /// Whether the panel goes into two columns on a wide, short screen.
    var arrangesInColumnsWhenWide: Bool { false }

    private func wantsColumns(fontTraits: UITraitCollection) -> Bool {
        arrangesInColumnsWhenWide && ScrollingPanelView.fitsColumns(in: view.bounds.size, safeArea: view.safeAreaInsets,
                                                                     traits: fontTraits)
    }

    override func loadView() {
        // The screen it replaces gives its size, so the first panel already has the right shape.
        let view = UIView(frame: parent?.view.bounds ?? .zero)
        view.backgroundColor = GameSettings.shared.selectedTheme.sceneBackgroundColor
        self.view = view
        install(makePanel(fontTraits: traitCollection, safeArea: parent?.view.safeAreaInsets))
    }

    /// Turning the phone moves the panel between one column and two.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let panel = panel, view.bounds.width > 0,
              panel.usesColumns != wantsColumns(fontTraits: view.traitCollection) else { return }
        rebuildPanel()
    }

    private func makePanel(fontTraits: UITraitCollection, safeArea: UIEdgeInsets? = nil) -> Panel {
        let columns = arrangesInColumnsWhenWide && ScrollingPanelView.fitsColumns(
            in: view.bounds.size, safeArea: safeArea ?? view.safeAreaInsets, traits: fontTraits)
        let panel = createPanel(frame: view.bounds, theme: GameSettings.shared.selectedTheme,
                                fontTraits: fontTraits, columns: columns)
        // Only this panel is read, never the empty SpriteKit view underneath.
        panel.accessibilityViewIsModal = true
        panel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        panel.onBack = { [weak self] in
            guard let self = self, !self.isChangingScreen else { return }
            self.panel.stopScanning()
            self.navigate(self.backDestination)
        }
        panel.onThemeChanged = { [weak self] in self?.rebuildPanel() }
        configure(panel)
        return panel
    }

    /// Subclasses wire their own panel callbacks here; called for every rebuilt panel.
    func configure(_ panel: Panel) { }

    private func install(_ panel: Panel) {
        view.addSubview(panel)
        self.panel = panel
    }

    private func rebuildPanel() {
        let old = panel!
        let savedOffset = old.scrollPosition
        let wasScanning = old.switchScanner.isActive
        let focusedSetting = old.focusedSetting
        let wasAdjusting = old.isAdjusting
        old.stopScanning()
        old.isUserInteractionEnabled = false
        // While it fades, the old panel must not ask for rebuilds of its own; with rapid
        // text-size changes (Control Center's slider) panels would otherwise multiply.
        old.onThemeChanged = nil
        old.onBack = nil
        old.accessibilityElementsHidden = true
        let new = makePanel(fontTraits: view.traitCollection)
        new.alpha = 0
        install(new)
        new.restoreScrollPosition(savedOffset)
        if wasScanning || GameSettings.shared.scanningEnabled {
            new.startScanning(focusing: focusedSetting)
            if wasAdjusting { new.primaryActivate() }
        } else if wasAdjusting {
            new.reopenAdjustment(labelled: focusedSetting)
        }
        view.backgroundColor = GameSettings.shared.selectedTheme.sceneBackgroundColor
        UIView.animate(withDuration: 0.25) {
            new.alpha = 1
            old.alpha = 0
        } completion: { _ in
            old.removeFromSuperview()
            ScreenChangeAnnouncer.post(new.announcementAfterRebuild)
        }
    }

    override func screenDidAppear() {
        if GameSettings.shared.scanningEnabled { panel.startScanning(focusing: focusOnAppear) }
        super.screenDidAppear()
    }

    override func screenWillDisappear() {
        panel.stopScanning()
    }

    override var scannersDuringTransition: [FocusScanner] { [panel.switchScanner] }

    override func switchPrimaryBegan() { panel.primaryActivate() }
    override func switchSecondaryBegan() { panel.secondaryAdvance() }
}
