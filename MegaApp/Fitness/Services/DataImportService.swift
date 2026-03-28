import Foundation
import SwiftData

// MARK: - DataImportService

/// One-time importer for workout sessions exported from the original Swift/iOS app.
/// Must run on the main actor because it touches a `ModelContext` directly.
@MainActor
final class DataImportService {

    // MARK: - Decodable shape (matches the JSON export schema)

    struct ImportedSession: Decodable {
        let id:              String
        let activityType:    String
        let date:            Date
        let durationSeconds: Int
        let distanceMiles:   Double?
        let calories:        Int?
        let heartRate:       Int?   // JSON key is "heartRate", maps to avgHeartRateBpm
        let notes:           String?
    }

    // MARK: - Activity type mapping
    //
    // The JSON uses human-readable strings ("Outdoor Run", "Treadmill", "Bike") while
    // ActivityType.rawValue is camelCase ("outdoorRun", "treadmill", "bike").
    // Automatic Codable synthesis would fail on "Outdoor Run" — use an explicit map.

    private static let activityTypeMap: [String: ActivityType] = [
        "Outdoor Run": .outdoorRun,
        "Treadmill":   .treadmill,
        "Bike":        .bike,
    ]

    // MARK: - Import

    /// Loads `fitness-export.json` from the main bundle, decodes it, and inserts sessions
    /// that don't already exist in `context` (deduplication is by UUID).
    ///
    /// - Returns: `(inserted:, skipped:)` counts.
    /// - Throws: `ImportError.fileNotFound` if the bundle resource is missing, or any
    ///   `DecodingError` / `SwiftData` error encountered during the import.
    static func importFromBundle(into context: ModelContext) throws -> (inserted: Int, skipped: Int) {
        guard let url = Bundle.main.url(forResource: "fitness-export", withExtension: "json") else {
            throw ImportError.fileNotFound
        }

        let data    = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([ImportedSession].self, from: data)

        var inserted = 0
        var skipped  = 0

        for entry in imported {
            // Skip malformed UUIDs
            guard let uuid = UUID(uuidString: entry.id) else {
                skipped += 1
                continue
            }

            // Skip unknown activity types
            guard let activityType = activityTypeMap[entry.activityType] else {
                skipped += 1
                continue
            }

            // Duplicate check — skip if a session with this UUID is already in the store
            let fetch = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.id == uuid }
            )
            let existing = (try? context.fetch(fetch)) ?? []
            guard existing.isEmpty else {
                skipped += 1
                continue
            }

            let session = WorkoutSession(
                id:              uuid,
                date:            entry.date,
                activityType:    activityType.rawValue,
                durationSeconds: entry.durationSeconds,
                distanceMiles:   entry.distanceMiles,
                calories:        entry.calories,
                avgHeartRateBpm: entry.heartRate,
                notes:           entry.notes
            )
            context.insert(session)
            inserted += 1
        }

        try context.save()
        return (inserted: inserted, skipped: skipped)
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case fileNotFound

        var errorDescription: String? {
            "fitness-export.json was not found in the app bundle."
        }
    }
}
