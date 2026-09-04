import Testing
import SpriteKit
@testable import Helichopter

// ButtonNode.init(texture:color:size:) creates a bare node with no scene.
// isFocused runs SKActions that queue but don't execute without a scene — safe in tests.
// AVSpeechSynthesizer.speak is called but produces no audible output on simulators.
private func makeButton() -> ButtonNode {
    ButtonNode(texture: nil, color: .clear, size: .zero)
}

@Suite("FocusScanner", .serialized) struct FocusScannerTests {

    // MARK: - Initial state

    @Test func initialStateIsInactive() {
        let scanner = FocusScanner()
        #expect(!scanner.isActive)
        #expect(scanner.currentIndex == 0)
    }

    // MARK: - start()

    @Test func startWithNoItemsDoesNotActivate() {
        let scanner = FocusScanner()
        scanner.start()
        #expect(!scanner.isActive)
    }

    @Test func startWithItemsActivatesAtIndexZero() {
        let scanner = FocusScanner()
        scanner.items = [makeButton(), makeButton()]
        scanner.start()
        defer { scanner.stop() }
        #expect(scanner.isActive)
        #expect(scanner.currentIndex == 0)
    }

    // MARK: - stop()

    @Test func stopDeactivates() {
        let scanner = FocusScanner()
        scanner.items = [makeButton()]
        scanner.start()
        scanner.stop()
        #expect(!scanner.isActive)
    }

    // MARK: - primaryActivate()

    @Test func primaryActivateStartsScannerWhenInactive() {
        let scanner = FocusScanner()
        scanner.items = [makeButton(), makeButton()]
        #expect(!scanner.isActive)
        scanner.primaryActivate()
        defer { scanner.stop() }
        #expect(scanner.isActive)
    }

    // MARK: - secondaryAdvance()

    @Test func secondaryAdvanceStartsScannerWhenInactive() {
        let scanner = FocusScanner()
        scanner.items = [makeButton(), makeButton()]
        scanner.secondaryAdvance()
        defer { scanner.stop() }
        #expect(scanner.isActive)
    }

    @Test func secondaryAdvanceIncrementsIndex() {
        let savedScheme = GameSettings.shared.scanScheme
        defer { GameSettings.shared.scanScheme = savedScheme }
        GameSettings.shared.scanScheme = .twoSwitch

        let scanner = FocusScanner()
        scanner.items = [makeButton(), makeButton(), makeButton()]
        scanner.start()
        defer { scanner.stop() }

        #expect(scanner.currentIndex == 0)
        scanner.secondaryAdvance()
        #expect(scanner.currentIndex == 1)
        scanner.secondaryAdvance()
        #expect(scanner.currentIndex == 2)
    }

    @Test func secondaryAdvanceWrapsAroundToZero() {
        let savedScheme = GameSettings.shared.scanScheme
        defer { GameSettings.shared.scanScheme = savedScheme }
        GameSettings.shared.scanScheme = .twoSwitch

        let scanner = FocusScanner()
        scanner.items = [makeButton(), makeButton()]
        scanner.start()
        defer { scanner.stop() }

        scanner.secondaryAdvance()   // 0 -> 1
        scanner.secondaryAdvance()   // 1 -> 0 (wrap)
        #expect(scanner.currentIndex == 0)
    }

    // MARK: - Auto-scan timer

    // Schedules a 50 ms dwell timer and confirms the index advances within 300 ms.
    // @MainActor ensures Timer is scheduled on the main run loop so it fires during Task.sleep.
    @Test @MainActor func autoScanTimerAdvancesIndex() async throws {
        let savedScheme = GameSettings.shared.scanScheme
        let savedDwell  = GameSettings.shared.scanDwellTime
        defer {
            GameSettings.shared.scanScheme    = savedScheme
            GameSettings.shared.scanDwellTime = savedDwell
        }
        GameSettings.shared.scanScheme    = .autoScan
        GameSettings.shared.scanDwellTime = 0.05   // 50 ms

        let scanner = FocusScanner()
        scanner.items = [makeButton(), makeButton(), makeButton()]
        scanner.start()
        defer { scanner.stop() }

        #expect(scanner.currentIndex == 0)
        try await Task.sleep(nanoseconds: 300_000_000)   // 300 ms — timer fires >= 4x
        #expect(scanner.currentIndex > 0)
    }
}
