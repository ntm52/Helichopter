import UIKit

// MARK: - Control target helpers
// These wrappers let closures work as addTarget selectors while keeping a strong
// reference alive via ScrollingPanelView.controlTargets. ButtonTarget is in ScrollingPanelView.swift.

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

// MARK: - Row builders

extension SettingsPanelView {

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
            btn.padding = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
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
                   min: Float, max: Float, value: Float, seconds: Bool = false,
                   onChange: @escaping (Float) -> Void) {
        let row = UIView()
        row.backgroundColor = style.rowBg

        let titleL  = makeLabel(title,  size: 16, weight: .semibold, color: style.text)
        let detailL = makeLabel(detail, size: 12, weight: .regular,  color: style.sub)
        detailL.numberOfLines = 0

        let slider = SettingsSlider()
        slider.accessibilityRow = row
        slider.speaksSeconds = seconds
        slider.accessibilityLabel = title
        slider.accessibilityHint = "\(detail). \(lo) to \(hi). Double-tap for larger buttons."
        slider.onActivate = { [weak self, weak slider] in
            guard let self = self, let slider = slider, !self.isAdjusting else { return }
            self.showAdjustment(for: slider)
        }
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
        // The slider speaks its own name, purpose, and range once.
        [titleL, detailL, rangeRow].forEach { $0.accessibilityElementsHidden = true }
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

        let sw = SettingsSwitch()
        sw.accessibilityRow = row
        sw.accessibilityLabel = title
        sw.accessibilityHint = detail
        // The switch speaks its own name and purpose once.
        titleL.accessibilityElementsHidden = true
        detailL.accessibilityElementsHidden = true
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
            "Independent of the menu theme in the Hangar.",
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
            paletteViews.append(swatch)
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
        for (i, view) in paletteViews.enumerated() {
            let chosen = (i == index)
            if chosen { view.accessibilityTraits.insert(.selected) }
            else { view.accessibilityTraits.remove(.selected) }
            view.layer.borderWidth = chosen ? 3.0 : 1.5
            view.layer.borderColor = chosen ? style.accent.cgColor : style.div.cgColor
        }
    }

    // MARK: Factory helpers

    private func colorDot(_ color: UIColor, size: CGFloat) -> UIView {
        let v = UIView()
        v.backgroundColor    = color
        v.layer.cornerRadius = size / 2
        v.isUserInteractionEnabled = false
        v.widthAnchor.constraint(equalToConstant: size).isActive = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }
}

extension UISlider {
    /// The value as players hear and see it: "37%" of the range, or "1.5 seconds".
    var spokenValue: String {
        if (self as? SettingsSlider)?.speaksSeconds == true { return String(format: "%.1f seconds", value) }
        let range = maximumValue - minimumValue
        let fraction = range > 0 ? (value - minimumValue) / range : 0
        return "\(Int((fraction * 100).rounded()))%"
    }
}

/// A Settings slider that assistive technology activates into the adjustment page of
/// plain Decrease and Increase buttons: VoiceOver double-tap, Switch Control select, and
/// Voice Control "Tap <name>" if it activates through accessibility (unconfirmed until
/// the device pass). A finger tap does nothing new; dragging and VoiceOver swipes up and
/// down still move it directly.
final class SettingsSlider: UISlider {
    var onActivate: (() -> Void)?
    /// The row whose title and description this control speaks for.
    weak var accessibilityRow: UIView?
    /// Time settings say "1.5 seconds", not a percentage of their range.
    var speaksSeconds = false

    override var accessibilityValue: String? {
        get { spokenValue }
        set { super.accessibilityValue = newValue }
    }

    override var accessibilityFrame: CGRect {
        get { rowAccessibilityFrame(row: accessibilityRow) ?? super.accessibilityFrame }
        set { super.accessibilityFrame = newValue }
    }

    override var accessibilityActivationPoint: CGPoint {
        get { UIAccessibility.convertToScreenCoordinates(bounds, in: self).center }
        set { super.accessibilityActivationPoint = newValue }
    }

    override func accessibilityActivate() -> Bool {
        guard let onActivate = onActivate else { return false }
        onActivate()
        return true
    }
}

/// A Settings switch whose accessibility frame covers its whole row, so VoiceOver
/// finds it from the row's text; taps still land on the switch itself.
final class SettingsSwitch: UISwitch {
    weak var accessibilityRow: UIView?

    override var accessibilityFrame: CGRect {
        get { rowAccessibilityFrame(row: accessibilityRow) ?? super.accessibilityFrame }
        set { super.accessibilityFrame = newValue }
    }

    override var accessibilityActivationPoint: CGPoint {
        get { UIAccessibility.convertToScreenCoordinates(bounds, in: self).center }
        set { super.accessibilityActivationPoint = newValue }
    }
}

private extension UIView {
    /// The row's frame on screen, so touching its title or description reaches the control.
    func rowAccessibilityFrame(row: UIView?) -> CGRect? {
        guard let row = row, row.window != nil else { return nil }
        return UIAccessibility.convertToScreenCoordinates(row.bounds, in: row)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
