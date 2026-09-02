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

    static let allButtonIdentifiers: [ButtonIdentifier] = [
        .play, .pause, .resume, .menu, .settings, .home, .retry, .cancel, .scores, .soundEffects, .music, .pipeDistance, .characters, .difficulty
    ]

    var selectedTextureName: String? {
        switch self {
        default:
            return nil
        }
    }
}

/// A custom sprite node that represents a pressable and selectable button in a scene.
class ButtonNode: SKSpriteNode {

    // MARK: Properties

    var buttonIdentifier: ButtonIdentifier!

    var responder: ButtonNodeResponderType {
        guard let responder = scene as? ButtonNodeResponderType else {
            fatalError("ButtonNode may only be used within a `ButtonNodeResponderType` scene.")
        }
        return responder
    }

    var isHighlighted = false {
        didSet {
            guard oldValue != isHighlighted else { return }
            removeAllActions()
            let newScale: CGFloat = isHighlighted ? 0.99 : 1.01
            let scaleAction = SKAction.scale(by: newScale, duration: 0.15)
            let newColorBlendFactor: CGFloat = isHighlighted ? 1.0 : 0.0
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
    var focusableNeighbors = [ControlInputDirection: ButtonNode]()

    var isFocused = false {
        didSet {
            if isFocused {
                run(SKAction.scale(to: 1.08, duration: 0.20))
                focusRing?.alpha = 0.0
                focusRing?.isHidden = false
                focusRing?.run(SKAction.fadeIn(withDuration: 0.2))
            } else {
                run(SKAction.scale(to: 1.0, duration: 0.20))
                focusRing?.isHidden = true
            }
        }
    }

    // B8 fix: optional — not every button in a .sks file has a focusRing child node
    lazy var focusRing: SKNode? = childNode(withName: "focusRing")

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

        defaultTexture = texture

        if let textureName = buttonIdentifier.selectedTextureName {
            selectedTexture = SKTexture(imageNamed: textureName)
        } else {
            selectedTexture = texture
        }

        focusRing?.isHidden = true
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
        if isUserInteractionEnabled {
            responder.buttonTriggered(button: self)
        }
    }

    func performInvalidFocusChangeAnimationForDirection(direction: ControlInputDirection) {
        let animationKey = "ButtonNode.InvalidFocusChangeAnimationKey"
        guard action(forKey: animationKey) == nil else { return }

        let theAction: SKAction
        switch direction {
        case .up:    theAction = SKAction(named: "InvalidFocusChange_Up")!
        case .down:  theAction = SKAction(named: "InvalidFocusChange_Down")!
        case .left:  theAction = SKAction(named: "InvalidFocusChange_Left")!
        case .right: theAction = SKAction(named: "InvalidFocusChange_Right")!
        }
        run(theAction, withKey: animationKey)
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

    #elseif os(OSX)
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isHighlighted = true
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isHighlighted = false
        if containsLocationForEvent(event) {
            buttonTriggered()
        }
    }

    private func containsLocationForEvent(_ event: NSEvent) -> Bool {
        guard let scene = scene else { return false }
        let location = event.location(in: scene)
        let clickedNode = scene.atPoint(location)
        return clickedNode === self || clickedNode.inParentHierarchy(self)
    }
    #endif
}
