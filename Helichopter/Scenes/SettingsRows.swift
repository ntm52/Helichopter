import UIKit

// MARK: - Control target helpers
// These wrappers let closures work as addTarget selectors while keeping a strong
// reference alive via SettingsPanelView.controlTargets.

final class ButtonTarget: NSObject {
    private let f: () -> Void
    init(_ f: @escaping () -> Void) { self.f = f }
    @objc func tapped() { f() }
}

final class SliderTarget: NSObject {
    private let f: (Float) -> Void
    init(_ f: @escaping (Float) -> Void) { self.f = f }
    @objc func changed(_ sender: UISlider) { f(sender.value) }
}

final class SwitchTarget: NSObject {
    private let f: (Bool) -> Void
    init(_ f: @escaping (Bool) -> Void) { self.f = f }
    @objc func changed(_ sender: UISwitch) { f(sender.isOn) }
}

final class SegTarget: NSObject {
    private let f: (Int) -> Void
    init(_ f: @escaping (Int) -> Void) { self.f = f }
    @objc func changed(_ sender: UISegmentedControl) { f(sender.selectedSegmentIndex) }
}

// MARK: - Theme-derived colour tokens

/// The Settings colours, derived from the active UITheme so the panel follows the
/// player's chosen theme.
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

// MARK: - Row builders

extension SettingsPanelView {

    func sectionHeader(_ title: String) {
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 18).isActive = true
        stack.addArrangedSubview(spacer)

        let lbl = makeLabel(title.uppercased(), size: 12, weight: .bold, color: style.accent)

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

