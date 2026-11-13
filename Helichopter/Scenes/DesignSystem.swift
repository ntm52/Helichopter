import UIKit

// MARK: - Design tokens (Plan 03, direction "Bold arcade")
// One spacing scale, two radii, three stroke widths, five text styles, and three kinds
// of button. Screens take sizes from here and colours from `UITheme`, never their own.

/// The spacing scale, in points.
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum Radius {
    /// Buttons, chips, and other controls.
    static let control: CGFloat = 18
    /// Cards and panels.
    static let card: CGFloat = 20
    /// Small pictures inside a card.
    static let inner: CGFloat = 12
}

enum Stroke {
    /// The ink outline around controls and cards.
    static let outline: CGFloat = 3
    /// The solid lower edge that makes a button look pressable.
    static let edge: CGFloat = 6
    /// The scanner's focus border.
    static let focus: CGFloat = 4
    /// Dividers between rows.
    static let divider: CGFloat = 1
    /// How far a pressed button's face sinks onto its lower edge.
    static let press: CGFloat = 4
}

/// What the app does in answer to a touch or a choice: a light tap of the haptic motor,
/// and things that move. Calm Mode turns off both; Reduce Motion turns off the movement.
enum Feedback {
    /// Read whenever something is about to move; tests replace it.
    static var prefersReducedMotion: () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    /// Plays the choose haptic; tests replace it to count choices.
    static var playChoose: () -> Void = { chooseGenerator.impactOccurred() }
    private static let chooseGenerator = UIImpactFeedbackGenerator(style: .light)

    /// True when buttons may sink and screens may settle; otherwise they only fade or dim.
    static var allowsMovement: Bool { !prefersReducedMotion() && !GameSettings.shared.calmMode }

    /// The light haptic for a choice the player has just made. Silent in Calm Mode.
    static func choose() {
        guard !GameSettings.shared.calmMode else { return }
        playChoose()
    }
}

enum Layout {
    /// Content never grows wider than this, so iPad screens are not stretched.
    static let maxContentWidth: CGFloat = 560
    /// The smallest height of any button.
    static let minButtonHeight: CGFloat = 56
    /// The smallest height of a large button, such as Play on Home.
    static let largeButtonHeight: CGFloat = 86
}

/// The type scale: SF Rounded, scaled by Dynamic Type up to the largest accessibility size.
enum TypeStyle {
    /// The "Helichopter" wordmark on Home, and the score on Round Over.
    case wordmark
    /// Screen titles.
    case display
    /// Section headings and page titles inside a panel.
    case heading
    /// Running text.
    case body
    /// Button titles and the names of settings.
    case label
    /// Descriptions and other secondary text.
    case caption

    private var size: CGFloat {
        switch self {
        case .wordmark: return 46
        case .display: return 34
        case .heading: return 22
        case .body, .label: return 17
        case .caption: return 15
        }
    }

    private var weight: UIFont.Weight {
        switch self {
        case .wordmark, .display: return .black
        case .heading, .label: return .heavy
        case .body: return .medium
        case .caption: return .semibold
        }
    }

    private var textStyle: UIFont.TextStyle {
        switch self {
        case .wordmark, .display: return .largeTitle
        case .heading: return .title2
        case .body: return .body
        case .label: return .headline
        case .caption: return .subheadline
        }
    }

    /// The font at the text size in `traits`, or the system's current size when nil.
    /// `maximumPointSize` stops the font growing past a size that fits its space.
    func font(compatibleWith traits: UITraitCollection? = nil, maximumPointSize: CGFloat? = nil) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        guard let limit = maximumPointSize else {
            return metrics.scaledFont(for: unscaledFont(), compatibleWith: traits)
        }
        return metrics.scaledFont(for: unscaledFont(size: min(size, limit)), maximumPointSize: limit, compatibleWith: traits)
    }

    /// The style's typeface at a fixed size, for measuring text.
    func unscaledFont(size: CGFloat? = nil) -> UIFont {
        let size = size ?? self.size
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
    }
}

/// The three kinds of button. A screen has at most one primary.
enum ButtonKind {
    /// Filled with the theme's accent: the main action.
    case primary
    /// Card-coloured with an ink outline: everything else that matters.
    case secondary
    /// Accent-coloured text with no outline: links and minor actions.
    case quiet
}

/// How big a button is. Large is for the one action a screen is about.
enum ButtonSize {
    case regular, large
}

