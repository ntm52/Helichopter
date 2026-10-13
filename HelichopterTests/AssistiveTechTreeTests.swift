import Testing
import SpriteKit
import UIKit
@testable import Helichopter

/// VoiceOver and Voice Control cannot run in the simulator, but both read the same
/// accessibility tree. These tests walk that tree as VoiceOver does and check what
/// a player would hear, and which names Voice Control would offer.
@MainActor @Suite("VoiceOver and Voice Control tree", .serialized)
struct AssistiveTechTreeTests {

    /// The elements VoiceOver visits, in order. The test host does not load UIKit's
    /// accessibility runtime, so labels and controls get their system defaults here:
    /// each is one element, named by its text unless the app set a label.
    private func elements(in object: NSObject) -> [NSObject] {
        if let view = object as? UIView, view.isHidden || view.alpha == 0 || view.accessibilityElementsHidden { return [] }
        // VoiceOver visits segments; UIKit builds them, so treat the control as one stop here.
        if object is UISegmentedControl { return [object] }
        if object.isAccessibilityElement || object is UIControl || ((object as? UILabel)?.text ?? "") != "" { return [object] }
        let children = (object.accessibilityElements as? [NSObject]) ?? (object as? UIView)?.subviews ?? []
        return children.flatMap { elements(in: $0) }
    }

    private func spoken(_ element: NSObject) -> String {
        element.accessibilityLabel ?? (element as? UIButton)?.currentTitle ?? (element as? UILabel)?.text ?? ""
    }

    private func isActionable(_ element: NSObject) -> Bool {
        element is UIControl || element.accessibilityTraits.contains(.button)
    }

    /// Settings controls hold their actions weakly, so the panel must stay alive.
    private func makeSettings(locked: Bool = false) -> (SettingsPanelView, UIWindow) {
        GameSettings.shared.isSettingsLocked = locked
        let size = CGSize(width: 390, height: 844)
        let panel = SettingsPanelView(frame: CGRect(origin: .zero, size: size), theme: GameSettings.shared.selectedTheme)
        let window = makeTestWindow(frame: CGRect(origin: .zero, size: size))
        let host = UIViewController()
        host.view = panel
        window.rootViewController = host
        window.makeKeyAndVisible()
        panel.layoutIfNeeded()
        return (panel, window)
    }

    @Test func settingsReadsEachSettingOnceWithRealHeadings() throws {
        let savedLock = GameSettings.shared.isSettingsLocked
        defer { GameSettings.shared.isSettingsLocked = savedLock }
        let (panel, window) = makeSettings()
        defer { window.isHidden = true }
        let read = elements(in: panel)
        let labels = read.map(spoken)

        let back = try #require(read.first)
        #expect(spoken(back) == "Back", "Back must not read its arrow symbol")
        for name in ["Gap Size", "Pipe Speed", "No-Fail Mode", "Calm Mode", "Show Score", "Scan Dwell Time", "Lock Settings"] {
            #expect(labels.filter { $0 == name }.count == 1, "\(name) is read \(labels.filter { $0 == name }.count) times")
        }
        // Slider ends and setting descriptions are spoken by the control, not separately.
        #expect(!labels.contains("Narrow") && !labels.contains("How wide the opening between pipes is"))
        let gap = try #require(read.first { spoken($0) == "Gap Size" } as? UISlider)
        #expect(gap.accessibilityHint?.contains("Narrow to Wide") == true)

        let headings = read.filter { $0.accessibilityTraits.contains(.header) }.map(spoken)
        #expect(headings.contains("Settings"))
        for section in ["Difficulty Preset", "Gameplay", "Comfort", "Switch Access", "Colour Accessibility", "Caregiver", "About"] {
            #expect(headings.contains(section), "\(section) is not a heading")
        }
    }

