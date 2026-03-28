import Foundation
import SwiftData

// MARK: - SessionSnapshot
//
// A plain-struct copy of a WorkoutSession used for:
//   1. Passing session data across actor boundaries (SwiftData @Model objects are
//      actor-isolated; plain structs are sendable).
//   2. Undo state in RunRecoveryManager — we store the snapshot before deletion
//      so we can reconstruct the session if the user shakes within 20 seconds.
//
// Keep this in sync with WorkoutSession whenever new fields are added.

struct SessionSnapshot: Sendable {
    let id:              UUID
    let date:            Date
    let activityType:    String
    let durationSeconds: Int
    let distanceMiles:   Double?
    let calories:        Int?
    let avgHeartRateBpm: Int?
    let rating:          Int?
    let inclinePercent:  Double?
    let avgSpeedMph:     Double?
    let avgWatts:        Int?
    let notes:           String?
    let segments:        [TreadmillSegmentSnapshot]

    /// Reconstruct a live SwiftData model from this snapshot.
    /// The caller is responsible for inserting it into a ModelContext.
    @MainActor
    func makeSession() -> WorkoutSession {
        let session = WorkoutSession(
            id:              id,
            date:            date,
            activityType:    activityType,
            durationSeconds: durationSeconds,
            distanceMiles:   distanceMiles,
            calories:        calories,
            avgHeartRateBpm: avgHeartRateBpm,
            rating:          rating,
            inclinePercent:  inclinePercent,
            avgSpeedMph:     avgSpeedMph,
            avgWatts:        avgWatts,
            notes:           notes
        )
        session.segments = segments.enumerated().map { idx, snap in
            TreadmillSegment(
                id:              snap.id,
                speedMph:        snap.speedMph,
                durationSeconds: snap.durationSeconds,
                sortOrder:       idx
            )
        }
        return session
    }
}

// MARK: - TreadmillSegmentSnapshot

struct TreadmillSegmentSnapshot: Sendable {
    let id:              UUID
    let speedMph:        Double
    let durationSeconds: Int
}

// MARK: - WorkoutSession convenience init

extension SessionSnapshot {
    /// Snapshot the current state of a WorkoutSession for safe cross-actor use.
    @MainActor
    init(from session: WorkoutSession) {
        id              = session.id
        date            = session.date
        activityType    = session.activityType
        durationSeconds = session.durationSeconds
        distanceMiles   = session.distanceMiles
        calories        = session.calories
        avgHeartRateBpm = session.avgHeartRateBpm
        rating          = session.rating
        inclinePercent  = session.inclinePercent
        avgSpeedMph     = session.avgSpeedMph
        avgWatts        = session.avgWatts
        notes           = session.notes
        segments        = session.segments
            .sorted { $0.sortOrder < $1.sortOrder }
            .map    { TreadmillSegmentSnapshot(id: $0.id, speedMph: $0.speedMph, durationSeconds: $0.durationSeconds) }
    }
}
