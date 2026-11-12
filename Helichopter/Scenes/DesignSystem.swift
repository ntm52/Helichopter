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
    /// The "Helichopter" wordmark on Home.
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

    override var isHighlighted: Bool {
        didSet {
            titleLabel?.alpha = isHighlighted ? 0.6 : 1
            iconView?.alpha = isHighlighted ? 0.6 : 1
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
        edgeLayer.frame = bounds
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
        edge.frame = bounds
        face.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - Stroke.edge))
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

    override var isHighlighted: Bool {
        didSet { subviews.forEach { $0.alpha = isHighlighted ? 0.6 : 1 } }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layers.layout(in: bounds)
    }
}
