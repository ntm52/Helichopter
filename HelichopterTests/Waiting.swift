import Foundation

/// Polls `condition` on the main actor until it is true or `timeout` passes, and
/// returns the final result. Use it to wait for timers to fire: a fixed sleep can
/// end before a timer that a loaded simulator has delayed.
@MainActor
func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async throws -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline { return false }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    return true
}
