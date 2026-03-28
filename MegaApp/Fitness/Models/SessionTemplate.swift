import Foundation

// MARK: - SessionTemplate
//
// Pre-filled workout presets shown in SessionEditorView's template picker.
// Choosing a template populates the editor form with sensible defaults —
// the user can still override any field before saving.

enum SessionTemplate: String, CaseIterable, Identifiable {
    case treadmillEasy       = "Treadmill — Easy Pace"
    case treadmillIntervals  = "Treadmill — Intervals"
    case bikeSteady          = "Bike — Steady State"

    var id: String { rawValue }

    var activityType: ActivityType {
        switch self {
        case .treadmillEasy, .treadmillIntervals: return .treadmill
        case .bikeSteady:                          return .bike
        }
    }

    var defaultDurationSeconds: Int {
        switch self {
        case .treadmillEasy:      return 30 * 60   // 30 min
        case .treadmillIntervals: return 25 * 60   // 25 min
        case .bikeSteady:         return 45 * 60   // 45 min
        }
    }

    var defaultDistanceMiles: Double? {
        switch self {
        case .treadmillEasy:      return 2.5
        case .treadmillIntervals: return 2.0
        case .bikeSteady:         return nil
        }
    }

    var defaultSpeedMph: Double? {
        switch self {
        case .treadmillEasy:      return 5.0
        case .treadmillIntervals: return nil  // speed varies per segment
        case .bikeSteady:         return nil
        }
    }

    var defaultWatts: Int? {
        switch self {
        case .bikeSteady: return 175
        default:          return nil
        }
    }

    var defaultIncline: Double? {
        switch self {
        case .treadmillEasy: return 1.0
        default:             return nil
        }
    }

    /// Pre-filled treadmill segments.  Empty for non-treadmill templates.
    var defaultSegments: [(speedMph: Double, durationSeconds: Int)] {
        switch self {
        case .treadmillIntervals:
            // Warm-up + 5 × (fast / recovery) + cool-down
            return [
                (5.0, 5 * 60),
                (7.5, 2 * 60),
                (5.5, 1 * 60),
                (7.5, 2 * 60),
                (5.5, 1 * 60),
                (7.5, 2 * 60),
                (5.5, 1 * 60),
                (7.5, 2 * 60),
                (5.5, 1 * 60),
                (7.5, 2 * 60),
                (5.0, 5 * 60),
            ]
        default:
            return []
        }
    }
}
