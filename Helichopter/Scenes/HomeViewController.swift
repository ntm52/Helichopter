import UIKit
import SpriteKit

/// What a Home screen choice does, in scanning order.
enum HomeAction: CaseIterable {
    case play, settings, howToPlay

    var title: String {
        switch self {
        case .play: return "Play"
        case .settings: return "Settings"
        case .howToPlay: return "How to Play"
        }
    }

    var hint: String {
        switch self {
        case .play: return "Starts a new game"
        case .settings: return "Opens settings"
        case .howToPlay: return "Replays the guide to flying, pausing, and switches"
        }
    }
}

/// The Home screen: the mascot, the title, and Play, Settings, and How to Play.
final class HomeViewController: MenuViewController {
    let titleLabel = UILabel()
    private(set) var mascot: UIImageView!
    /// Read when Home is built and when the setting changes; tests replace it.
    static var prefersReducedMotion: () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    private(set) lazy var items: [MenuItem] = HomeAction.allCases.map { action in
        item(action.title, hint: action.hint) { [weak self] in self?.perform(action) }
    }

    override var announcement: Any? { titleLabel }

    override func buildMenu() {
        let atlas = SKTextureAtlas(named: "Helicopter Player")
        let mascot = UIImageView(image: UIImage(cgImage: atlas.textureNamed("r_player1").cgImage()))
        mascot.contentMode = .scaleAspectFit
        mascot.heightAnchor.constraint(equalToConstant: 110).isActive = true
        mascot.isAccessibilityElement = false
        self.mascot = mascot
        menu.stack.addArrangedSubview(mascot)
        updateMascotMotion()
        NotificationCenter.default.addObserver(self, selector: #selector(updateMascotMotion),
                                               name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)

        menu.addLabel("Helichopter", style: .title1, into: titleLabel)
        items.forEach { menu.addButton(for: $0) }
        scanner.items = items
    }

    /// The rotor spins only when the player has not asked for less motion.
    @objc private func updateMascotMotion() {
        guard !Self.prefersReducedMotion() else {
            mascot.stopAnimating()
            mascot.animationImages = nil
            return
        }
        guard mascot.animationImages == nil else { return }
        let atlas = SKTextureAtlas(named: "Helicopter Player")
        mascot.animationImages = (1...60).map { UIImage(cgImage: atlas.textureNamed("r_player\($0)").cgImage()) }
        mascot.animationDuration = 60 * HelicopterNode.rotorFrameInterval
        mascot.startAnimating()
    }

    func perform(_ action: HomeAction) {
        switch action {
        case .play:
            guard let scene = GameScene(fileNamed: Scenes.game.getName()) else { return }
            navigate(.scene(scene))
        case .settings:
            navigate(.settings)
        case .howToPlay:
            navigate(.guide)
        }
    }
}
