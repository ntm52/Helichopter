import UIKit
import SpriteKit

/// What a Home screen choice does, in scanning order.
enum HomeAction: CaseIterable {
    case play, hangar, settings, howToPlay

    var title: String {
        switch self {
        case .play: return "Play"
        case .hangar: return "Hangar"
        case .settings: return "Settings"
        case .howToPlay: return "How to Play"
        }
    }

    var hint: String {
        switch self {
        case .play: return "Starts a new game"
        case .hangar: return "Changes how the game looks"
        case .settings: return "Opens settings"
        case .howToPlay: return "Replays the guide to flying, pausing, and switches"
        }
    }

    /// The SF Symbol shown with the title. Decoration only; VoiceOver reads the title.
    var symbolName: String {
        switch self {
        case .play: return "play.fill"
        case .hangar: return "paintbrush.fill"
        case .settings: return "gearshape.fill"
        case .howToPlay: return "questionmark.circle.fill"
        }
    }
}

/// The Home screen: the mascot, the wordmark, Play as the one large primary button, and
/// Hangar, Settings, and How to Play as a row of tiles (a column at accessibility text sizes).
final class HomeViewController: MenuViewController {
    let titleLabel = UILabel()
    private(set) var mascot: UIImageView!
    /// The leaning view that holds the wordmark.
    private(set) var wordmarkHolder: UIView!
    /// Read when Home is built and when the setting changes; tests replace it.
    static var prefersReducedMotion: () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    private(set) lazy var items: [MenuItem] = HomeAction.allCases.map { action in
        item(action.title, hint: action.hint) { [weak self] in self?.perform(action) }
    }

    override var announcement: Any? { titleLabel }

    override func buildMenu() {
        let mascot = UIImageView(image: GameSettings.shared.selectedHelicopterSkin.helicopterImage())
        mascot.contentMode = .scaleAspectFit
        // Large, but smaller when the text is very large and the buttons need the room.
        let large = !traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        mascot.heightAnchor.constraint(equalToConstant: large ? Self.mascotHeight : Self.compactMascotHeight).isActive = true
        mascot.isAccessibilityElement = false
        self.mascot = mascot
        menu.stack.addArrangedSubview(mascot)
        updateMascotMotion()
        NotificationCenter.default.addObserver(self, selector: #selector(updateMascotMotion),
                                               name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)

        addWordmark()
        // Play first and largest; the scanner still moves Play, Hangar, Settings, How to Play.
        menu.addButton(for: items[0], kind: .primary, size: .large, icon: HomeAction.play.symbolName)
        menu.addTileRow(for: zip(items, HomeAction.allCases).dropFirst().map { (choice: $0, icon: $1.symbolName) })
        scanner.items = items
    }

    static let mascotHeight: CGFloat = 170
    static let compactMascotHeight: CGFloat = 110
    /// How far the wordmark leans, in radians (about three degrees).
    static let wordmarkTilt: CGFloat = -.pi / 60

    /// The name in the heaviest rounded type, leaning a little, with a solid shadow in
    /// the theme's accent. `fitWordmark()` keeps it to one line by limiting its size.
    private func addWordmark() {
        let theme = menu.theme
        menu.addLabel("Helichopter", style: .wordmark, into: titleLabel)
        titleLabel.accessibilityTraits = .header
        titleLabel.textColor = theme.textColor
        titleLabel.layer.shadowColor = theme.accentColor.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: Spacing.xs)
        titleLabel.layer.shadowRadius = 0
        titleLabel.layer.shadowOpacity = 1
        // The lean is on a holder, not the label: a rotated label's own frame no longer
        // matches its text, which the accessibility audit reports as clipped text.
        let holder = UIView()
        titleLabel.removeFromSuperview()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: holder.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: holder.trailingAnchor)
        ])
        holder.transform = CGAffineTransform(rotationAngle: Self.wordmarkTilt)
        menu.stack.addArrangedSubview(holder)
        wordmarkHolder = holder
        menu.stack.setCustomSpacing(Spacing.xl, after: holder)
    }

    /// The rotor spins only when the player has not asked for less motion.
    @objc private func updateMascotMotion() {
        guard !Self.prefersReducedMotion() else {
            mascot.stopAnimating()
            mascot.animationImages = nil
            return
        }
        guard mascot.animationImages == nil else { return }
        let skin = GameSettings.shared.selectedHelicopterSkin
        let frames = Cosmetic.helicopterFrameCount
        mascot.animationImages = (1...frames).map { skin.helicopterImage(frame: $0) }
        mascot.animationDuration = Double(frames) * HelicopterNode.rotorFrameInterval
        mascot.startAnimating()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitWordmark()
    }

    private var fittedWordmarkWidth: CGFloat = 0

    /// The wordmark grows with the text size only as far as one line of the screen
    /// allows, so the name never breaks in the middle. A one-line label that shrinks to
    /// fit would do the same, but the accessibility audit reports that as clipped text.
    private func fitWordmark() {
        let width = titleLabel.bounds.width
        guard width > 0, width != fittedWordmarkWidth, let text = titleLabel.text else { return }
        fittedWordmarkWidth = width
        let probe: CGFloat = 100
        let needed = (text as NSString).size(withAttributes: [.font: TypeStyle.wordmark.unscaledFont(size: probe)]).width
        let limit = (probe * (width - Spacing.l) / needed).rounded(.down)
        titleLabel.font = TypeStyle.wordmark.font(compatibleWith: traitCollection, maximumPointSize: limit)
    }

    func perform(_ action: HomeAction) {
        switch action {
        case .play:
            guard let scene = GameLayout.best(for: view.bounds.size).makeScene() else { return }
            navigate(.scene(scene))
        case .hangar:
            navigate(.hangar)
        case .settings:
            navigate(.settings)
        case .howToPlay:
            navigate(.guide)
        }
    }
}
