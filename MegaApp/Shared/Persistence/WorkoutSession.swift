import Foundation
import SwiftData

// MARK: - WorkoutSession

/// Persisted workout session. `activityType` is stored as a raw String so SwiftData
/// doesn't need to encode a custom enum — use `activityTypeEnum` computed property
/// for type-safe access everywhere else in the codebase.
@Model
final class WorkoutSession {
    var id:               UUID
    var date:             Date
    /// Raw value of `ActivityType` enum — "treadmill" | "bike" | "outdoorRun"
    var activityType:     String
    var durationSeconds:  Int
    var distanceMiles:    Double?
    var calories:         Int?
    var avgHeartRateBpm:  Int?
    /// 0–10 star/effort rating
    var rating:           Int?
    var inclinePercent:   Double?
    var avgSpeedMph:      Double?
    var avgWatts:         Int?
    var notes:            String?

    /// Cascade-deletes segments when the session is deleted.
    @Relationship(deleteRule: .cascade, inverse: \TreadmillSegment.session)
    var segments: [TreadmillSegment] = []

    init(
        id:              UUID    = UUID(),
        date:            Date    = Date(),
        activityType:    String,
        durationSeconds: Int,
        distanceMiles:   Double? = nil,
        calories:        Int?    = nil,
        avgHeartRateBpm: Int?    = nil,
        rating:          Int?    = nil,
        inclinePercent:  Double? = nil,
        avgSpeedMph:     Double? = nil,
        avgWatts:        Int?    = nil,
        notes:           String? = nil
    ) {
        self.id              = id
        self.date            = date
        self.activityType    = activityType
        self.durationSeconds = durationSeconds
        self.distanceMiles   = distanceMiles
        self.calories        = calories
        self.avgHeartRateBpm = avgHeartRateBpm
        self.rating          = rating
        self.inclinePercent  = inclinePercent
        self.avgSpeedMph     = avgSpeedMph
        self.avgWatts        = avgWatts
        self.notes           = notes
    }

    // MARK: Computed

    var activityTypeEnum: ActivityType {
        ActivityType(rawValue: activityType) ?? .treadmill
    }

    /// Returns pace in min/mile, or nil when distance or duration is zero.
    var paceMinPerMile: Double? {
        guard let dist = distanceMiles, dist > 0, durationSeconds > 0 else { return nil }
        return (Double(durationSeconds) / 60.0) / dist
    }

    /// Effective average speed in mph, derived from distance + duration when no direct value.
    var computedAvgSpeedMph: Double? {
        if let spd = avgSpeedMph { return spd }
        guard let dist = distanceMiles, dist > 0, durationSeconds > 0 else { return nil }
        return dist / (Double(durationSeconds) / 3600.0)
    }
}

// MARK: - TreadmillSegment

/// A single speed interval within a treadmill session (e.g. "6.0 mph for 3 minutes").
/// `sortOrder` preserves the user-defined sequence.
@Model
final class TreadmillSegment {
    var id:              UUID
    var speedMph:        Double
    var durationSeconds: Int
    var sortOrder:       Int
    /// Back-reference to the owning session (set automatically by SwiftData via @Relationship).
    var session:         WorkoutSession?

    init(
        id:              UUID   = UUID(),
        speedMph:        Double,
        durationSeconds: Int,
        sortOrder:       Int
    ) {
        self.id              = id
        self.speedMph        = speedMph
        self.durationSeconds = durationSeconds
        self.sortOrder       = sortOrder
    }

    /// Distance covered during this segment.
    var distanceMiles: Double {
        speedMph * (Double(durationSeconds) / 3600.0)
    }
}
