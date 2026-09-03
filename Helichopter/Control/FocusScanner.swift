import SpriteKit
import AVFoundation

// MARK: - SwitchInputReceivable

/// Scenes and nodes that handle switch / keyboard / game-controller input conform here.
/// All methods are called on the main thread.
protocol SwitchInputReceivable: AnyObject {
    func switchPrimaryBegan()
    func switchPrimaryEnded()
    func switchSecondaryBegan()
    func switchSecondaryEnded()
}

// MARK: - FocusScanner

/// Drives the ButtonNode focus-ring scanning loop for accessible menu navigation.
///
/// Auto-scan: a dwell timer advances through buttons automatically; primary switch activates.
/// Two-switch: primary switch activates; secondary switch advances manually (no timer).
///
/// Call `start()` to begin scanning, `stop()` before the scene transitions away.
/// If scanning is not yet active, the first primary-switch press will start it automatically.
final class FocusScanner {

    /// Ordered list of buttons to scan through. Set before calling `start()`.
    var items: [ButtonNode] = []

    private(set) var isActive = false
    private(set) var currentIndex: Int = 0
    private var scanTimer: Timer?
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Public API

    func start() {
        guard !items.isEmpty else { return }
        isActive = true
        currentIndex = 0
        focusItem(at: 0)
        if GameSettings.shared.scanScheme == .autoScan {
            scheduleTimer()
        }
    }

    func stop() {
        isActive = false
        scanTimer?.invalidate()
        scanTimer = nil
        synthesizer.stopSpeaking(at: .immediate)
        items.forEach { $0.isFocused = false }
    }

    /// Primary switch: activate the focused button.
    /// If scanning hasn't started yet, this call starts it instead of activating.
    func primaryActivate() {
        guard isActive else {
            start()
            return
        }
        guard items.indices.contains(currentIndex) else { return }
        items[currentIndex].scannerActivate()
        if GameSettings.shared.scanScheme == .autoScan {
            scheduleTimer()  // reset dwell so the next item gets a full interval
        }
    }

    /// Secondary switch: manually advance to the next item.
    /// Starts scanning if not yet active.
    func secondaryAdvance() {
        guard isActive else {
            start()
            return
        }
        advanceToNext()
        if GameSettings.shared.scanScheme == .autoScan {
            scheduleTimer()  // reset dwell after manual advance
        }
    }

    // MARK: - Private

    private func advanceToNext() {
        guard !items.isEmpty else { return }
        items[safe: currentIndex]?.isFocused = false
        currentIndex = (currentIndex + 1) % items.count
        focusItem(at: currentIndex)
    }

    private func focusItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        let item = items[index]
        item.isFocused = true
        speak(item.accessibilityScanLabel)
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    private func scheduleTimer() {
        scanTimer?.invalidate()
        let interval = GameSettings.shared.scanDwellTime
        scanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceToNext()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
