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

// MARK: - Row builders

extension SettingsPanelView {

    func presetButtons() {
        let presets: [(String, () -> Void)] = [
            ("Gentle",    { GameSettings.shared.applyGentle() }),
            ("Standard",  { GameSettings.shared.applyStandard() }),
            ("Challenge", { GameSettings.shared.applyChallenge() }),
        ]
        let buttons = presets.map { name, action -> UIView in
            let t = ButtonTarget { [weak self] in
                action()
                self?.onThemeChanged?()
            }
            controlTargets.append(t)
            return panelButton(name, target: t, action: #selector(ButtonTarget.tapped))
        }
        let column = UIStackView(arrangedSubviews: buttons)
        column.axis = .vertical
        column.spacing = Spacing.m
        appendToPage(column)
    }

    /// The row's name, then anything after it (a slider's value), on one line.
    private func titleLine(_ title: UILabel, trailing: UIView) -> UIStackView {
        trailing.setContentHuggingPriority(.required, for: .horizontal)
        trailing.setContentCompressionResistancePriority(.required, for: .horizontal)
        let line = UIStackView(arrangedSubviews: [title, trailing])
        // At accessibility text sizes the name needs the whole width, so the value goes below.
        if (fontTraits ?? traitCollection).preferredContentSizeCategory.isAccessibilityCategory {
            line.axis = .vertical
            line.alignment = .leading
        } else {
            line.alignment = .firstBaseline
            line.spacing = Spacing.m
        }
        return line
    }

    /// A text button that opens a page with the long explanation of a setting.
    private func moreButton(about title: String, text: String) -> UIButton {
        let name = "More about \(title)"
        infoPages[name] = text
        let button = panelButton("More about this", icon: "info.circle", kind: .quiet,
                                 target: self, action: #selector(openInfoPage(_:)))
        button.accessibilityLabel = name
        // Voice Control users can say what they see.
        button.accessibilityUserInputLabels = ["More about this", name]
        return button
    }

    @objc private func openInfoPage(_ sender: UIButton) { showAdjustment(for: sender) }

    /// `more` is a longer explanation, shown on the slider's adjustment page.
    func sliderRow(_ title: String, detail: String, more: String? = nil, lo: String, hi: String,
                   min: Float, max: Float, value: Float, seconds: Bool = false,
                   onChange: @escaping (Float) -> Void) {
        let row = UIView()

        let titleL  = makeLabel(title,  style: .label, color: style.text)
        let detailL = makeLabel(detail, style: .caption,  color: style.sub)
        detailL.numberOfLines = 0

        let slider = SettingsSlider()
        slider.accessibilityRow = row
        slider.speaksSeconds = seconds
        slider.accessibilityLabel = title
        slider.accessibilityHint = "\(more ?? detail). \(lo) to \(hi). Double-tap for larger buttons."
        if let more = more { infoPages[title] = more }
        slider.onActivate = { [weak self, weak slider] in
            guard let self = self, let slider = slider, !self.isAdjusting else { return }
            self.showAdjustment(for: slider)
        }
        slider.minimumValue          = min
        slider.maximumValue          = max
        slider.value                 = value
        slider.minimumTrackTintColor = style.accentFill
        slider.maximumTrackTintColor = style.div
        slider.thumbTintColor        = style.accentFill

        // The value in the accent colour, beside the name.
        let valueL = makeLabel(slider.shortValue, style: .label, color: style.accent)
        valueL.textAlignment = .right
        let t = SliderTarget { [weak slider, weak valueL] v in
            onChange(v)
            valueL?.text = slider?.shortValue
        }
        controlTargets.append(t)
        slider.addTarget(t, action: #selector(SliderTarget.changed(_:)), for: .valueChanged)

        let loL = makeLabel(lo, style: .caption, color: style.sub)
        let hiL = makeLabel(hi, style: .caption, color: style.sub)
        hiL.textAlignment = .right

        let rangeRow = UIStackView(arrangedSubviews: [loL, hiL])
        // The slider speaks its own name, purpose, and range once.
        [titleL, valueL, detailL, rangeRow].forEach { $0.accessibilityElementsHidden = true }
        rangeRow.axis         = .horizontal
        rangeRow.distribution = .equalSpacing

        let vs = UIStackView(arrangedSubviews: [titleLine(titleL, trailing: valueL), detailL, slider, rangeRow])
        vs.axis    = .vertical
        vs.spacing = Spacing.xs
        vs.setCustomSpacing(Spacing.s, after: detailL)
        vs.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(vs)
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: row.topAnchor, constant: Spacing.l),
            vs.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -Spacing.l),
            vs.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Spacing.l),
            vs.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Spacing.l),
        ])
        appendRow(row)
    }

    /// `more` is a longer explanation. VoiceOver reads it as the switch's hint; on screen
    /// it sits behind a "More about this" button, so the row shows one short line.
    /// `hint` is what VoiceOver reads when it should differ from the short `detail`.
    func toggleRow(_ title: String, detail: String, hint: String? = nil, more: String? = nil, isOn: Bool,
                   onChange: @escaping (Bool) -> Void) {
        let row = UIView()
        // The part of the row the switch speaks for: its name, description, and itself.
        let main = UIView()

        let titleL  = makeLabel(title,  style: .label, color: style.text)
        let detailL = makeLabel(detail, style: .caption,  color: style.sub)
        detailL.numberOfLines = 0

        let lStack = UIStackView(arrangedSubviews: [titleL, detailL])
        lStack.axis    = .vertical
        lStack.spacing = Spacing.xs
        lStack.translatesAutoresizingMaskIntoConstraints = false

        let sw = SettingsSwitch()
        sw.accessibilityRow = more == nil ? row : main
        sw.accessibilityLabel = title
        sw.accessibilityHint = more ?? hint ?? detail
        // The switch speaks its own name and purpose once.
        titleL.accessibilityElementsHidden = true
        detailL.accessibilityElementsHidden = true
        sw.isOn        = isOn
        sw.onTintColor = style.accentFill
        sw.translatesAutoresizingMaskIntoConstraints = false

        let t = SwitchTarget(onChange)
        controlTargets.append(t)
        sw.addTarget(t, action: #selector(SwitchTarget.changed(_:)), for: .valueChanged)

        main.addSubview(lStack)
        main.addSubview(sw)
        NSLayoutConstraint.activate([
            lStack.topAnchor.constraint(equalTo: main.topAnchor),
            lStack.bottomAnchor.constraint(equalTo: main.bottomAnchor),
            lStack.leadingAnchor.constraint(equalTo: main.leadingAnchor),
            lStack.trailingAnchor.constraint(equalTo: sw.leadingAnchor, constant: -Spacing.m),

            sw.centerYAnchor.constraint(equalTo: main.centerYAnchor),
            sw.trailingAnchor.constraint(equalTo: main.trailingAnchor),
            main.heightAnchor.constraint(greaterThanOrEqualTo: sw.heightAnchor),
        ])
        let vs = UIStackView(arrangedSubviews: [main])
        vs.axis = .vertical
        vs.spacing = Spacing.xs
        vs.translatesAutoresizingMaskIntoConstraints = false
        if let more = more {
            // At the leading edge, under the description it expands on.
            let line = UIStackView(arrangedSubviews: [moreButton(about: title, text: more), UIView()])
            vs.addArrangedSubview(line)
        }
        row.addSubview(vs)
        // A "More about this" button brings its own space below it.
        let bottom = more == nil ? Spacing.l : Spacing.xs
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: row.topAnchor, constant: Spacing.l),
            vs.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -bottom),
            vs.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Spacing.l),
            vs.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Spacing.l),
        ])
        appendRow(row)
    }

    /// A short list of choices, one button each, with the chosen one marked. Choosing
    /// takes one press; nothing scrolls sideways.
    func choiceRow(_ title: String, detail: String, items: [String], selectedIndex: Int,
                   onChange: @escaping (Int) -> Void) {
        let row = UIView()
        let titleL  = makeLabel(title,  style: .label, color: style.text)
        let detailL = makeLabel(detail, style: .caption,  color: style.sub)
        // VoiceOver reads the name as a heading for the choices under it.
        titleL.accessibilityTraits = .header

        var buttons: [ChoiceButton] = []
        for (index, item) in items.enumerated() {
            let button = ChoiceButton(name: makeLabel(item, style: .label, color: style.text), theme: theme)
            button.isChosen = index == selectedIndex
            button.accessibilityHint = title
            let t = ButtonTarget { [weak self, weak button] in
                onChange(index)
                buttons.forEach { $0.isChosen = $0 === button }
                // Scan mode may just have changed; apply it at once, staying on this choice.
                if self?.switchScanner.isActive == true { self?.startScanning(focusing: item) }
            }
            controlTargets.append(t)
            button.addTarget(t, action: #selector(ButtonTarget.tapped), for: .touchUpInside)
            buttons.append(button)
        }
        choiceGroups[title] = buttons

        let vs = UIStackView(arrangedSubviews: [titleL, detailL] + buttons)
        vs.axis    = .vertical
        vs.spacing = Spacing.xs
        vs.setCustomSpacing(Spacing.s, after: detailL)
        vs.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(vs)
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: row.topAnchor, constant: Spacing.l),
            vs.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -Spacing.s),
            vs.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Spacing.l),
            vs.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Spacing.l),
        ])
        appendRow(row)
    }

    /// A category on the Settings menu: its picture, name, what is inside, and a chevron.
    func categoryCard(_ category: SettingsCategory) -> UIButton {
        let card = CardButton(theme: theme)
        card.accessibilityLabel = category.title
        card.accessibilityHint = category.detail

        let symbols = UIImage.SymbolConfiguration(font: font(.heading))
        let icon = UIImageView(image: UIImage(systemName: category.symbolName, withConfiguration: symbols))
        icon.tintColor = style.accent
        icon.contentMode = .center
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        // Icons differ in width; a fixed column keeps the names in line.
        icon.widthAnchor.constraint(equalToConstant: font(.heading).lineHeight * 1.4).isActive = true

        let text = UIStackView(arrangedSubviews: [makeLabel(category.title, style: .label, color: style.text),
                                                  makeLabel(category.detail, style: .caption, color: style.sub)])
        text.axis = .vertical
        text.spacing = Spacing.xs

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(font: font(.label))))
        chevron.tintColor = style.sub
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)

        let line = UIStackView(arrangedSubviews: [icon, text, chevron])
        line.alignment = .center
        line.spacing = Spacing.m
        line.isUserInteractionEnabled = false
        line.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(line)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: card.topAnchor, constant: Spacing.l),
            line.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Spacing.l - CardButton.bottomInset),
            line.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Spacing.l),
            line.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Spacing.l),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minButtonHeight + Stroke.edge),
        ])

        let t = ButtonTarget { [weak self] in self?.onOpenCategory?(category) }
        controlTargets.append(t)
        card.addTarget(t, action: #selector(ButtonTarget.tapped), for: .touchUpInside)
        return card
    }

    func paletteRow() {
        let descRow = UIView()
        let descL = makeLabel(
            "Helicopter and pipe colours for different colour vision. The menu theme is separate.",
            style: .caption, color: style.sub)
        descL.numberOfLines = 0
        descL.translatesAutoresizingMaskIntoConstraints = false
        descRow.addSubview(descL)
        NSLayoutConstraint.activate([
            descL.topAnchor.constraint(equalTo: descRow.topAnchor, constant: Spacing.l),
            descL.bottomAnchor.constraint(equalTo: descRow.bottomAnchor, constant: -Spacing.m),
            descL.leadingAnchor.constraint(equalTo: descRow.leadingAnchor, constant: Spacing.l),
            descL.trailingAnchor.constraint(equalTo: descRow.trailingAnchor, constant: -Spacing.l),
        ])
        appendRow(descRow)

        let row = UIView()

        let hScroll = UIScrollView()
        hScroll.showsHorizontalScrollIndicator = false
        hScroll.translatesAutoresizingMaskIntoConstraints = false

        let hs = UIStackView()
        hs.axis    = .horizontal
        hs.spacing = Spacing.m
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
            hs.topAnchor.constraint(equalTo: hScroll.contentLayoutGuide.topAnchor, constant: Spacing.xs),
            hs.bottomAnchor.constraint(equalTo: hScroll.contentLayoutGuide.bottomAnchor, constant: -Spacing.xs),
            hs.leadingAnchor.constraint(equalTo: hScroll.contentLayoutGuide.leadingAnchor, constant: Spacing.xs),
            hs.trailingAnchor.constraint(equalTo: hScroll.contentLayoutGuide.trailingAnchor, constant: -Spacing.xs),
            hs.heightAnchor.constraint(equalTo: hScroll.frameLayoutGuide.heightAnchor, constant: -Spacing.xs),
        ])

        row.addSubview(hScroll)
        NSLayoutConstraint.activate([
            hScroll.topAnchor.constraint(equalTo: row.topAnchor, constant: Spacing.m),
            hScroll.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -Spacing.m),
            hScroll.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Spacing.l),
            hScroll.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Spacing.l),
            hScroll.heightAnchor.constraint(equalToConstant: 50 + font(.caption).lineHeight * 3),
        ])
        appendRow(row)
    }

    private func makeSwatch(_ palette: ColorPalette, selected: Bool, index: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.widthAnchor.constraint(equalToConstant: max(100, font(.caption).pointSize * 8)).isActive = true
        styleCard(btn, chosen: selected)
        btn.accessibilityLabel = palette.name
        if selected { btn.accessibilityTraits.insert(.selected) }

        let heliDot = colorDot(palette.helicopterColor, size: 26)
        let pipeDot = colorDot(palette.pipeColor,       size: 26)
        let dots = UIStackView(arrangedSubviews: [heliDot, pipeDot])
        dots.axis         = .horizontal
        dots.spacing      = Spacing.s
        dots.distribution = .fillEqually
        dots.isUserInteractionEnabled = false

        let nameL = UILabel()
        nameL.text          = palette.name
        nameL.textColor     = style.text
        nameL.font = font(.caption)
        nameL.adjustsFontForContentSizeCategory = true
        nameL.numberOfLines = 0
        nameL.textAlignment = .center
        nameL.isUserInteractionEnabled = false

        let vs = UIStackView(arrangedSubviews: [dots, nameL])
        vs.axis      = .vertical
        vs.spacing   = Spacing.xs
        vs.alignment = .center
        vs.isUserInteractionEnabled = false
        vs.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(vs)
        NSLayoutConstraint.activate([
            nameL.widthAnchor.constraint(lessThanOrEqualTo: vs.widthAnchor),
            vs.topAnchor.constraint(equalTo: btn.topAnchor, constant: Spacing.s),
            vs.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -Spacing.s),
            vs.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: Spacing.xs),
            vs.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -Spacing.xs),
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
            styleCard(view, chosen: chosen)
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

