import SpriteKit

/// A type that can respond to `ButtonNode` button press events.
protocol ButtonNodeResponderType: AnyObject {
    func buttonTriggered(button: ButtonNode)
}

/// The complete set of button identifiers supported in the app.
enum ButtonIdentifier: String {
    case play = "Play"
    case pause = "Pause"
    case resume = "Resume"
    case menu = "Menu"
    case home = "Home"
    case settings = "Settings"
    case retry = "Retry"
    case cancel = "Cancel"
    case scores = "Scores"
    case soundEffects = "SoundEffects"
    case music = "Music"
    case pipeDistance = "PipeDistance"
    case characters = "Characters"
    case difficulty = "Difficulty"
    // Phase 5
    case noFail = "NoFail"
    case calmMode = "CalmMode"
    case showScore = "ShowScore"

    static let allButtonIdentifiers: [ButtonIdentifier] = [
        .play, .pause, .resume, .menu, .settings, .home, .retry, .cancel, .scores,
        .soundEffects, .music, .pipeDistance, .characters, .difficulty,
        .noFail, .calmMode, .showScore
    ]
}

/// A custom sprite node that represents a pressable and selectable button in a scene.
class ButtonNode: SKSpriteNode {

    // MARK: Properties

    // Keep archived nodes as action/scanner models, with UIKit owning presentation.
    var isPresentedInUIKit = false {
        didSet {
            if isPresentedInUIKit {
                alpha = 0
                isUserInteractionEnabled = false
            }
        }
    }

    var buttonIdentifier: ButtonIdentifier!

    var responder: ButtonNodeResponderType {
        guard let responder = scene as? ButtonNodeResponderType else {
            fatalError("ButtonNode may only be used within a `ButtonNodeResponderType` scene.")
        }
        return responder
    }

    /// Baseline blend factor applied by the active UI theme.
    /// Preserved when transitioning out of highlight so the theme tint isn't lost.
    var themeColorBlendFactor: CGFloat = 0.0

    var isHighlighted = false {
        didSet {
            guard oldValue != isHighlighted else { return }
            removeAllActions()
            let newScale: CGFloat = isHighlighted ? 0.99 : 1.01
            let scaleAction = SKAction.scale(by: newScale, duration: 0.15)
            let newColorBlendFactor: CGFloat = isHighlighted ? 1.0 : themeColorBlendFactor
            let colorBlendAction = SKAction.colorize(withColorBlendFactor: newColorBlendFactor, duration: 0.15)
            run(SKAction.group([scaleAction, colorBlendAction]))
        }
    }

    var isSelected = false {
        didSet {
            texture = isSelected ? selectedTexture : defaultTexture
        }
    }

    var defaultTexture: SKTexture?
    var selectedTexture: SKTexture?

    var isFocused = false {
        didSet {
            // Apply immediately: SKActions do not advance while the game is paused.
            focusRing.isHidden = !isFocused
            focusRing.alpha = 1
        }
    }

    lazy var focusRing: SKNode = {
        if let existing = childNode(withName: "focusRing") { return existing }
        let ring = SKShapeNode(rect: CGRect(
            x: -size.width * anchorPoint.x - 6,
            y: -size.height * anchorPoint.y - 6,
            width: size.width + 12, height: size.height + 12), cornerRadius: 8)
        ring.name = "focusRing"
        ring.strokeColor = GameSettings.shared.selectedTheme.titleTextColor
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.zPosition = 100
        ring.isHidden = true
        addChild(ring)
        return ring
    }()

    // MARK: Initializers

