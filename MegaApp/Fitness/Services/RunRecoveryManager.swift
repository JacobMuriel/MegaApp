import Foundation
import SwiftData
import Combine

// MARK: - RunRecoveryManager
//
// Manages the 20-second shake-to-undo window after a session is deleted.
//
// Workflow:
//   1. HistoryView calls `registerDeleted(snapshot:)` immediately after
//      calling `modelContext.delete(session)`.
//   2. RunRecoveryManager starts a 20-second countdown and sets `isPending = true`.
//   3. HistoryView shows a recovery banner with the countdown.
//   4. If the user shakes, HistoryView calls `recoverIfPossible(in:)`.
//   5. After 20 seconds (or on recovery), `isPending` resets to false.

@MainActor
final class RunRecoveryManager: ObservableObject {

    @Published var isPending:          Bool = false
    @Published var secondsRemaining:   Int  = 0

    private(set) var pendingSnapshot: SessionSnapshot?

    private var countdownTimer: AnyCancellable?

    // MARK: - Register a deletion

    /// Call this immediately after deleting the session from the context —
    /// *before* calling `try? modelContext.save()`.
    func registerDeleted(snapshot: SessionSnapshot) {
        // Cancel any existing window first
        cancelCountdown()

        pendingSnapshot  = snapshot
        secondsRemaining = 20
        isPending        = true

        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.secondsRemaining -= 1
                if self.secondsRemaining <= 0 {
                    self.cancelCountdown()
                }
            }
    }

    // MARK: - Recover

    /// Re-inserts the deleted session into `context`.
    /// Returns `true` if a session was actually recovered.
    @discardableResult
    func recoverIfPossible(in context: ModelContext) -> Bool {
        guard isPending, let snapshot = pendingSnapshot else { return false }
        let session = snapshot.makeSession()
        context.insert(session)
        try? context.save()
        cancelCountdown()
        return true
    }

    // MARK: - Cancel

    func cancelCountdown() {
        countdownTimer?.cancel()
        countdownTimer   = nil
        isPending        = false
        secondsRemaining = 0
        pendingSnapshot  = nil
    }
}
