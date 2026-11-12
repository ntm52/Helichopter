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
        // Always a column: three names do not fit side by side on a phone.
        return cardsRow(themeCards, inColumn: true)
    }

    /// Cards side by side at normal text sizes, one column at accessibility sizes. They
    /// stand on the page, each as tall as the tallest in its row.
    private func cardsRow(_ items: [UIButton], inColumn: Bool = false) -> UIView {
        let row = UIView()

        let column = inColumn || usesSingleColumn
        let cards = UIStackView(arrangedSubviews: items)
        cards.axis = column ? .vertical : .horizontal
        cards.distribution = column ? .fill : .fillEqually
        cards.alignment = .fill
        cards.spacing = Spacing.m
        cards.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(cards)
        NSLayoutConstraint.activate([
            cards.topAnchor.constraint(equalTo: row.topAnchor),
            cards.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            cards.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            cards.trailingAnchor.constraint(equalTo: row.trailingAnchor),
        ])
        appendToPage(row)
        return row
    }

    /// A card with its chosen state shown by the outline, the button state, and the trait.
    private func makeCard(chosen: Bool) -> CardButton {
        let btn = CardButton(theme: theme)
        btn.isChosen = chosen
        // The button state too, so UI automation and Switch Control see the choice.
        btn.isSelected = chosen
        if chosen { btn.accessibilityTraits.insert(.selected) }
        return btn
    }

    private func makeThemeCard(_ theme: UITheme, selected: Bool) -> UIButton {
        let btn = makeCard(chosen: selected)
        btn.accessibilityLabel = theme.name
        btn.accessibilityHint  = "Menu theme"

        // A small picture of the theme: its background, title text, and a button chip.
        let preview = UIView()
        preview.backgroundColor = theme.sceneBackgroundColor
        preview.layer.cornerRadius = Radius.inner
        preview.layer.borderWidth = Stroke.outline
        preview.layer.borderColor = style.div.cgColor

        let previewTitle = previewLabel("Helichopter", style: .label, color: theme.titleTextColor)
        let chipText = previewLabel("Play", style: .caption, color: theme.onAccentColor)
        let chip = UIView()
        chip.backgroundColor = theme.accentColor
        chip.layer.cornerRadius = Radius.inner / 2
        chip.addSubview(chipText)
        NSLayoutConstraint.activate([
            chipText.topAnchor.constraint(equalTo: chip.topAnchor, constant: Spacing.xs),
            chipText.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -Spacing.xs),
            chipText.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: Spacing.l),
            chipText.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -Spacing.l),
        ])
        let previewStack = UIStackView(arrangedSubviews: [previewTitle, chip])
        previewStack.axis = .vertical
        previewStack.alignment = .center
        previewStack.spacing = Spacing.s
        previewStack.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(previewStack)
        NSLayoutConstraint.activate([
            previewStack.topAnchor.constraint(equalTo: preview.topAnchor, constant: Spacing.l),
            previewStack.bottomAnchor.constraint(equalTo: preview.bottomAnchor, constant: -Spacing.l),
            previewStack.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: Spacing.xs),
            previewStack.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -Spacing.xs),
            previewTitle.widthAnchor.constraint(lessThanOrEqualTo: previewStack.widthAnchor),
        ])

        // The picture before the name; above it at accessibility text sizes.
        let stacked = usesSingleColumn
        let nameL = makeLabel(theme.name, style: .label, color: style.text)
        var labels: [UIView] = [nameL]
        if selected {
            // Shown in words too, not only by the thicker border.
            labels.append(makeLabel("Chosen", style: .caption, color: style.accent))
        }
        let text = UIStackView(arrangedSubviews: labels)
        text.axis = .vertical
        text.spacing = Spacing.xs
        if !stacked { preview.widthAnchor.constraint(equalToConstant: Self.themePreviewWidth).isActive = true }

        let vs = UIStackView(arrangedSubviews: [preview, text])
        vs.axis = stacked ? .vertical : .horizontal
        vs.alignment = stacked ? .fill : .center
        vs.spacing = stacked ? Spacing.s : Spacing.l
        vs.translatesAutoresizingMaskIntoConstraints = false
        vs.isUserInteractionEnabled = false
        btn.addSubview(vs)
        NSLayoutConstraint.activate([
            vs.topAnchor.constraint(equalTo: btn.topAnchor, constant: Spacing.m),
            vs.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -Spacing.m - CardButton.bottomInset),
            vs.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: Spacing.m),
            vs.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -Spacing.m),
        ])

        let t = ButtonTarget { [weak self] in self?.chooseTheme(theme) }
        controlTargets.append(t)
        btn.addTarget(t, action: #selector(ButtonTarget.tapped), for: .touchUpInside)
        return btn
    }

    /// Preview text scales with the player's text size but shrinks to fit its card.
    private func previewLabel(_ text: String, style: TypeStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = font(style)
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
        let btn = makeCard(chosen: equipped)
        btn.accessibilityLabel = skin.name
        btn.accessibilityHint  = skin.spokenDescription
        if equipped { btn.accessibilityValue = "Equipped" }

        let picture = UIImageView(image: skinImage(skin))
        picture.contentMode = .scaleAspectFit
        picture.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picture.widthAnchor.constraint(equalToConstant: Self.pictureSize),
            picture.heightAnchor.constraint(equalToConstant: Self.pictureSize),
        ])

        let nameL = makeLabel(skin.name, style: .label, color: style.text)
        nameL.textAlignment = .center
        var labels: [UIView] = [nameL]
        if equipped {
            let equippedL = makeLabel("Equipped", style: .caption, color: style.accent)
            equippedL.textAlignment = .center
            labels.append(equippedL)
        }
        let text = UIStackView(arrangedSubviews: labels)
        text.axis = .vertical
        text.spacing = Spacing.xs

        let hs = UIStackView(arrangedSubviews: [picture, text])
        // The picture sits above the name, so a name gets the card's full width and
        // never breaks inside a word when two cards share a row.
        hs.axis = .vertical
        hs.alignment = .center
        hs.spacing = Spacing.s
        hs.translatesAutoresizingMaskIntoConstraints = false
        hs.isUserInteractionEnabled = false
        btn.addSubview(hs)
        // Pinned to the top, so names line up across a row whether or not a card says
        // "Equipped"; the weak bottom pin gives a card on its own row its height.
        let below = Spacing.m + CardButton.bottomInset
        let hugBottom = hs.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -below)
        hugBottom.priority = .defaultLow
        NSLayoutConstraint.activate([
            hs.topAnchor.constraint(equalTo: btn.topAnchor, constant: Spacing.m),
            hs.bottomAnchor.constraint(lessThanOrEqualTo: btn.bottomAnchor, constant: -below),
            hugBottom,
            hs.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: Spacing.m),
            hs.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -Spacing.m),
        ])

        let t = ButtonTarget { [weak self] in self?.chooseSkin(skin) }
        controlTargets.append(t)
        btn.addTarget(t, action: #selector(ButtonTarget.tapped), for: .touchUpInside)
        return btn
    }

    /// The width of a theme's small picture when it sits before the name.
    static let themePreviewWidth: CGFloat = 132
    /// The side of a look's picture.
    static let pictureSize: CGFloat = 112

    private func skinImage(_ skin: Cosmetic) -> UIImage? {
        switch skin.kind {
        case .helicopter: return skin.helicopterImage()
        // Pipe art is drawn grey and takes the colour palette's pipe colour, as in play.
        case .pipe: return skin.pipePreviewImage(tint: GameSettings.shared.selectedPalette.pipeColor)
        }
    }

    private func chooseSkin(_ skin: Cosmetic) {
        guard !GameSettings.shared.isSettingsLocked, skin.isOwned else { return }
        GameSettings.shared.select(skin)
        chosenCardName = skin.name
        onThemeChanged?()
    }
}
