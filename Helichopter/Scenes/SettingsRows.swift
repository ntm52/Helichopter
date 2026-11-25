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

/// Flips a switch when its row's name or description is tapped, so the target is the
/// whole row and not only the small switch.
final class RowTapTarget: NSObject {
    private weak var toggle: UISwitch?
    init(_ toggle: UISwitch) { self.toggle = toggle }
    @objc func tapped() {
        guard let toggle = toggle, toggle.isEnabled else { return }
        Feedback.choose()
        toggle.setOn(!toggle.isOn, animated: Feedback.allowsMovement)
        toggle.sendActions(for: .valueChanged)
    }
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
        // Side by side when the page has two columns, as they read Gentle to Challenge.
        let column = UIStackView(arrangedSubviews: buttons)
        column.axis = usesColumns ? .horizontal : .vertical
        column.distribution = usesColumns ? .fillEqually : .fill
        column.spacing = Spacing.m
        appendToPage(column, spansColumns: true)
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

    @objc private func openInfoPage(_ sender: UIButton) {
        Feedback.choose()
        showAdjustment(for: sender)
    }

    /// The button under every slider that opens its page of Decrease and Increase buttons.
    static let adjustTitle = "Adjust with buttons"

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
        slider.maximumTrackTintColor = style.track
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

        // Dragging a slider needs a steady finger; this opens the page of large Decrease
        // and Increase buttons for anyone, by touch or by saying its name.
        let open = ButtonTarget { [weak self, weak slider] in
            guard let self = self, let slider = slider, !self.isAdjusting else { return }
            self.showAdjustment(for: slider)
        }
        controlTargets.append(open)
        let adjust = panelButton(Self.adjustTitle, icon: "plusminus.circle", kind: .quiet,
                                 target: open, action: #selector(ButtonTarget.tapped))
        adjust.accessibilityLabel = "Adjust \(title) with buttons"
        adjust.accessibilityHint = "Opens larger Decrease and Increase buttons"
        adjust.accessibilityUserInputLabels = [Self.adjustTitle, "Adjust \(title)"]
        // The scanner opens the same page from the slider itself.
        scanSkipped.add(adjust)

        let vs = UIStackView(arrangedSubviews: [titleLine(titleL, trailing: valueL), detailL, slider, rangeRow,
                                                UIStackView(arrangedSubviews: [adjust, UIView()])])
        vs.axis    = .vertical
        vs.spacing = Spacing.xs
        vs.setCustomSpacing(Spacing.s, after: detailL)
        vs.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(vs)
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: row.topAnchor, constant: Spacing.l),
            // The Adjust button brings its own space below it.
            vs.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -Spacing.xs),
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

        // A tap on the name or description flips the switch too. UIKit keeps this
        // recogniser from firing for touches on the switch itself.
        let rowTap = RowTapTarget(sw)
        controlTargets.append(rowTap)
        main.addGestureRecognizer(UITapGestureRecognizer(target: rowTap, action: #selector(RowTapTarget.tapped)))

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
    /// `accessory` gives a small picture to show after a choice's name.
    func choiceRow(_ title: String, detail: String, items: [String], selectedIndex: Int,
                   accessory: ((Int) -> UIView?)? = nil, onChange: @escaping (Int) -> Void) {
        let row = UIView()
        let titleL  = makeLabel(title,  style: .label, color: style.text)
        let detailL = makeLabel(detail, style: .caption,  color: style.sub)
        // VoiceOver reads the name as a heading for the choices under it.
        titleL.accessibilityTraits = .header

        // At accessibility text sizes a name needs the whole width, so its picture goes below.
        let large = (fontTraits ?? traitCollection).preferredContentSizeCategory.isAccessibilityCategory
        var buttons: [ChoiceButton] = []
        for (index, item) in items.enumerated() {
            let button = ChoiceButton(name: makeLabel(item, style: .label, color: style.text), theme: theme,
                                      accessory: accessory?(index), accessoryBelow: large)
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

    /// A palette's helicopter and pipe colours, shown after its name. Decoration: the
    /// name is what is spoken.
    func paletteDots(_ palette: ColorPalette) -> UIView {
        let dots = UIStackView(arrangedSubviews: [colorDot(palette.helicopterColor, size: 26),
                                                  colorDot(palette.pipeColor, size: 26)])
        dots.spacing = Spacing.s
        dots.alignment = .center
        dots.isUserInteractionEnabled = false
        return dots
    }

    // MARK: Factory helpers

    private func colorDot(_ color: UIColor, size: CGFloat) -> UIView {
        // An outline, so a dot the card's own colour (white on Parchment) still shows.
        let v = DotView(fill: color, outline: style.sub)
        v.widthAnchor.constraint(equalToConstant: size).isActive = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }
}

/// A round dot of colour with a thin outline. Decoration only.
private final class DotView: UIView {
    private let fill: UIColor
    private let outline: UIColor

    init(fill: UIColor, outline: UIColor) {
        self.fill = fill
        self.outline = outline
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        let circle = UIBezierPath(ovalIn: bounds.insetBy(dx: Stroke.divider / 2, dy: Stroke.divider / 2))
        fill.setFill()
        circle.fill()
        outline.setStroke()
        circle.lineWidth = Stroke.divider
        circle.stroke()
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
    /// `accessory` is a small picture after the name, or under it when `accessoryBelow`.
    init(name: UILabel, theme: UITheme, accessory: UIView? = nil, accessoryBelow: Bool = false) {
        self.theme = theme
        symbols = UIImage.SymbolConfiguration(font: name.font, scale: .large)
        super.init(frame: .zero)
        accessibilityLabel = name.text
        mark.setContentHuggingPriority(.required, for: .horizontal)
        mark.setContentCompressionResistancePriority(.required, for: .horizontal)
        let line = UIStackView(arrangedSubviews: [mark, name])
        if let accessory = accessory, accessoryBelow {
            let column = UIStackView(arrangedSubviews: [name, accessory])
            column.axis = .vertical
            column.alignment = .leading
            column.spacing = Spacing.xs
            line.addArrangedSubview(column)
        } else if let accessory = accessory {
            accessory.setContentHuggingPriority(.required, for: .horizontal)
            accessory.setContentCompressionResistancePriority(.required, for: .horizontal)
            line.addArrangedSubview(accessory)
        }
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