    @Test func sliderActivationOpensLargeButtons() throws {
        let savedLock = GameSettings.shared.isSettingsLocked
        defer { GameSettings.shared.isSettingsLocked = savedLock }
        let (panel, window) = makeSettings()
        defer { window.isHidden = true }
        let gap = try #require(elements(in: panel).first { spoken($0) == "Gap Size" } as? UISlider)
        let before = gap.value
        // VoiceOver double-tap or Switch Control select; a finger tap does not do this.
        #expect(gap.accessibilityActivate())
        #expect(panel.isAdjusting)
        let names = elements(in: try #require(panel.adjustmentPanel)).filter(isActionable).map(spoken)
        #expect(names.contains { $0.hasPrefix("Decrease") } && names.contains { $0.hasPrefix("Increase") } && names.contains("Done"))
        #expect(gap.value == before)
        // Values are spoken as players think of them, never as "3.1e+02".
        #expect(names.contains("Increase. Value: \(gap.spokenValue)") && gap.spokenValue.hasSuffix("%"))
        #expect(!gap.spokenValue.contains("e+"))
        panel.closeAdjustment()
        let dwell = try #require(elements(in: panel).first { spoken($0) == "Scan Dwell Time" } as? UISlider)
        #expect(dwell.accessibilityValue == String(format: "%.1f seconds", dwell.value))
        #expect(!panel.isAdjusting)
    }

    /// Voice Control shows numbers instead of names when two choices share a name, so
    /// every Settings control and segment must be uniquely named.
    @Test func settingsChoicesHaveUniqueNames() throws {
        let savedLock = GameSettings.shared.isSettingsLocked
        defer { GameSettings.shared.isSettingsLocked = savedLock }
        let (panel, window) = makeSettings()
        defer { window.isHidden = true }
        var names: [String] = []
        for element in elements(in: panel) {
            if let segments = element as? UISegmentedControl {
                names += (0..<segments.numberOfSegments).compactMap { segments.titleForSegment(at: $0) }
            } else if isActionable(element) {
                names.append(spoken(element))
            }
        }
        let repeated = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys
        #expect(repeated.isEmpty, "Shared names: \(repeated.sorted())")
        #expect(names.contains("Step with Switch 2") && names.contains("Up/Down Switches"))
    }

    @Test func lockedSettingsAreDimmed() throws {
        let savedLock = GameSettings.shared.isSettingsLocked
        defer { GameSettings.shared.isSettingsLocked = savedLock }
        let (panel, window) = makeSettings(locked: true)
        defer { window.isHidden = true }
        let controls = elements(in: panel).compactMap { $0 as? UIControl }
        let open = Set(controls.filter(\.isEnabled).compactMap { $0.accessibilityLabel })
        #expect(open == ["Back", "Lock Settings", "Privacy Policy", "Acknowledgements"])
    }

    @Test func everyControlHasASpeakableName() throws {
        let savedLock = GameSettings.shared.isSettingsLocked
        defer { GameSettings.shared.isSettingsLocked = savedLock }
        let home = HomeViewController()
        let guide = GuideViewController()
        let (settings, window) = makeSettings()
        defer { window.isHidden = true }
        for (screen, root) in [("Home", home.view!), ("Guide", guide.view!), ("Settings", settings)] {
            root.layoutIfNeeded()
            let actionable = elements(in: root).filter(isActionable)
            #expect(!actionable.isEmpty)
            for element in actionable {
                let name = spoken(element)
                // Voice Control says what is shown; a symbol or empty name forces numbers.
                #expect(!name.isEmpty, "\(screen): unnamed control")
                #expect(name.unicodeScalars.allSatisfy { CharacterSet.letters.union(.decimalDigits).union(.whitespaces).union(.punctuationCharacters).contains($0) },
                        "\(screen): \(name) has symbols")
            }
        }
    }

    /// Dragging Control Center's text-size slider sends many changes in a row. Each
    /// rebuild must replace the panel, not leave fading panels that rebuild again.
    @Test func rapidTextSizeChangesLeaveOneLivePanel() throws {
        let settings = SettingsViewController()
        let window = makeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = settings
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        settings.view.layoutIfNeeded()
        for size in [UIContentSizeCategory.large, .extraLarge, .accessibilityMedium, .small, .accessibilityExtraExtraExtraLarge, .large] {
            settings.traitOverrides.preferredContentSizeCategory = size
            settings.view.layoutIfNeeded()
        }
        let panels = settings.view.subviews.compactMap { $0 as? SettingsPanelView }
        #expect(panels.filter { $0.onThemeChanged != nil }.count == 1)
        #expect(panels.filter { !$0.accessibilityElementsHidden }.count == 1)
        #expect(panels.count <= 7, "\(panels.count) panels after 6 changes")
    }

    @Test func gameplayOffersShortVoiceControlNames() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scene = try #require(GameScene(fileNamed: "GameScene"))
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let overlay = SceneTextOverlay(frame: view.bounds)
        view.addSubview(overlay)
        overlay.refresh(in: view)
        let read = elements(in: overlay)
        let flight = try #require(read.first as? FlightAccessibilityElement)
        #expect(flight.accessibilityUserInputLabels.first == "Fly")
        #expect(flight.accessibilityUserInputLabels.contains("Helicopter flight control"))
        #expect(read.contains { spoken($0) == "Pause" && isActionable($0) })
    }
}