/// One choice in a list: a mark that is filled when chosen, then the name. The chosen
/// state shows by the mark's shape as well as its colour, and as the selected trait.
final class ChoiceButton: UIButton {
    private let mark = UIImageView()
    private let theme: UITheme
    private let symbols: UIImage.SymbolConfiguration

    var isChosen = false {
        didSet {
            isSelected = isChosen
            if isChosen { accessibilityTraits.insert(.selected) } else { accessibilityTraits.remove(.selected) }
            mark.image = UIImage(systemName: isChosen ? "checkmark.circle.fill" : "circle", withConfiguration: symbols)
            mark.tintColor = isChosen ? theme.accentTextColor : theme.secondaryTextColor
        }
    }

    /// `name` is the choice's label, already in the panel's font and colour.
    init(name: UILabel, theme: UITheme) {
        self.theme = theme
        symbols = UIImage.SymbolConfiguration(font: name.font, scale: .large)
        super.init(frame: .zero)
        accessibilityLabel = name.text
        mark.setContentHuggingPriority(.required, for: .horizontal)
        mark.setContentCompressionResistancePriority(.required, for: .horizontal)
        let line = UIStackView(arrangedSubviews: [mark, name])
        line.alignment = .center
        line.spacing = Spacing.m
        line.isUserInteractionEnabled = false
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.s),
            line.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Spacing.s),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minButtonHeight),
        ])
        isChosen = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}

extension UISlider {
    /// The value as shown beside a setting's name: "37%" or "1.5 s".
    var shortValue: String {
        (self as? SettingsSlider)?.speaksSeconds == true ? String(format: "%.1f s", value) : spokenValue
    }

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
