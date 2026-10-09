import UIKit

private final class SettingsScanItem: FocusScannable {
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
        if let slider = control as? UISlider { return "\(label), \(String(format: "%.2g", slider.value)). Select to adjust." }
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

// MARK: - SettingsPanelView
// The scrolling list of settings shown by SettingsViewController. Rows are built in
// SettingsRows.swift; the switch-friendly adjustment page in SettingsAdjustmentPanel.swift.

final class SettingsPanelView: UIView {

    let fontTraits: UITraitCollection?
    let style: SettingsStyle

    var onBack: (() -> Void)?
    /// Asks the host to rebuild the panel: theme, preset, lock, reset, or text size changed.
    var onThemeChanged: (() -> Void)?

    let switchScanner = FocusScanner()
    private let focusRing = UIView()
    private(set) weak var focusedControl: UIControl?
    var adjustmentPanel: UIView?
    var adjustmentTargets: [NSObject] = []
    var returnControlLabel: String?
    private var navigationItems: [FocusScannable] = []

    // Retain targets so addTarget's weak reference doesn't dangle.
    var controlTargets: [NSObject] = []
    var paletteViews: [(UIView, String)] = []

    private let scrollView = UIScrollView()
    let stack = UIStackView()

    // MARK: - Initialization

    init(frame: CGRect, theme: UITheme, fontTraits: UITraitCollection? = nil) {
        self.fontTraits = fontTraits
        style = SettingsStyle(theme: theme)
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Switch scanning

    var focusedSetting: String? {
        returnControlLabel ?? focusedControl?.accessibilityLabel ?? (focusedControl as? UIButton)?.currentTitle
    }

    func startScanning(focusing label: String? = nil) {
        switchScanner.stop()
        navigationItems = controls(in: self).map { scanItem(for: $0) }
        switchScanner.items = navigationItems
        let index = navigationItems.firstIndex {
            let control = ($0 as? SettingsScanItem)?.control
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
        SettingsScanItem(control: control, focus: { [weak self] control, focused in
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
            guard let self = self else { return }
            if control is UISlider || control is UISegmentedControl {
                self.showAdjustment(for: control)
            } else if let toggle = control as? UISwitch {
                toggle.setOn(!toggle.isOn, animated: false)
                toggle.sendActions(for: .valueChanged)
            } else {
                control.sendActions(for: .touchUpInside)
            }
        })
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if (fontTraits ?? previousTraitCollection)?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            onThemeChanged?()
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
        let titleLbl = makeLabel("Settings", size: 26, weight: .bold, color: style.text)
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

    // MARK: - Sections

    private func buildSections() {
        let gs = GameSettings.shared

        sectionHeader("Difficulty Preset")
        presetButtons()

        sectionHeader("Gameplay")
        // Gap: gentle midpoint≈475, standard≈310, challenge≈230. Wider = easier.
        sliderRow("Gap Size",
                  detail: "How wide the opening between pipes is",
                  lo: "Narrow", hi: "Wide",
                  min: 200, max: 500,
                  value: Float((gs.gapMin + gs.gapMax) / 2)) { [weak self] v in
            self?.applyGap(CGFloat(v))
        }
        // Pipe speed: inverted so slider-right = faster pipes.
        sliderRow("Pipe Speed",
                  detail: "How fast pipes cross the screen",
                  lo: "Slow", hi: "Fast",
                  min: 4, max: 10,
                  value: Float(14 - gs.pipeMoveDuration)) { v in
            gs.pipeMoveDuration = TimeInterval(14 - Double(v))
        }
        sliderRow("Hitbox Size",
                  detail: "How closely collisions follow the helicopter's visual edge",
                  lo: "Generous", hi: "Exact",
                  min: 0.4, max: 1.0,
                  value: Float(gs.hitboxFraction)) { v in
            gs.hitboxFraction = CGFloat(v)
        }

        sectionHeader("Motion")
        sliderRow("Background Scroll",
                  detail: "Speed of the sky behind the game — independent of pipe speed",
                  lo: "Still", hi: "Fast",
                  min: 0, max: 200,
                  value: Float(gs.backgroundScrollSpeed)) { v in
            gs.backgroundScrollSpeed = Double(v)
        }

        sectionHeader("Comfort")
        toggleRow("No-Fail Mode",
                  detail: "Helicopter passes through pipes — no game over",
                  isOn: gs.noFailMode) { v in gs.noFailMode = v }
        toggleRow("Calm Mode",
                  detail: "No collision sounds or vibration on impact",
                  isOn: gs.calmMode) { v in gs.calmMode = v }
        toggleRow("Helicopter Outline",
                  detail: "Black and white contrast marker around the helicopter",
                  isOn: gs.helicopterOutline) { v in gs.helicopterOutline = v }
        toggleRow("Hide Game While Paused",
                  detail: "Use a solid background behind the pause menu to reduce distractions",
                  isOn: gs.hideGameWhilePaused) { v in gs.hideGameWhilePaused = v }
        toggleRow("Show Score",
                  detail: "Display current and best scores during play and at the end of a run",
                  isOn: gs.showScore) { v in gs.showScore = v }

        sectionHeader("Switch Access")
        toggleRow("Auto-Scan Menus",
                  detail: "Menus cycle through buttons automatically — press your switch to select",
                  isOn: gs.scanningEnabled) { v in gs.scanningEnabled = v }
        segmentedRow("Menu Scan Mode",
                     detail: "Auto-Advance cycles on a timer; Two-Switch requires a second switch press to step",
                     items: ["Auto-Advance", "Two-Switch"],
                     selectedIndex: gs.scanScheme.rawValue) { idx in
            if let scheme = ScanScheme(rawValue: idx) { gs.scanScheme = scheme }
        }
        sliderRow("Scan Dwell Time",
                  detail: "How long the scanner pauses on each button before moving on",
                  lo: "0.5 s", hi: "10 s",
                  min: 0.5, max: 10.0,
                  value: Float(gs.scanDwellTime)) { v in
            gs.scanDwellTime = TimeInterval(v)
        }
        segmentedRow("In-Game Control",
                     detail: "How you control the helicopter's altitude while playing",
                     items: ["Tap to Flap", "Hold to Hover", "Auto Hover", "Two-Switch"],
                     selectedIndex: gs.controlScheme.rawValue) { idx in
            if let scheme = ControlScheme(rawValue: idx) { gs.controlScheme = scheme }
        }

        sliderRow("Hold Switch to Pause",
                  detail: "Hold the primary switch to pause, then release before choosing a menu item. For longer hover holds, increase this delay.",
                  lo: "2 s", hi: "10 s",
                  min: 2, max: 10,
                  value: Float(gs.switchPauseHoldDuration)) { v in
            gs.switchPauseHoldDuration = TimeInterval(v)
        }

        sectionHeader("Visual Theme")
        let themes = GameSettings.allThemes
        let themeIdx = themes.firstIndex { $0.id == gs.selectedThemeID } ?? 0
        segmentedRow("Menu Theme",
                     detail: "Personal colour preference for menus and the title screen",
                     items: themes.map { $0.name },
                     selectedIndex: themeIdx) { [weak self] idx in
            guard idx < themes.count else { return }
            gs.selectedThemeID = themes[idx].id
            self?.onThemeChanged?()
        }

        sectionHeader("Colour Accessibility")
        paletteRow()

        sectionHeader("Audio")
        toggleRow("Sound Effects",
                  detail: "Play sounds during the game",
                  isOn: UserDefaults.standard.bool(for: .isSoundEffectsOn)) { v in
            UserDefaults.standard.set(v, for: .isSoundEffectsOn)
        }
        toggleRow("Music",
                  detail: "Play background music",
                  isOn: UserDefaults.standard.bool(for: .isMusicOn)) { v in
            UserDefaults.standard.set(v, for: .isMusicOn)
        }

        sectionHeader("Reset")
        let reset = plainButton("Reset Settings", color: style.accent, target: self,
                                action: #selector(showAdjustment(from:)))
        reset.accessibilityLabel = "Reset Settings"
        reset.titleLabel?.numberOfLines = 0
        reset.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        stack.addArrangedSubview(reset)

        if gs.isSettingsLocked {
            // Keep the panel and Back reachable, while preventing accidental edits.
            for row in stack.arrangedSubviews {
                row.isUserInteractionEnabled = false
                row.alpha = 0.5
            }
        }
        sectionHeader("Caregiver")
        toggleRow("Lock Settings",
                  detail: "Prevents changes to the controls above. Turn this off to edit settings.",
                  isOn: gs.isSettingsLocked) { [weak self] v in
            gs.isSettingsLocked = v
            self?.onThemeChanged?()
        }

        // Informational only, so it stays available when Settings is locked.
        sectionHeader("About")
        for title in ["Privacy Policy", "Acknowledgements"] {
            let button = plainButton(title, color: style.accent, target: self, action: #selector(showAdjustment(from:)))
            button.accessibilityLabel = title
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            stack.addArrangedSubview(button)
        }
    }

    /// Reset, Privacy Policy, and Acknowledgements open the adjustment page.
    @objc private func showAdjustment(from sender: UIButton) {
        showAdjustment(for: sender)
    }

    // MARK: - Gap helper

    private func applyGap(_ midpoint: CGFloat) {
        let spread = max(60, midpoint * 0.22)
        GameSettings.shared.gapMin = max(160, midpoint - spread)
        GameSettings.shared.gapMax = min(600, midpoint + spread)
    }
}
