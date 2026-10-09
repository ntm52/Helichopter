import SpriteKit

class RoutingUtilityScene: SKScene, ButtonNodeResponderType {

    // MARK: - Properties

    let selection = UISelectionFeedbackGenerator()

    // Focus scanner drives the ButtonNode focus-ring for switch / keyboard / controller navigation.
    // Nil until the first didMove(to:) — subclasses share the same instance.
    private(set) var focusScanner: FocusScanner?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupFocusScanner()
        // Notify Switch Control that a new screen is available
        ScreenChangeAnnouncer.post()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        focusScanner?.stop()
    }

    // MARK: - Scanner setup

    var scannersDuringTransition: [FocusScanner] { focusScanner.map { [$0] } ?? [] }

    private func setupFocusScanner() {
        focusScanner?.stop()
        let scanner = FocusScanner()
        scanner.items = findAllButtonsInScene()
        focusScanner = scanner
        // Auto-start the timed scanning loop only when the user has opted into switch access.
        // First-time switch users can still trigger scanning via the first key/controller press.
        if GameSettings.shared.scanningEnabled {
            scanner.start()
        }
    }

    // MARK: - Conformance to ButtonNodeResponderType

    func buttonTriggered(button: ButtonNode) {
        guard let identifier = button.buttonIdentifier else { return }
        selection.selectionChanged()

        let screen: Screen?
        switch identifier {
        case .play:     screen = GameScene(fileNamed: Scenes.game.getName()).map(Screen.scene)
        case .settings: screen = .settings
        case .menu, .home: screen = .home
        default:
            debugPrint(#function, "unhandled identifier:", identifier)
            screen = nil
        }
        guard let screen = screen else { return }
        GameViewController.present(screen, in: view)
    }

    // Switch handlers live in the class so UIKit-based scenes can override routing.

    func switchPrimaryBegan() {
        focusScanner?.primaryActivate()
    }

    func switchPrimaryEnded() { }

    func switchSecondaryBegan() {
        focusScanner?.secondaryAdvance()
    }

    func switchSecondaryEnded() { }
}

extension RoutingUtilityScene: SwitchInputReceivable { }

extension RoutingUtilityScene: ScreenTransitionScanning { }