/// Where a button's icon sits: before the title, or above it on a tile.
enum IconPlacement {
    case leading, top
}

/// A themed button. Primary and secondary buttons have an ink outline and a solid lower
/// edge; a quiet button is text only. `showsFocus` turns the face to the theme's focus
/// colour, so scanner focus shows by brightness as well as by the border.
class ArcadeButton: DynamicTextButton {
    let kind: ButtonKind
    private let theme: UITheme
    private let edgeLayer = CALayer()
    private let faceLayer = CALayer()
    private let size: ButtonSize
    private let fontTraits: UITraitCollection?
    /// The padding before any room is made for an icon.
    private var basePadding: UIEdgeInsets = .zero
    private var iconView: UIImageView?
    private var iconSize: CGSize = .zero
    /// Where the icon sits; a row of tiles changes this when it becomes a column.
    var iconPlacement: IconPlacement = .leading {
        didSet {
            guard iconPlacement != oldValue else { return }
            iconSize = .zero
            setNeedsLayout()
        }
    }

    var showsFocus = false {
        didSet { applyColours() }
    }

    init(kind: ButtonKind, size: ButtonSize = .regular, theme: UITheme, traits: UITraitCollection? = nil) {
        self.kind = kind
        self.size = size
        self.theme = theme
        fontTraits = traits
        super.init(frame: .zero)
        titleLabel?.font = titleFont(compatibleWith: traits)
        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.numberOfLines = 0
        titleLabel?.textAlignment = .center
        layer.cornerRadius = Radius.control
        layer.borderColor = theme.focusColor.cgColor
        if kind == .quiet {
            padding = UIEdgeInsets(top: Spacing.m, left: Spacing.s, bottom: Spacing.m, right: Spacing.s)
        } else {
            padding = UIEdgeInsets(top: Spacing.l, left: Spacing.l, bottom: Spacing.l + Stroke.edge, right: Spacing.l)
            for sublayer in [edgeLayer, faceLayer] {
                sublayer.cornerRadius = Radius.control
                layer.insertSublayer(sublayer, at: 0)
            }
            layer.insertSublayer(edgeLayer, below: faceLayer)
            edgeLayer.backgroundColor = theme.inkColor.cgColor
            faceLayer.borderWidth = Stroke.outline
            faceLayer.borderColor = theme.inkColor.cgColor
        }
        basePadding = padding
        let height = heightAnchor.constraint(greaterThanOrEqualToConstant:
            (size == .large ? Layout.largeButtonHeight : Layout.minButtonHeight) + (kind == .quiet ? 0 : Stroke.edge))
        // Below required, so a host that fixes a row's height wins without a conflict.
        height.priority = UILayoutPriority(999)
        height.isActive = true
        applyColours()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (button: ArcadeButton, _: UITraitCollection) in
            button.updateIconSize(compatibleWith: button.traitCollection)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func titleFont(compatibleWith traits: UITraitCollection?) -> UIFont {
        (size == .large ? TypeStyle.heading : TypeStyle.label).font(compatibleWith: traits)
    }

    /// Shows an SF Symbol with the title. It is decoration: the title is the spoken name.
    func setIcon(systemName: String, placement: IconPlacement = .leading) {
        iconView?.removeFromSuperview()
        let view = UIImageView(image: UIImage(systemName: systemName))
        view.isAccessibilityElement = false
        view.isUserInteractionEnabled = false
        view.contentMode = .center
        addSubview(view)
        iconView = view
        iconPlacement = placement
        updateIconSize(compatibleWith: fontTraits)
        applyColours()
    }

    private func updateIconSize(compatibleWith traits: UITraitCollection?) {
        iconView?.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: titleFont(compatibleWith: traits), scale: .large)
        iconSize = .zero
        setNeedsLayout()
    }

    /// The face colour and the title colour for the current state.
    private var colours: (face: UIColor, title: UIColor) {
        if showsFocus && kind != .quiet { return (theme.focusColor, theme.onFocusColor) }
        switch kind {
        case .primary: return (theme.accentColor, theme.onAccentColor)
        case .secondary: return (theme.cardColor, theme.textColor)
        case .quiet: return (.clear, theme.accentTextColor)
        }
    }