    override init(texture: SKTexture?, color: SKColor, size: CGSize) {
        super.init(texture: texture, color: color, size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // B8 fix: return nil instead of fatalError when button name is unrecognised
        guard let nodeName = name, let buttonIdentifier = ButtonIdentifier(rawValue: nodeName) else {
            return nil
        }
        self.buttonIdentifier = buttonIdentifier

        defaultTexture  = texture
        selectedTexture = texture

        focusRing.isHidden = true
        isUserInteractionEnabled = true
    }

    override func copy(with zone: NSZone? = nil) -> Any {
        let newButton = super.copy(with: zone) as! ButtonNode
        newButton.buttonIdentifier = buttonIdentifier
        newButton.defaultTexture = defaultTexture?.copy() as? SKTexture
        newButton.selectedTexture = selectedTexture?.copy() as? SKTexture
        return newButton
    }

    func buttonTriggered() {
        if isUserInteractionEnabled || isPresentedInUIKit {
            responder.buttonTriggered(button: self)
        }
    }

    // MARK: - Scanner & Accessibility Support

    /// Human-readable label spoken by FocusScanner and read by VoiceOver / Switch Control.
    var accessibilityScanLabel: String {
        guard let id = buttonIdentifier else { return name ?? "Button" }
        switch id {
        case .play:         return "Play"
        case .pause:        return "Pause"
        case .resume:       return "Resume"
        case .menu:         return "Menu"
        case .home:         return "Home"
        case .settings:     return "Settings"
        case .retry:        return "Try Again"
        case .cancel:       return "Cancel"
        case .scores:       return "Scores"
        case .soundEffects: return "Sound Effects"
        case .music:        return "Music"
        case .pipeDistance: return "Pipe Gap"
        case .characters:   return "Characters"
        case .difficulty:   return "Difficulty"
        case .noFail:       return "No-Fail Mode"
        case .calmMode:     return "Calm Mode"
        case .showScore:    return "Show Score"
        }
    }

    /// VoiceOver hint describing what activating this button does.
    var accessibilityScanHint: String {
        guard let id = buttonIdentifier else { return "" }
        switch id {
        case .play:         return "Starts a new game"
        case .pause:        return "Pauses the game"
        case .resume:       return "Resumes the game"
        case .menu, .home:  return "Goes to the main menu"
        case .settings:     return "Opens settings"
        case .retry:        return "Starts a new game"
        case .cancel:       return "Dismisses this screen"
        case .scores:       return "Shows your high scores"
        case .soundEffects: return "Toggles sound effects on or off"
        case .music:        return "Toggles background music on or off"
        case .pipeDistance: return "Toggles wide or narrow pipe gaps"
        case .characters:   return "Changes the playable character"
        case .difficulty:   return "Cycles through Easy, Medium, and Hard"
        case .noFail:       return "Toggles no-fail practice mode on or off"
        case .calmMode:     return "Toggles calm mode — suppresses hit sounds and haptics"
        case .showScore:    return "Toggles score display on or off"
        }
    }

    /// Called by FocusScanner and iOS Switch Control to activate this button.
    /// Subclasses override to perform the type-appropriate action.
    func scannerActivate() {
        buttonTriggered()
    }

    /// Returns the button's frame in UIKit screen coordinates for UIAccessibilityElement proxies.
    func accessibilityScreenFrame(in skView: SKView) -> CGRect {
        guard let scene = scene else { return .zero }
        let pos = convert(CGPoint.zero, to: scene)
        let halfW = frame.width / 2
        let halfH = frame.height / 2
        let viewTL = skView.convert(CGPoint(x: pos.x - halfW, y: pos.y + halfH), from: scene)
        let viewBR = skView.convert(CGPoint(x: pos.x + halfW, y: pos.y - halfH), from: scene)
        let viewRect = CGRect(
            x: min(viewTL.x, viewBR.x),
            y: min(viewTL.y, viewBR.y),
            width: abs(viewBR.x - viewTL.x),
            height: abs(viewBR.y - viewTL.y)
        )
        return UIAccessibility.convertToScreenCoordinates(viewRect, in: skView)
    }

    // MARK: Responder

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        isHighlighted = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        isHighlighted = false
        if containsTouches(touches: touches) {
            buttonTriggered()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches!, with: event)
        isHighlighted = false
    }

    private func containsTouches(touches: Set<UITouch>) -> Bool {
        guard let scene = scene else { return false }
        return touches.contains { touch in
            let touchPoint = touch.location(in: scene)
            let touchedNode = scene.atPoint(touchPoint)
            return touchedNode === self || touchedNode.inParentHierarchy(self)
        }
    }

    #endif
}
