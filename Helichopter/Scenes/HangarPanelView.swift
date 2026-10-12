import UIKit
import SpriteKit

/// The Hangar screen: how the game looks. It hosts a `HangarPanelView` and rebuilds it,
/// keeping scroll and scanner focus, when the theme, the lock, or the text size changes.
final class HangarViewController: PanelScreenViewController<HangarPanelView> { }

// MARK: - HangarPanelView
// Menu Theme cards, then the helicopter and pipe looks. In this version only Classic
// exists for helicopters and pipes, shown as static cards that are not controls.

final class HangarPanelView: ScrollingPanelView {

    override class var title: String { "Hangar" }

    static let lockedMessage = "Locked by a caregiver in Settings."

    private(set) var themeCards: [UIButton] = []
    /// The card just chosen, so the rebuilt panel scans from it however it was chosen.
    private var chosenThemeName: String?

    override var focusedSetting: String? { chosenThemeName ?? super.focusedSetting }

    /// After choosing a theme the rebuilt panel moves VoiceOver to the chosen card.
    override var announcementAfterRebuild: Any? {
        themeCards.first { $0.accessibilityTraits.contains(.selected) } ?? self
    }

    private var usesSingleColumn: Bool {
        (fontTraits ?? traitCollection).preferredContentSizeCategory.isAccessibilityCategory
    }

    override func buildSections() {
        let gs = GameSettings.shared

        sectionHeader("Menu Theme")
        if gs.isSettingsLocked { noteRow(Self.lockedMessage) }
        let cards = themeCardsRow()
        if gs.isSettingsLocked { lock([cards]) }

        sectionHeader("Helicopters")
        classicRow(kind: "Helicopter", image: helicopterImage())

        sectionHeader("Pipes")
        classicRow(kind: "Pipes", image: UIImage(named: "pipe-yellow")?.withRenderingMode(.alwaysTemplate),
                   tint: gs.selectedPalette.pipeColor)
    }

    // MARK: Menu Theme

    private func themeCardsRow() -> UIView {
        let row = UIView()
        row.backgroundColor = style.rowBg

        let cards = UIStackView()
        cards.axis = usesSingleColumn ? .vertical : .horizontal
        cards.distribution = usesSingleColumn ? .fill : .fillEqually
        cards.alignment = .fill
        cards.spacing = 12
        cards.translatesAutoresizingMaskIntoConstraints = false

        themeCards = []
        let currentID = GameSettings.shared.selectedThemeID
        for theme in GameSettings.allThemes {
            let card = makeThemeCard(theme, selected: theme.id == currentID)
            cards.addArrangedSubview(card)
            themeCards.append(card)
        }

        row.addSubview(cards)
        NSLayoutConstraint.activate([
            cards.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            cards.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
            cards.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            cards.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
        ])
        appendRow(row)
        return row
    }

    private func makeThemeCard(_ theme: UITheme, selected: Bool) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 12
        btn.layer.borderWidth  = selected ? 3.0 : 1.5
        btn.layer.borderColor  = selected ? style.accent.cgColor : style.div.cgColor
        btn.backgroundColor    = style.swatchBg
        btn.accessibilityLabel = theme.name
        btn.accessibilityHint  = "Menu theme"
        // The button state too, so UI automation and Switch Control see the choice.
        btn.isSelected = selected
        if selected { btn.accessibilityTraits.insert(.selected) }

        // A small picture of the theme: its background, title text, and a button chip.
        let preview = UIView()
        preview.backgroundColor = theme.sceneBackgroundColor
        preview.layer.cornerRadius = 8
        preview.layer.borderWidth = 1
        preview.layer.borderColor = style.div.cgColor

