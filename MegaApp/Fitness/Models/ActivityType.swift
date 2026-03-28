import Foundation

// MARK: - ActivityType

enum ActivityType: String, CaseIterable, Identifiable, Codable {
    case treadmill  = "treadmill"
    case bike       = "bike"
    case outdoorRun = "outdoorRun"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .treadmill:  return "Treadmill"
        case .bike:       return "Bike"
        case .outdoorRun: return "Outdoor Run"
        }
    }

    var systemImage: String {
        switch self {
        case .treadmill:  return "figure.walk"
        case .bike:       return "figure.outdoor.cycle"
        case .outdoorRun: return "figure.run"
        }
    }
}

// MARK: - ActivityFilter

/// Used by HistoryView to narrow the session list.
enum ActivityFilter: String, CaseIterable, Identifiable {
    case all        = "All"
    case treadmill  = "Treadmill"
    case bike       = "Bike"
    case outdoorRun = "Outdoor Run"

    var id: String { rawValue }

    /// Returns nil when the filter is `.all`, otherwise the matching ActivityType raw value.
    var activityTypeRawValue: String? {
        switch self {
        case .all:        return nil
        case .treadmill:  return ActivityType.treadmill.rawValue
        case .bike:       return ActivityType.bike.rawValue
        case .outdoorRun: return ActivityType.outdoorRun.rawValue
        }
    }
}
