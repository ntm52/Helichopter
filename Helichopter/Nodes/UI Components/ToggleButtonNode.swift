import SpriteKit

/// A type that can respond to `ToggleButtonNode` button press events.
protocol ToggleButtonNodeResponderType: AnyObject {
    func toggleButtonTriggered(toggle: ToggleButtonNode)
}

class ToggleButtonNode: ButtonNode {

    // MARK: - Properties

    var type: String

    var isOn: Bool {
        didSet {
            guard let on = state.on, let off = state.off else {
                return
            }
            on.isHidden = !isOn
            off.isHidden = isOn

            if isUserInteractionEnabled {
                toggleResponder.toggleButtonTriggered(toggle: self)
            }
        }
    }

    private var state: (on: SKLabelNode?, off: SKLabelNode?) = (on: nil, off: nil)

    var toggleResponder: ToggleButtonNodeResponderType {
        guard let responder = scene as? ToggleButtonNodeResponderType else {
            fatalError("ToggleButtonNode may only be used within a `ToggleButtonNodeResponderType` scene.")
        }
        return responder
    }

    // MARK: - Initializers

    required init?(coder aDecoder: NSCoder) {
        self.type = "Music"
        self.isOn = true

        super.init(coder: aDecoder)

        let type = self.name
        self.type = type ?? "Music"

        var onVariable = "On"
        var offVariable = "Off"

        switch self.type {
        case "Music":
            self.isOn = UserDefaults.standard.bool(for: .isMusicOn)
        case "SoundEffects":
            self.isOn = UserDefaults.standard.bool(for: .isSoundEffectsOn)
        case "PipeDistance":
            self.isOn = UserDefaults.standard.bool(for: .pipeDistance)
            onVariable = "Close"
            offVariable = "Far"
        default:
            break
        }

        // B8 fix: return nil instead of fatalError when expected child labels are absent
        guard let onState = self.childNode(withName: onVariable) as? SKLabelNode else {
            return nil
        }
        state.on = onState

        guard let offState = self.childNode(withName: offVariable) as? SKLabelNode else {
            return nil
        }
        state.off = offState
    }

    // MARK: - Methods

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        isOn = !isOn
    }

    // MARK: - Scanner & Accessibility Support

    override var accessibilityScanLabel: String {
        let base = super.accessibilityScanLabel
        return isOn ? "\(base), On" : "\(base), Off"
    }

    override func scannerActivate() {
        isOn = !isOn
    }
}
