import SpriteKit
import UIKit

// MARK: - Control target helpers (iOS 12 compatible)
// UIControl.addAction requires iOS 14+, so these wrappers let closures
// work as addTarget selectors while keeping a strong reference alive
// via SettingsOverlayView.controlTargets.

private final class ButtonTarget: NSObject {
    private let f: () -> Void
    init(_ f: @escaping () -> Void) { self.f = f }
    @objc func tapped() { f() }
}

private final class SliderTarget: NSObject {
    private let f: (Float) -> Void
    init(_ f: @escaping (Float) -> Void) { self.f = f }
    @objc func changed(_ sender: UISlider) { f(sender.value) }
}

private final class SwitchTarget: NSObject {
    private let f: (Bool) -> Void
    init(_ f: @escaping (Bool) -> Void) { self.f = f }
    @objc func changed(_ sender: UISwitch) { f(sender.isOn) }
}

private final class SegTarget: NSObject {
    private let f: (Int) -> Void
    init(_ f: @escaping (Int) -> Void) { self.f = f }
    @objc func changed(_ sender: UISegmentedControl) { f(sender.selectedSegmentIndex) }
}

// MARK: - SettingsOverlayView
// Full UIKit settings panel shown on top of the SpriteKit scene.
// Colors are derived from the active UITheme so the panel follows the user's chosen theme.

private final class SettingsOverlayView: UIView {

    var onBack: (() -> Void)?
    var onThemeChanged: (() -> Void)?

    var scrollPosition: CGPoint { scrollView.contentOffset }

    func restoreScrollPosition(_ offset: CGPoint) {
        // Defer one run loop so Auto Layout has computed the content size first.
        DispatchQueue.main.async { [weak self] in
            self?.scrollView.contentOffset = offset
        }
    }

    // MARK: Theme-derived color tokens
    private let bg:              UIColor   // panel background
    private let accent:          UIColor   // section headers, back button, slider/switch track
    private let text:            UIColor   // primary label text
    private let sub:             UIColor   // secondary / detail text
    private let rowBg:           UIColor   // individual row backgrounds
    private let div:             UIColor   // hairline separators
    private let segBg:           UIColor   // segmented control tray background
    private let selectedSegText: UIColor   // text on the highlighted segment chip
    private let swatchBg:        UIColor   // palette swatch card background

    // Retain targets so addTarget's weak reference doesn't dangle.
    private var controlTargets: [NSObject] = []
    private var paletteViews: [(UIView, String)] = []

    private let scrollView = UIScrollView()
    private let stack      = UIStackView()

    // MARK: - Initialization