    private func applyColours() {
        let (face, title) = colours
        setTitleColor(title, for: .normal)
        iconView?.tintColor = title
        // The view's own colour matches the face, so anything reading the view tree
        // (contrast tests, snapshots) sees what is behind the title.
        backgroundColor = kind == .quiet ? nil : face
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        faceLayer.backgroundColor = face.cgColor
        CATransaction.commit()
    }

    /// True while the face is sunk onto the lower edge under a touch.
    private(set) var isPressedDown = false

    /// A pressed primary or secondary button sinks onto its lower edge. A quiet button,
    /// or any button when movement is off, dims its title instead.
    override var isHighlighted: Bool {
        didSet {
            let sinks = kind != .quiet && Feedback.allowsMovement
            let dims = isHighlighted && !sinks
            titleLabel?.alpha = dims ? 0.6 : 1
            iconView?.alpha = dims ? 0.6 : 1
            isPressedDown = isHighlighted && sinks
            let depth = isPressedDown ? Stroke.press : 0
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // Everything on the button moves down except the edge it lands on. The
            // scanner's focus border is the button's own, so it stays put.
            layer.sublayerTransform = CATransform3DMakeTranslation(0, depth, 0)
            edgeLayer.transform = CATransform3DMakeTranslation(0, -depth, 0)
            CATransaction.commit()
        }
    }

    override func layoutSubviews() {
        if let icon = iconView {
            // Make room for the icon beside or above the title, so the two are centred
            // together and the button's own height and width allow for both.
            let size = icon.intrinsicContentSize
            if size != iconSize {
                iconSize = size
                var insets = basePadding
                switch iconPlacement {
                case .leading: insets.left += size.width + Spacing.s
                case .top: insets.top += size.height + Spacing.s
                }
                padding = insets
            }
        }
        super.layoutSubviews()
        if let icon = iconView, let label = titleLabel {
            switch iconPlacement {
            case .leading:
                icon.frame = CGRect(x: label.frame.minX - Spacing.s - iconSize.width, y: label.frame.midY - iconSize.height / 2,
                                    width: iconSize.width, height: iconSize.height)
            case .top:
                icon.frame = CGRect(x: label.frame.midX - iconSize.width / 2, y: label.frame.minY - Spacing.s - iconSize.height,
                                    width: iconSize.width, height: iconSize.height)
            }
        }
        guard kind != .quiet else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Not `frame`: the edge may be shifted while the button is pressed.
        edgeLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        edgeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        faceLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - Stroke.edge))
        CATransaction.commit()
    }
}

/// The two layers behind a card: a solid ink lower edge and a face with an ink outline.
/// The owning view keeps its content above `Stroke.edge` and calls `layout(in:)`.
struct SurfaceLayers {
    private let edge = CALayer()
    private let face = CALayer()

    func install(in view: UIView, radius: CGFloat = Radius.card) {
        view.layer.cornerRadius = radius
        for layer in [face, edge] {
            layer.cornerRadius = radius
            view.layer.insertSublayer(layer, at: 0)
        }
    }

    func layout(in bounds: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Not `frame`: the edge may be shifted while its card is pressed.
        edge.bounds = CGRect(origin: .zero, size: bounds.size)
        edge.position = CGPoint(x: bounds.midX, y: bounds.midY)
        face.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - Stroke.edge))
        CATransaction.commit()
    }

    /// Sinks everything in `view` by `depth` except the lower edge, for a pressed card.
    func press(_ view: UIView, depth: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.layer.sublayerTransform = CATransform3DMakeTranslation(0, depth, 0)
        edge.transform = CATransform3DMakeTranslation(0, -depth, 0)
        CATransaction.commit()
    }

    func colour(fill: UIColor, edge edgeColour: UIColor, outline: UIColor, width: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        edge.backgroundColor = edgeColour.cgColor
        face.backgroundColor = fill.cgColor
        face.borderColor = outline.cgColor
        face.borderWidth = width
        CATransaction.commit()
    }
}

/// A card: a rounded theme surface with an ink outline and a solid lower edge. Rows and
/// other content go in `content`, which stays inside the outline and above the edge.
final class SurfaceView: UIView {
    let content = UIStackView()
    private let layers = SurfaceLayers()

