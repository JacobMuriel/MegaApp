import Foundation
import SwiftData
import SwiftUI

// MARK: - PantryItem

@Model
final class PantryItem {
    var id:        UUID
    var name:      String
    var amount:    Double?
    var unit:      String?
    /// "ok" | "low" | "out"
    var status:    String
    var category:  String?
    var updatedAt: Date

    init(
        id:        UUID    = UUID(),
        name:      String,
        amount:    Double? = nil,
        unit:      String? = nil,
        status:    String  = PantryStatus.ok.rawValue,
        category:  String? = nil,
        updatedAt: Date    = Date()
    ) {
        self.id        = id
        self.name      = name
        self.amount    = amount
        self.unit      = unit
        self.status    = status
        self.category  = category
        self.updatedAt = updatedAt
    }

    var statusEnum: PantryStatus {
        PantryStatus(rawValue: status) ?? .ok
    }
}

// MARK: - PantryStatus

enum PantryStatus: String, CaseIterable {
    case ok  = "ok"
    case low = "low"
    case out = "out"

    var label: String {
        switch self {
        case .ok:  return "OK"
        case .low: return "Low"
        case .out: return "Out"
        }
    }

    var color: Color {
        switch self {
        case .ok:  return .green
        case .low: return .orange
        case .out: return .red
        }
    }
}
