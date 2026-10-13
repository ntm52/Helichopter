import UIKit

// MARK: - Control target helpers
// These wrappers let closures work as addTarget selectors while keeping a strong
// reference alive via ScrollingPanelView.controlTargets.

final class ButtonTarget: NSObject {
    private let f: () -> Void
    init(_ f: @escaping () -> Void) { self.f = f }
    @objc func tapped() { f() }
}

// MARK: - Theme-derived colour tokens

/// The panel colours shared by Settings and the Hangar, derived from the active UITheme
/// so panels follow the player's chosen theme.
struct SettingsStyle {
    let bg: UIColor               // panel background
    let accent: UIColor           // section headers, back button, slider/switch track
    let text: UIColor             // primary label text
    let sub: UIColor              // secondary / detail text
    let rowBg: UIColor            // individual row backgrounds
    let div: UIColor              // hairline separators
    let segBg: UIColor            // segmented control tray background
    let selectedSegText: UIColor  // text on the highlighted segment chip
    let swatchBg: UIColor         // palette swatch card background

    init(theme: UITheme) {
        let light = Self.isLightColor(theme.sceneBackgroundColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        theme.sceneBackgroundColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        bg     = theme.sceneBackgroundColor.withAlphaComponent(0.97)
        accent = theme.titleTextColor
        text   = light ? theme.titleTextColor : .white
        sub    = light ? theme.titleTextColor.withAlphaComponent(0.75) : UIColor(white: 0.65, alpha: 1.0)
        // For dark themes: nudge the row bg slightly brighter while preserving hue.
        // For light themes: shade it slightly darker so rows read off the panel bg.
        rowBg  = light
            ? UIColor(red: r * 0.93, green: g * 0.93, blue: b * 0.93, alpha: 1.0)
            : UIColor(red: min(1, r + 0.08), green: min(1, g + 0.08), blue: min(1, b + 0.08), alpha: 1.0)
        div    = light ? UIColor(white: 0.75, alpha: 1.0) : UIColor(white: 0.22, alpha: 1.0)
        segBg  = light ? UIColor(white: 0.82, alpha: 1.0) : UIColor(white: 0.20, alpha: 1.0)
        // Selected segment text must contrast against `accent` (the tint color on the chip).
        // Light themes use a dark accent (navy) → white text reads well on it.
        // Dark themes use a light accent (sky-blue/cyan) → black text reads well on it.
        selectedSegText = light ? .white : .black
        swatchBg = light ? UIColor(white: 0.88, alpha: 1.0) : UIColor(white: 0.10, alpha: 1.0)
    }

    // Returns true when the relative luminance of `color` exceeds 0.5 (i.e. it reads as a light color).
    private static func isLightColor(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.5
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
        if let segment = control as? UISegmentedControl {
            let value = segment.titleForSegment(at: segment.selectedSegmentIndex) ?? ""
            return "\(label), \(value). Select to choose."
        }
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

    /// The heading under Back.
    class var title: String { "" }

    let fontTraits: UITraitCollection?
    let style: SettingsStyle

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
    let stack = UIStackView()

    // MARK: - Initialization

    required init(frame: CGRect, theme: UITheme, fontTraits: UITraitCollection? = nil) {
        self.fontTraits = fontTraits
        style = SettingsStyle(theme: theme)
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

    /// True while a page covers the list; a rebuild reopens it.
    var isAdjusting: Bool { false }

    /// Where VoiceOver goes once a rebuilt panel has faded in.
    var announcementAfterRebuild: Any? { self }

    // MARK: - Switch scanning

    /// The label of the control the scanner is on, so a rebuilt panel can return to it.
    var focusedSetting: String? {
        focusedControl?.accessibilityLabel ?? (focusedControl as? UIButton)?.currentTitle
    }

    func startScanning(focusing label: String? = nil) {
        switchScanner.stop()
        navigationItems = controls(in: self).map { scanItem(for: $0) }
        switchScanner.items = navigationItems
        let index = navigationItems.firstIndex {
            let control = ($0 as? PanelScanItem)?.control
            return label != nil && (control?.accessibilityLabel ?? (control as? UIButton)?.currentTitle) == label
        } ?? 0
        switchScanner.start(at: index)
    }

    func stopScanning() { switchScanner.stop() }

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
                        scroll.scrollRectToVisible(control.convert(control.bounds.insetBy(dx: -6, dy: -6), to: scroll), animated: false)
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
        focusRing.frame = control.convert(control.bounds, to: self).insetBy(dx: -4, dy: -4)
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

        let backBtn  = plainButton("◀  Back", color: style.accent, target: self,
                                   action: #selector(backTapped))
        backBtn.accessibilityLabel = "Back"
        backBtn.accessibilityHint = "Goes to the home screen"
        let titleLbl = makeLabel(Self.title, size: 26, weight: .bold, color: style.text)
        titleLbl.accessibilityTraits = .header
        titleLbl.textAlignment = .center
        let header = UIStackView(arrangedSubviews: [backBtn, titleLbl])
        header.axis = .vertical
        header.spacing = 4
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 4, left: 16, bottom: 8, right: 16)
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        let headerDiv = hairline()
        header.addSubview(headerDiv)

        scrollView.alwaysBounceVertical        = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis    = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            headerDiv.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            headerDiv.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            headerDiv.trailingAnchor.constraint(equalTo: header.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        buildSections()
        focusRing.isUserInteractionEnabled = false
        focusRing.accessibilityElementsHidden = true
        focusRing.layer.borderWidth = 3
        focusRing.layer.borderColor = style.accent.cgColor
        focusRing.layer.cornerRadius = 8
        focusRing.isHidden = true
        addSubview(focusRing)
    }

    @objc private func backTapped() { onBack?() }
}

// MARK: - Shared row builders

extension ScrollingPanelView {

    func sectionHeader(_ title: String) {
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 18).isActive = true
        stack.addArrangedSubview(spacer)

        let lbl = makeLabel(title.uppercased(), size: 12, weight: .bold, color: style.accent)
        // VoiceOver's heading rotor jumps between sections; all-caps text can be spelled out.
        lbl.accessibilityLabel = title
        lbl.accessibilityTraits = .header

        let wrap = UIView()
        wrap.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 2),
            lbl.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -2),
            lbl.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 20),
            lbl.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -20),
        ])
        stack.addArrangedSubview(wrap)
        stack.addArrangedSubview(hairline())
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

    func scaledFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFontMetrics(forTextStyle: size < 15 ? .caption1 : (size >= 22 ? .title2 : .body)).scaledFont(
            for: .systemFont(ofSize: size, weight: weight), compatibleWith: fontTraits ?? traitCollection)
    }

    func makeLabel(_ labelText: String, size: CGFloat,
                   weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = WrappingPanelLabel()
        l.setContentCompressionResistancePriority(.required, for: .vertical)
        l.text      = labelText
        l.textColor = color
        l.adjustsFontForContentSizeCategory = true
        l.font = scaledFont(size, weight: weight)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    func plainButton(_ title: String, color: UIColor,
                     target: Any, action: Selector) -> UIButton {
        let btn = DynamicTextButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = scaledFont(17, weight: .semibold)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        btn.titleLabel?.numberOfLines = 0
        btn.padding = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        btn.setTitleColor(color, for: .normal)
        btn.addTarget(target, action: action, for: .touchUpInside)
        return btn
    }

    func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = style.div
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    func appendRow(_ row: UIView) {
        stack.addArrangedSubview(row)
        stack.addArrangedSubview(hairline())
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

    override var announcement: Any? { panel }

    override func loadView() {
        let view = UIView()
        view.backgroundColor = GameSettings.shared.selectedTheme.sceneBackgroundColor
        self.view = view
        install(makePanel(fontTraits: traitCollection))
    }

    private func makePanel(fontTraits: UITraitCollection) -> Panel {
        let panel = Panel(frame: view.bounds, theme: GameSettings.shared.selectedTheme,
                          fontTraits: fontTraits)
        // Only this panel is read, never the empty SpriteKit view underneath.
        panel.accessibilityViewIsModal = true
        panel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        panel.onBack = { [weak self] in
            guard let self = self, !self.isChangingScreen else { return }
            self.panel.stopScanning()
            self.navigate(.home)
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
        if GameSettings.shared.scanningEnabled { panel.startScanning() }
        super.screenDidAppear()
    }

    override func screenWillDisappear() {
        panel.stopScanning()
    }

    override var scannersDuringTransition: [FocusScanner] { [panel.switchScanner] }

    override func switchPrimaryBegan() { panel.primaryActivate() }
    override func switchSecondaryBegan() { panel.secondaryAdvance() }
}