    init(frame: CGRect, theme: UITheme) {
        let light = SettingsOverlayView.isLightColor(theme.sceneBackgroundColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        theme.sceneBackgroundColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        bg     = theme.sceneBackgroundColor.withAlphaComponent(0.97)
        accent = theme.titleTextColor
        text   = light ? theme.titleTextColor : .white
        sub    = light ? theme.titleTextColor.withAlphaComponent(0.6) : UIColor(white: 0.65, alpha: 1.0)
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

        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) {
        let theme = GameSettings.shared.selectedTheme
        let light = SettingsOverlayView.isLightColor(theme.sceneBackgroundColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        theme.sceneBackgroundColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        bg     = theme.sceneBackgroundColor.withAlphaComponent(0.97)
        accent = theme.titleTextColor
        text   = light ? theme.titleTextColor : .white
        sub    = light ? theme.titleTextColor.withAlphaComponent(0.6) : UIColor(white: 0.65, alpha: 1.0)
        rowBg  = light
            ? UIColor(red: r * 0.93, green: g * 0.93, blue: b * 0.93, alpha: 1.0)
            : UIColor(red: min(1, r + 0.08), green: min(1, g + 0.08), blue: min(1, b + 0.08), alpha: 1.0)
        div    = light ? UIColor(white: 0.75, alpha: 1.0) : UIColor(white: 0.22, alpha: 1.0)
        segBg  = light ? UIColor(white: 0.82, alpha: 1.0) : UIColor(white: 0.20, alpha: 1.0)
        selectedSegText = light ? .white : .black
        swatchBg = light ? UIColor(white: 0.88, alpha: 1.0) : UIColor(white: 0.10, alpha: 1.0)

        super.init(coder: coder)
        buildUI()
    }

    // Returns true when the relative luminance of `color` exceeds 0.5 (i.e. it reads as a light color).
    private static func isLightColor(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.5
    }

    private func buildUI() {
        backgroundColor = bg

        let backBtn  = plainButton("◀  Back", color: accent, target: self,
                                   action: #selector(backTapped))
        let titleLbl = makeLabel("Settings", size: 26, weight: .bold, color: text)
        titleLbl.textAlignment = .center

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        [backBtn, titleLbl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview($0)
        }
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
            header.heightAnchor.constraint(equalToConstant: 52),

            backBtn.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            backBtn.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),

            titleLbl.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLbl.centerYAnchor.constraint(equalTo: header.centerYAnchor),

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
    }

    @objc private func backTapped() { onBack?() }

    // MARK: - Section building

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
        toggleRow("Show Score",
                  detail: "Display score during play and at the end of a run",
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

        sectionHeader("Caregiver")
        toggleRow("Lock Settings",
                  detail: "Disables the settings button on the title screen — open settings again to unlock",
                  isOn: gs.isSettingsLocked) { v in gs.isSettingsLocked = v }
    }

    // MARK: - Row builders

    private func sectionHeader(_ title: String) {
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 18).isActive = true
        stack.addArrangedSubview(spacer)

        let attrStr = NSAttributedString(string: title.uppercased(), attributes: [
            .foregroundColor: accent,
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .kern: 1.5,
        ])
        let lbl = UILabel()
        lbl.attributedText = attrStr
        lbl.translatesAutoresizingMaskIntoConstraints = false

        let wrap = UIView()
        wrap.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 2),
            lbl.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -2),
            lbl.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 20),
        ])
        stack.addArrangedSubview(wrap)
        stack.addArrangedSubview(hairline())
    }

    private func presetButtons() {
        let row = UIView()
        row.backgroundColor = rowBg

        let hs = UIStackView()
        hs.axis         = .horizontal
        hs.distribution = .fillEqually
        hs.spacing      = 10
        hs.translatesAutoresizingMaskIntoConstraints = false

        let presets: [(String, UIColor, () -> Void)] = [
            ("Gentle",    UIColor(red: 0.20, green: 0.73, blue: 0.20, alpha: 1), { GameSettings.shared.applyGentle() }),
            ("Standard",  UIColor(red: 0.20, green: 0.50, blue: 1.00, alpha: 1), { GameSettings.shared.applyStandard() }),
            ("Challenge", UIColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1), { GameSettings.shared.applyChallenge() }),
        ]
        for (name, color, action) in presets {
            let t = ButtonTarget(action)
            controlTargets.append(t)
            let btn = UIButton(type: .system)
            btn.setTitle(name, for: .normal)
            btn.titleLabel?.font   = .systemFont(ofSize: 15, weight: .semibold)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor    = color.withAlphaComponent(0.30)
            btn.layer.cornerRadius = 10
            btn.layer.borderWidth  = 1.5
            btn.layer.borderColor  = color.withAlphaComponent(0.70).cgColor
            btn.heightAnchor.constraint(equalToConstant: 48).isActive = true
            btn.addTarget(t, action: #selector(ButtonTarget.tapped), for: .touchUpInside)
            hs.addArrangedSubview(btn)
        }

        row.addSubview(hs)
        NSLayoutConstraint.activate([
            hs.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            hs.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -14),
            hs.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            hs.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
        ])
        appendRow(row)
    }

    private func sliderRow(_ title: String, detail: String, lo: String, hi: String,
                            min: Float, max: Float, value: Float,
                            onChange: @escaping (Float) -> Void) {
        let row = UIView()
        row.backgroundColor = rowBg

        let titleL  = makeLabel(title,  size: 16, weight: .semibold, color: text)
        let detailL = makeLabel(detail, size: 12, weight: .regular,  color: sub)
        detailL.numberOfLines = 0

        let slider = UISlider()
        slider.minimumValue          = min
        slider.maximumValue          = max
        slider.value                 = value
        slider.minimumTrackTintColor = accent
        slider.maximumTrackTintColor = UIColor(white: 0.3, alpha: 1.0)
        slider.thumbTintColor        = accent

        let t = SliderTarget(onChange)
        controlTargets.append(t)
        slider.addTarget(t, action: #selector(SliderTarget.changed(_:)), for: .valueChanged)

        let loL = makeLabel(lo, size: 11, weight: .regular, color: sub)
        let hiL = makeLabel(hi, size: 11, weight: .regular, color: sub)
        hiL.textAlignment = .right

        let rangeRow = UIStackView(arrangedSubviews: [loL, hiL])
        rangeRow.axis         = .horizontal
        rangeRow.distribution = .equalSpacing

        let vs = UIStackView(arrangedSubviews: [titleL, detailL, slider, rangeRow])
        vs.axis    = .vertical
        vs.spacing = 5
        vs.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(vs)
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            vs.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -14),
            vs.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            vs.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
        ])
        appendRow(row)
    }

    private func toggleRow(_ title: String, detail: String, isOn: Bool,
                            onChange: @escaping (Bool) -> Void) {
        let row = UIView()
        row.backgroundColor = rowBg

        let titleL  = makeLabel(title,  size: 16, weight: .semibold, color: text)
        let detailL = makeLabel(detail, size: 12, weight: .regular,  color: sub)
        detailL.numberOfLines = 0

        let lStack = UIStackView(arrangedSubviews: [titleL, detailL])
        lStack.axis    = .vertical
        lStack.spacing = 2
        lStack.translatesAutoresizingMaskIntoConstraints = false

        let sw = UISwitch()
        sw.isOn        = isOn
        sw.onTintColor = accent
        sw.translatesAutoresizingMaskIntoConstraints = false

        let t = SwitchTarget(onChange)
        controlTargets.append(t)
        sw.addTarget(t, action: #selector(SwitchTarget.changed(_:)), for: .valueChanged)

        row.addSubview(lStack)
        row.addSubview(sw)
        NSLayoutConstraint.activate([
            lStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            lStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -14),
            lStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            lStack.trailingAnchor.constraint(equalTo: sw.leadingAnchor, constant: -12),

            sw.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            sw.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
        ])
        appendRow(row)
    }

    private func segmentedRow(_ title: String, detail: String,
                               items: [String], selectedIndex: Int,
                               onChange: @escaping (Int) -> Void) {
        let row = UIView()
        row.backgroundColor = rowBg

        let titleL  = makeLabel(title,  size: 16, weight: .semibold, color: text)
        let detailL = makeLabel(detail, size: 12, weight: .regular,  color: sub)
        detailL.numberOfLines = 0

        let seg = UISegmentedControl(items: items)
        seg.selectedSegmentIndex     = selectedIndex
        seg.backgroundColor          = segBg
        seg.selectedSegmentTintColor = accent
        seg.setTitleTextAttributes([.foregroundColor: sub], for: .normal)
        seg.setTitleTextAttributes([
            .foregroundColor: selectedSegText,
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
        ], for: .selected)

        let t = SegTarget(onChange)
        controlTargets.append(t)
        seg.addTarget(t, action: #selector(SegTarget.changed(_:)), for: .valueChanged)

        let vs = UIStackView(arrangedSubviews: [titleL, detailL, seg])
        vs.axis    = .vertical
        vs.spacing = 8
        vs.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(vs)
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            vs.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -14),
            vs.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            vs.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
        ])
        appendRow(row)
    }

    private func paletteRow() {
        let descRow = UIView()
        descRow.backgroundColor = rowBg
        let descL = makeLabel(
            "Adjusts helicopter and pipe colours to suit different colour vision needs. " +
            "Independent of the menu theme above.",
            size: 12, weight: .regular, color: sub)
        descL.numberOfLines = 0
        descL.translatesAutoresizingMaskIntoConstraints = false
        descRow.addSubview(descL)
        NSLayoutConstraint.activate([
            descL.topAnchor.constraint(equalTo: descRow.topAnchor, constant: 10),
            descL.bottomAnchor.constraint(equalTo: descRow.bottomAnchor, constant: -10),
            descL.leadingAnchor.constraint(equalTo: descRow.leadingAnchor, constant: 20),
            descL.trailingAnchor.constraint(equalTo: descRow.trailingAnchor, constant: -20),
        ])
        stack.addArrangedSubview(descRow)
        stack.addArrangedSubview(hairline())

        let row = UIView()
        row.backgroundColor = rowBg

        let hScroll = UIScrollView()
        hScroll.showsHorizontalScrollIndicator = false
        hScroll.translatesAutoresizingMaskIntoConstraints = false

        let hs = UIStackView()
        hs.axis    = .horizontal
        hs.spacing = 12
        hs.translatesAutoresizingMaskIntoConstraints = false
        hScroll.addSubview(hs)

        paletteViews = []
        let currentID = GameSettings.shared.selectedPaletteID
        for (i, palette) in GameSettings.allPalettes.enumerated() {
            let swatch = makeSwatch(palette, selected: palette.id == currentID, index: i)
            hs.addArrangedSubview(swatch)
            paletteViews.append((swatch, palette.id))
        }

        NSLayoutConstraint.activate([
            hs.topAnchor.constraint(equalTo: hScroll.contentLayoutGuide.topAnchor, constant: 2),
            hs.bottomAnchor.constraint(equalTo: hScroll.contentLayoutGuide.bottomAnchor, constant: -2),
            hs.leadingAnchor.constraint(equalTo: hScroll.contentLayoutGuide.leadingAnchor, constant: 4),
            hs.trailingAnchor.constraint(equalTo: hScroll.contentLayoutGuide.trailingAnchor, constant: -4),
            hs.heightAnchor.constraint(equalTo: hScroll.frameLayoutGuide.heightAnchor, constant: -4),
        ])

        row.addSubview(hScroll)
        NSLayoutConstraint.activate([
            hScroll.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            hScroll.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
            hScroll.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            hScroll.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            hScroll.heightAnchor.constraint(equalToConstant: 88),
        ])
        appendRow(row)
    }

    private func makeSwatch(_ palette: ColorPalette, selected: Bool, index: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.widthAnchor.constraint(equalToConstant: 72).isActive = true
        btn.layer.cornerRadius = 12
        btn.layer.borderWidth  = selected ? 3.0 : 1.5
        btn.layer.borderColor  = selected ? accent.cgColor : div.cgColor
        btn.backgroundColor    = swatchBg
        btn.accessibilityLabel = palette.name

        let heliDot = colorDot(palette.helicopterColor, size: 26)
        let pipeDot = colorDot(palette.pipeColor,       size: 26)
        let dots = UIStackView(arrangedSubviews: [heliDot, pipeDot])
        dots.axis         = .horizontal
        dots.spacing      = 6
        dots.distribution = .fillEqually
        dots.isUserInteractionEnabled = false

        let nameL = UILabel()
        nameL.text          = palette.name
        nameL.textColor     = sub
        nameL.font          = .systemFont(ofSize: 9, weight: .medium)
        nameL.numberOfLines = 2
        nameL.textAlignment = .center
        nameL.isUserInteractionEnabled = false

        let vs = UIStackView(arrangedSubviews: [dots, nameL])
        vs.axis      = .vertical
        vs.spacing   = 4
        vs.alignment = .center
        vs.isUserInteractionEnabled = false
        vs.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(vs)
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: btn.topAnchor, constant: 8),
            vs.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -6),
            vs.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 4),
            vs.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -4),
        ])

        let t = ButtonTarget { [weak self] in self?.selectPalette(atIndex: index) }
        controlTargets.append(t)
        btn.addTarget(t, action: #selector(ButtonTarget.tapped), for: .touchUpInside)

        return btn
    }

    // MARK: - Palette selection

    private func selectPalette(atIndex index: Int) {
        guard index < GameSettings.allPalettes.count else { return }
        GameSettings.shared.selectedPaletteID = GameSettings.allPalettes[index].id
        for (i, (view, _)) in paletteViews.enumerated() {
            let chosen = (i == index)
            view.layer.borderWidth = chosen ? 3.0 : 1.5
            view.layer.borderColor = chosen ? accent.cgColor : div.cgColor
        }
    }

    // MARK: - Factory helpers

    private func makeLabel(_ labelText: String, size: CGFloat,
                            weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text      = labelText
        l.textColor = color
        l.font      = .systemFont(ofSize: size, weight: weight)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func plainButton(_ title: String, color: UIColor,
                              target: Any, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.setTitleColor(color, for: .normal)
        btn.addTarget(target, action: action, for: .touchUpInside)
        return btn
    }

    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = div
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func colorDot(_ color: UIColor, size: CGFloat) -> UIView {
        let v = UIView()
        v.backgroundColor    = color
        v.layer.cornerRadius = size / 2
        v.isUserInteractionEnabled = false
        v.widthAnchor.constraint(equalToConstant: size).isActive = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }

    private func appendRow(_ row: UIView) {
        stack.addArrangedSubview(row)
        stack.addArrangedSubview(hairline())
    }

    // MARK: - Gap helper

    private func applyGap(_ midpoint: CGFloat) {
        let spread = max(60, midpoint * 0.22)
        GameSettings.shared.gapMin = max(160, midpoint - spread)
        GameSettings.shared.gapMax = min(600, midpoint + spread)
    }
}

