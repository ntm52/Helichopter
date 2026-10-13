import UIKit

/// The Hangar screen: how the game looks. It hosts a `HangarPanelView` and rebuilds it,
/// keeping scroll and scanner focus, when the theme, the lock, or the text size changes.
final class HangarViewController: PanelScreenViewController<HangarPanelView> {
    /// The panel being replaced still holds the card just chosen; the new one announces it.
    override func configure(_ panel: HangarPanelView) {
        panel.cardToAnnounce = self.panel?.chosenCardName
    }
}

// MARK: - HangarPanelView
// Menu Theme cards, then one card per helicopter and pipe look in `CosmeticsCatalog`.
// Only Classic exists so far; each card is a real control, so new looks need only
// catalog entries and art.

final class HangarPanelView: ScrollingPanelView {

    override class var title: String { "Hangar" }

    static let lockedMessage = "Locked by a caregiver in Settings."

    private(set) var themeCards: [UIButton] = []
    private(set) var helicopterCards: [UIButton] = []
    private(set) var pipeCards: [UIButton] = []
    /// The card just chosen, so the rebuilt panel scans from it however it was chosen.
    fileprivate private(set) var chosenCardName: String?
    /// The card chosen on the panel this one replaced, for VoiceOver to land on.
    fileprivate var cardToAnnounce: String?

    override var focusedSetting: String? { chosenCardName ?? super.focusedSetting }

    /// After choosing a card the rebuilt panel moves VoiceOver to it.
    override var announcementAfterRebuild: Any? {
        let all = themeCards + helicopterCards + pipeCards
        return all.first { cardToAnnounce != nil && $0.accessibilityLabel == cardToAnnounce }
            ?? themeCards.first { $0.accessibilityTraits.contains(.selected) } ?? self
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
        helicopterCards = CosmeticsCatalog.items(of: .helicopter).filter(\.isOwned).map { makeSkinCard($0) }
        let helicopters = cardsRow(helicopterCards)

        sectionHeader("Pipes")
        pipeCards = CosmeticsCatalog.items(of: .pipe).filter(\.isOwned).map { makeSkinCard($0) }
        let pipes = cardsRow(pipeCards)

        if gs.isSettingsLocked { lock([helicopters, pipes]) }
    }

    // MARK: Menu Theme

    private func themeCardsRow() -> UIView {
        let currentID = GameSettings.shared.selectedThemeID
        themeCards = GameSettings.allThemes.map { makeThemeCard($0, selected: $0.id == currentID) }
        return cardsRow(themeCards)
    }

    /// Cards side by side at normal text sizes, one column at accessibility sizes.
    private func cardsRow(_ items: [UIButton]) -> UIView {
        let row = UIView()
        row.backgroundColor = style.rowBg

        let cards = UIStackView(arrangedSubviews: items)
        cards.axis = usesSingleColumn ? .vertical : .horizontal
        cards.distribution = usesSingleColumn ? .fill : .fillEqually
        cards.alignment = .fill
        cards.spacing = 12
        cards.translatesAutoresizingMaskIntoConstraints = false

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
        chosenCardName = theme.name
        onThemeChanged?()
    }

    // MARK: Helicopters and Pipes

    /// One look: its picture, name, and "Equipped" in words on the chosen one.
    private func makeSkinCard(_ skin: Cosmetic) -> UIButton {
        let equipped = GameSettings.shared.selectedSkin(of: skin.kind) == skin
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 12
        btn.layer.borderWidth  = equipped ? 3.0 : 1.5
        btn.layer.borderColor  = equipped ? style.accent.cgColor : style.div.cgColor
        btn.backgroundColor    = style.swatchBg
        btn.accessibilityLabel = skin.name
        btn.accessibilityHint  = skin.spokenDescription
        btn.isSelected = equipped
        if equipped {
            btn.accessibilityTraits.insert(.selected)
            btn.accessibilityValue = "Equipped"
        }

        let picture = UIImageView(image: skinImage(skin))
        picture.contentMode = .scaleAspectFit
        // Pipe art is drawn grey and tinted by the colour palette, as in play.
        if skin.kind == .pipe { picture.tintColor = GameSettings.shared.selectedPalette.pipeColor }
        picture.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picture.widthAnchor.constraint(equalToConstant: 64),
            picture.heightAnchor.constraint(equalToConstant: 64),
        ])

        let nameL = makeLabel(skin.name, size: 16, weight: .semibold, color: style.text)
        var labels: [UIView] = [nameL]
        if equipped {
            labels.append(makeLabel("Equipped", size: 12, weight: .medium, color: style.sub))
        }
        let text = UIStackView(arrangedSubviews: labels)
        text.axis = .vertical
        text.spacing = 2

        let hs = UIStackView(arrangedSubviews: [picture, text])
        hs.axis = usesSingleColumn ? .vertical : .horizontal
        hs.alignment = usesSingleColumn ? .leading : .center
        hs.spacing = 14
        hs.translatesAutoresizingMaskIntoConstraints = false
        hs.isUserInteractionEnabled = false
        btn.addSubview(hs)
        NSLayoutConstraint.activate([
            hs.topAnchor.constraint(equalTo: btn.topAnchor, constant: 10),
            hs.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -10),
            hs.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 12),
            hs.trailingAnchor.constraint(lessThanOrEqualTo: btn.trailingAnchor, constant: -12),
        ])

        let t = ButtonTarget { [weak self] in self?.chooseSkin(skin) }
        controlTargets.append(t)
        btn.addTarget(t, action: #selector(ButtonTarget.tapped), for: .touchUpInside)
        return btn
    }

    private func skinImage(_ skin: Cosmetic) -> UIImage? {
        switch skin.kind {
        case .helicopter: return skin.helicopterImage()
        case .pipe: return UIImage(named: skin.pipeTextureName)?.withRenderingMode(.alwaysTemplate)
        }
    }

    private func chooseSkin(_ skin: Cosmetic) {
        guard !GameSettings.shared.isSettingsLocked, skin.isOwned else { return }
        GameSettings.shared.select(skin)
        chosenCardName = skin.name
        onThemeChanged?()
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