        let previewTitle = previewLabel("Helichopter", size: 15, weight: .bold, color: theme.titleTextColor)
        let chipText = previewLabel("Play", size: 13, weight: .semibold, color: theme.buttonTextColor)
        let chip = UIView()
        chip.backgroundColor = theme.buttonTintColor
        chip.layer.cornerRadius = 6
        chip.addSubview(chipText)
        NSLayoutConstraint.activate([
            chipText.topAnchor.constraint(equalTo: chip.topAnchor, constant: 4),
            chipText.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -4),
            chipText.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 14),
            chipText.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -14),
        ])
        let previewStack = UIStackView(arrangedSubviews: [previewTitle, chip])
        previewStack.axis = .vertical
        previewStack.alignment = .center
        previewStack.spacing = 6
        previewStack.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(previewStack)
        NSLayoutConstraint.activate([
            previewStack.topAnchor.constraint(equalTo: preview.topAnchor, constant: 10),
            previewStack.bottomAnchor.constraint(equalTo: preview.bottomAnchor, constant: -10),
            previewStack.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 4),
            previewStack.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -4),
            previewTitle.widthAnchor.constraint(lessThanOrEqualTo: previewStack.widthAnchor),
        ])

        let nameL = makeLabel(theme.name, size: 15, weight: .semibold, color: style.text)
        nameL.textAlignment = .center
        preview.setContentHuggingPriority(.required, for: .vertical)
        var parts: [UIView] = [preview, nameL]
        if selected {
            // Shown in words too, not only by the thicker border.
            let chosenL = makeLabel("Chosen", size: 12, weight: .medium, color: style.sub)
            chosenL.textAlignment = .center
            parts.append(chosenL)
        }
        // Cards share a height; the spare space goes below the text, not into the preview.
        let filler = UIView()
        filler.setContentHuggingPriority(.defaultLow - 1, for: .vertical)
        parts.append(filler)

        let vs = UIStackView(arrangedSubviews: parts)
        vs.axis = .vertical
        vs.spacing = 6
        vs.translatesAutoresizingMaskIntoConstraints = false
        vs.isUserInteractionEnabled = false
        btn.addSubview(vs)
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: btn.topAnchor, constant: 8),
            vs.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -8),
            vs.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 8),
            vs.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -8),
        ])

        let t = ButtonTarget { [weak self] in self?.chooseTheme(theme) }
        controlTargets.append(t)
        btn.addTarget(t, action: #selector(ButtonTarget.tapped), for: .touchUpInside)
        return btn
    }

    /// Preview text scales with the player's text size but shrinks to fit its card.
    private func previewLabel(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = scaledFont(size, weight: weight)
        label.adjustsFontForContentSizeCategory = true
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func chooseTheme(_ theme: UITheme) {
        guard !GameSettings.shared.isSettingsLocked else { return }
        GameSettings.shared.selectedThemeID = theme.id
        chosenThemeName = theme.name
        onThemeChanged?()
    }

    // MARK: Helicopters and Pipes

    /// The one look that exists so far, shown as equipped. Not a control: there is
    /// nothing to choose yet, so the scanner and Voice Control skip it.
    private func classicRow(kind: String, image: UIImage?, tint: UIColor? = nil) {
        let row = UIView()
        row.backgroundColor = style.rowBg
        row.isAccessibilityElement = true
        row.accessibilityLabel = "Classic \(kind). Equipped."

        let picture = UIImageView(image: image)
        picture.contentMode = .scaleAspectFit
        // Pipe art is drawn grey and tinted by the colour palette, as in play.
        if let tint = tint { picture.tintColor = tint }
        picture.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picture.widthAnchor.constraint(equalToConstant: 64),
            picture.heightAnchor.constraint(equalToConstant: 64),
        ])

        let nameL = makeLabel("Classic", size: 16, weight: .semibold, color: style.text)
        let stateL = makeLabel("Equipped", size: 12, weight: .medium, color: style.sub)
        let labels = UIStackView(arrangedSubviews: [nameL, stateL])
        labels.axis = .vertical
        labels.spacing = 2

        let hs = UIStackView(arrangedSubviews: [picture, labels])
        hs.axis = usesSingleColumn ? .vertical : .horizontal
        hs.alignment = usesSingleColumn ? .leading : .center
        hs.spacing = 14
        hs.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(hs)
        NSLayoutConstraint.activate([
            hs.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            hs.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
            hs.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            hs.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -20),
        ])
        appendRow(row)
    }

    private func helicopterImage() -> UIImage {
        let atlas = SKTextureAtlas(named: "Helicopter Player")
        return UIImage(cgImage: atlas.textureNamed("r_player1").cgImage())
    }

    // MARK: Notes

    private func noteRow(_ text: String) {
        let row = UIView()
        row.backgroundColor = style.rowBg
        let label = makeLabel(text, size: 15, weight: .medium, color: style.text)
        row.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
        ])
        appendRow(row)
    }
}