// MARK: - SettingsScene

class SettingsScene: RoutingUtilityScene, ToggleButtonNodeResponderType, TriggleButtonNodeResponderType {

    private weak var settingsOverlay: SettingsOverlayView?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        // Immediately hide all .sks content so it doesn't flash through the SpriteKit
        // push transition before the UIKit overlay appears.
        children.forEach { $0.isHidden = true }
        backgroundColor = GameSettings.shared.selectedTheme.sceneBackgroundColor
        // Stop the SpriteKit scanner — the UIKit overlay owns all interaction here.
        focusScanner?.stop()
        showOverlay(in: view)
    }

    override func willMove(from view: SKView) {
        settingsOverlay?.removeFromSuperview()
        settingsOverlay = nil
        super.willMove(from: view)
    }

    // MARK: - Overlay management

    private func showOverlay(in view: SKView) {
        let overlay = makeOverlay(in: view)
        view.addSubview(overlay)
        settingsOverlay = overlay
    }

    private func makeOverlay(in view: SKView) -> SettingsOverlayView {
        let overlay = SettingsOverlayView(frame: view.bounds,
                                          theme: GameSettings.shared.selectedTheme)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onBack = { [weak self, weak view] in self?.navigateBack(from: view) }
        overlay.onThemeChanged = { [weak self, weak view, weak overlay] in
            guard let self = self, let view = view else { return }
            let savedOffset = overlay?.scrollPosition ?? .zero
            let newOverlay = self.makeOverlay(in: view)
            newOverlay.alpha = 0
            view.addSubview(newOverlay)
            newOverlay.restoreScrollPosition(savedOffset)
            self.backgroundColor = GameSettings.shared.selectedTheme.sceneBackgroundColor
            UIView.animate(withDuration: 0.25) {
                newOverlay.alpha = 1
                overlay?.alpha = 0
            } completion: { _ in
                overlay?.removeFromSuperview()
                self.settingsOverlay = newOverlay
            }
        }
        return overlay
    }

    private func navigateBack(from view: SKView?) {
        guard let view = view else { return }
        UIView.animate(withDuration: 0.15) { [weak self] in
            self?.settingsOverlay?.alpha = 0
        } completion: { [weak self, weak view] _ in
            self?.settingsOverlay?.removeFromSuperview()
            self?.settingsOverlay = nil
            guard let view = view,
                  let scene = TitleScene(fileNamed: Scenes.title.getName()) else { return }
            scene.scaleMode = RoutingUtilityScene.sceneScaleMode
            var fade = UIAccessibility.isReduceMotionEnabled
            if #available(iOS 14.0, *) { fade = fade || UIAccessibility.prefersCrossFadeTransitions }
            let tx = SKTransition.fade(withDuration: fade ? 0.4 : 1.0)
            tx.pausesIncomingScene = false
            tx.pausesOutgoingScene = false
            view.presentScene(scene, transition: tx)
        }
    }

    // MARK: - SpriteKit protocol conformance (fallback if .sks buttons appear behind overlay)

    func toggleButtonTriggered(toggle: ToggleButtonNode) {
        switch toggle.type {
        case "SoundEffects": UserDefaults.standard.set(toggle.isOn, for: .isSoundEffectsOn)
        case "Music":        UserDefaults.standard.set(toggle.isOn, for: .isMusicOn)
        case "PipeDistance":
            if toggle.isOn {
                GameSettings.shared.gapMin = 350; GameSettings.shared.gapMax = 600
            } else {
                GameSettings.shared.gapMin = GameSettings.standardPreset.gapMin
                GameSettings.shared.gapMax = GameSettings.standardPreset.gapMax
            }
        case "NoFail":    GameSettings.shared.noFailMode = toggle.isOn
        case "CalmMode":  GameSettings.shared.calmMode   = toggle.isOn
        case "ShowScore": GameSettings.shared.showScore  = toggle.isOn
        default: break
        }
    }

    func triggleButtonTriggered(triggle: TriggleButtonNode) {
        let level = triggle.triggle.toDifficultyLevel()
        switch level {
        case .easy:   GameSettings.shared.applyGentle()
        case .medium: GameSettings.shared.applyStandard()
        case .hard:   GameSettings.shared.applyChallenge()
        }
        UserDefaults.standard.set(difficultyLevel: level)
    }
}