    init(theme: UITheme) {
        super.init(frame: .zero)
        // The view's own colour matches the face, for anything that reads the view tree.
        backgroundColor = theme.cardColor
        layers.install(in: self)
        layers.colour(fill: theme.cardColor, edge: theme.inkColor, outline: theme.inkColor, width: Stroke.outline)
        content.axis = .vertical
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: Stroke.outline),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Stroke.outline - Stroke.edge),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Stroke.outline),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Stroke.outline)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layers.layout(in: bounds)
    }
}

/// A card that is chosen by pressing it: a theme, a helicopter, or a set of pipes. The
/// chosen card has a thicker outline in the theme's accent; hosts also say so in words.
final class CardButton: UIButton {
    private let theme: UITheme
    private let layers = SurfaceLayers()
    /// How far content must stay from the bottom, to clear the lower edge.
    static let bottomInset = Stroke.edge

    var isChosen = false {
        didSet { applyColours() }
    }

    init(theme: UITheme) {
        self.theme = theme
        super.init(frame: .zero)
        backgroundColor = theme.cardColor
        layers.install(in: self)
        applyColours()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func applyColours() {
        layers.colour(fill: theme.cardColor, edge: theme.inkColor,
                      outline: isChosen ? theme.accentColor : theme.inkColor,
                      width: isChosen ? Stroke.focus : Stroke.outline)
    }

    /// True while the card is sunk onto its lower edge under a touch.
    private(set) var isPressedDown = false

    /// A pressed card sinks onto its lower edge, or dims when movement is off.
    override var isHighlighted: Bool {
        didSet {
            let sinks = Feedback.allowsMovement
            subviews.forEach { $0.alpha = isHighlighted && !sinks ? 0.6 : 1 }
            isPressedDown = isHighlighted && sinks
            layers.press(self, depth: isPressedDown ? Stroke.press : 0)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layers.layout(in: bounds)
    }
}

/// A small label above a large number on a card-coloured chip: Score and Best during
/// play. VoiceOver reads the two as one, "Score 12".
final class ScoreChip: UIView {
    private let caption = UILabel()
    private let number = UILabel()
    private let name: String

    var value: Int = 0 {
        didSet {
            number.text = "\(value)"
            accessibilityLabel = "\(name) \(value)"
        }
    }

    /// What the chip shows, as VoiceOver reads it.
    var text: String { "\(name) \(value)" }

    init(name: String, theme: UITheme, traits: UITraitCollection?) {
        self.name = name
        super.init(frame: .zero)
        backgroundColor = theme.cardColor
        layer.cornerRadius = Radius.control
        layer.borderWidth = Stroke.outline
        layer.borderColor = theme.inkColor.cgColor
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        caption.text = name
        caption.font = TypeStyle.caption.font(compatibleWith: traits)
        caption.textColor = theme.secondaryTextColor
        number.font = TypeStyle.heading.font(compatibleWith: traits)
        number.textColor = theme.accentTextColor
        let column = UIStackView(arrangedSubviews: [caption, number])
        column.axis = .vertical
        column.alignment = .center
        column.translatesAutoresizingMaskIntoConstraints = false
        for label in [caption, number] {
            label.adjustsFontForContentSizeCategory = true
            label.textAlignment = .center
        }
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.s),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Spacing.s),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.l),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.l),
            // Wide enough that the chip does not change size with every point.
            widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.minButtonHeight + Spacing.xl)
        ])
        value = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// A line of text on a rounded card-coloured chip, with room around the text: the
/// flight hint and the new-high-score banner during play.
final class ChipLabel: UILabel {
    private static let insets = UIEdgeInsets(top: Spacing.s, left: Spacing.l, bottom: Spacing.s, right: Spacing.l)

    init(style: TypeStyle, theme: UITheme, traits: UITraitCollection?) {
        super.init(frame: .zero)
        font = style.font(compatibleWith: traits)
        adjustsFontForContentSizeCategory = true
        numberOfLines = 0
        textAlignment = .center
        textColor = theme.textColor
        backgroundColor = theme.cardColor
        layer.cornerRadius = Radius.control
        layer.borderWidth = Stroke.outline
        layer.borderColor = theme.inkColor.cgColor
        layer.masksToBounds = true
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: Self.insets))
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines lines: Int) -> CGRect {
        let inner = super.textRect(forBounds: bounds.inset(by: Self.insets), limitedToNumberOfLines: lines)
        return inner.inset(by: UIEdgeInsets(top: -Self.insets.top, left: -Self.insets.left,
                                            bottom: -Self.insets.bottom, right: -Self.insets.right))
    }
}