    func presetButtons() {
        let row = UIView()
        row.backgroundColor = style.rowBg

        let hs = UIStackView()
        hs.axis         = .vertical
        hs.distribution = .fillEqually
        hs.spacing      = 10
        hs.translatesAutoresizingMaskIntoConstraints = false

        let presets: [(String, UIColor, () -> Void)] = [
            ("Gentle",    UIColor(red: 0.20, green: 0.73, blue: 0.20, alpha: 1), { GameSettings.shared.applyGentle() }),
            ("Standard",  UIColor(red: 0.20, green: 0.50, blue: 1.00, alpha: 1), { GameSettings.shared.applyStandard() }),
            ("Challenge", UIColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1), { GameSettings.shared.applyChallenge() }),
        ]
        for (name, color, action) in presets {
            let t = ButtonTarget { [weak self] in
                action()
                self?.onThemeChanged?()
            }
            controlTargets.append(t)
            let btn = DynamicTextButton(type: .system)
            btn.setTitle(name, for: .normal)
            btn.titleLabel?.font = scaledFont(15, weight: .semibold)
            btn.titleLabel?.adjustsFontForContentSizeCategory = true
            btn.titleLabel?.numberOfLines = 0
            btn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            // Theme text, not white: white on the pale Parchment tint measured under 2:1.
            btn.setTitleColor(style.text, for: .normal)
            btn.backgroundColor    = color.withAlphaComponent(0.30)
            btn.layer.cornerRadius = 10
            btn.layer.borderWidth  = 1.5
            btn.layer.borderColor  = color.withAlphaComponent(0.70).cgColor
            btn.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
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

    func sliderRow(_ title: String, detail: String, lo: String, hi: String,
                   min: Float, max: Float, value: Float,
                   onChange: @escaping (Float) -> Void) {
        let row = UIView()
        row.backgroundColor = style.rowBg

        let titleL  = makeLabel(title,  size: 16, weight: .semibold, color: style.text)
        let detailL = makeLabel(detail, size: 12, weight: .regular,  color: style.sub)
        detailL.numberOfLines = 0

        let slider = UISlider()
        slider.accessibilityLabel = title
        slider.accessibilityHint = detail
        slider.minimumValue          = min
        slider.maximumValue          = max
        slider.value                 = value
        slider.minimumTrackTintColor = style.accent
        slider.maximumTrackTintColor = UIColor(white: 0.3, alpha: 1.0)
        slider.thumbTintColor        = style.accent

        let t = SliderTarget(onChange)
        controlTargets.append(t)
        slider.addTarget(t, action: #selector(SliderTarget.changed(_:)), for: .valueChanged)

        let loL = makeLabel(lo, size: 11, weight: .regular, color: style.sub)
        let hiL = makeLabel(hi, size: 11, weight: .regular, color: style.sub)
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

    func toggleRow(_ title: String, detail: String, isOn: Bool,
                   onChange: @escaping (Bool) -> Void) {
        let row = UIView()
        row.backgroundColor = style.rowBg

        let titleL  = makeLabel(title,  size: 16, weight: .semibold, color: style.text)
        let detailL = makeLabel(detail, size: 12, weight: .regular,  color: style.sub)
        detailL.numberOfLines = 0

        let lStack = UIStackView(arrangedSubviews: [titleL, detailL])
        lStack.axis    = .vertical
        lStack.spacing = 2
        lStack.translatesAutoresizingMaskIntoConstraints = false

        let sw = UISwitch()
        sw.accessibilityLabel = title
        sw.accessibilityHint = detail
        sw.isOn        = isOn
        sw.onTintColor = style.accent
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

    func segmentedRow(_ title: String, detail: String,
                      items: [String], selectedIndex: Int,
                      onChange: @escaping (Int) -> Void) {
        let row = UIView()
        row.backgroundColor = style.rowBg

        let titleL  = makeLabel(title,  size: 16, weight: .semibold, color: style.text)
        let detailL = makeLabel(detail, size: 12, weight: .regular,  color: style.sub)
        detailL.numberOfLines = 0

        let seg = UISegmentedControl(items: items)
        seg.accessibilityLabel = title
        seg.selectedSegmentIndex     = selectedIndex
        seg.backgroundColor          = style.segBg
        seg.selectedSegmentTintColor = style.accent
        let segmentFont = scaledFont(16, weight: .semibold)
        seg.setTitleTextAttributes([.foregroundColor: style.sub, .font: segmentFont], for: .normal)
        seg.setTitleTextAttributes([
            .foregroundColor: style.selectedSegText,
            .font: segmentFont,
        ], for: .selected)

        let t = SegTarget(onChange)
        controlTargets.append(t)
        seg.addTarget(t, action: #selector(SegTarget.changed(_:)), for: .valueChanged)

        let segmentScroll = UIScrollView()
        segmentScroll.showsHorizontalScrollIndicator = true
        segmentScroll.addSubview(seg)
        seg.translatesAutoresizingMaskIntoConstraints = false
        let itemWidth = items.map { ($0 as NSString).size(withAttributes: [.font: segmentFont]).width + 32 }.max() ?? 80
        NSLayoutConstraint.activate([
            seg.leadingAnchor.constraint(equalTo: segmentScroll.contentLayoutGuide.leadingAnchor),
            seg.trailingAnchor.constraint(equalTo: segmentScroll.contentLayoutGuide.trailingAnchor),
            seg.topAnchor.constraint(equalTo: segmentScroll.contentLayoutGuide.topAnchor),
            seg.bottomAnchor.constraint(equalTo: segmentScroll.contentLayoutGuide.bottomAnchor),
            seg.widthAnchor.constraint(equalToConstant: itemWidth * CGFloat(items.count)),
            seg.heightAnchor.constraint(equalTo: segmentScroll.frameLayoutGuide.heightAnchor),
            segmentScroll.heightAnchor.constraint(equalToConstant: Swift.max(44, segmentFont.lineHeight + 24))
        ])
        let vs = UIStackView(arrangedSubviews: [titleL, detailL, segmentScroll])
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

    func paletteRow() {
        let descRow = UIView()
        descRow.backgroundColor = style.rowBg
        let descL = makeLabel(
            "Adjusts helicopter and pipe colours to suit different colour vision needs. " +
            "Independent of the menu theme above.",
            size: 12, weight: .regular, color: style.sub)
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
        row.backgroundColor = style.rowBg

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
            hScroll.heightAnchor.constraint(equalToConstant: 50 + scaledFont(12, weight: .medium).lineHeight * 3),
        ])
        appendRow(row)
    }

    private func makeSwatch(_ palette: ColorPalette, selected: Bool, index: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.widthAnchor.constraint(equalToConstant: max(100, scaledFont(12, weight: .medium).pointSize * 8)).isActive = true
        btn.layer.cornerRadius = 12
        btn.layer.borderWidth  = selected ? 3.0 : 1.5
        btn.layer.borderColor  = selected ? style.accent.cgColor : style.div.cgColor
        btn.backgroundColor    = style.swatchBg
        btn.accessibilityLabel = palette.name
        if selected { btn.accessibilityTraits.insert(.selected) }

        let heliDot = colorDot(palette.helicopterColor, size: 26)
        let pipeDot = colorDot(palette.pipeColor,       size: 26)
        let dots = UIStackView(arrangedSubviews: [heliDot, pipeDot])
        dots.axis         = .horizontal
        dots.spacing      = 6
        dots.distribution = .fillEqually
        dots.isUserInteractionEnabled = false

        let nameL = UILabel()
        nameL.text          = palette.name
        nameL.textColor     = style.sub
        nameL.font = scaledFont(12, weight: .medium)
        nameL.adjustsFontForContentSizeCategory = true
        nameL.numberOfLines = 0
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
            nameL.widthAnchor.constraint(lessThanOrEqualTo: vs.widthAnchor),
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

    // MARK: Palette selection

    private func selectPalette(atIndex index: Int) {
        guard index < GameSettings.allPalettes.count else { return }
        GameSettings.shared.selectedPaletteID = GameSettings.allPalettes[index].id
        for (i, (view, _)) in paletteViews.enumerated() {
            let chosen = (i == index)
            if chosen { view.accessibilityTraits.insert(.selected) }
            else { view.accessibilityTraits.remove(.selected) }
            view.layer.borderWidth = chosen ? 3.0 : 1.5
            view.layer.borderColor = chosen ? style.accent.cgColor : style.div.cgColor
        }
    }

    // MARK: Factory helpers

    func scaledFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFontMetrics(forTextStyle: size < 15 ? .caption1 : (size >= 22 ? .title2 : .body)).scaledFont(
            for: .systemFont(ofSize: size, weight: weight), compatibleWith: fontTraits ?? traitCollection)
    }

    func makeLabel(_ labelText: String, size: CGFloat,
                   weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = WrappingSettingsLabel()
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
        btn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
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
}

/// Nested stacks need the resolved width when calculating multiline label height.
private final class WrappingSettingsLabel: UILabel {
    override var bounds: CGRect {
        didSet {
            if bounds.width > 0 && preferredMaxLayoutWidth != bounds.width {
                preferredMaxLayoutWidth = bounds.width
                invalidateIntrinsicContentSize()
            }
        }
    }
}
