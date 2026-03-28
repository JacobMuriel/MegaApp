import Foundation
import SwiftData

// MARK: - CartItem

/// A product added to the Cartly shopping cart. Macros are stored per-item so
/// the CartView can display a live macro total without additional API calls.
@Model
final class CartItem {
    var id:               UUID
    var krogerProductId:  String?
    var name:             String
    var brand:            String?
    var quantity:         Int
    var priceCents:       Int?
    var imageURL:         String?
    var aisleNumber:      String?
    // Macros per serving
    var calories:         Int?
    var proteinG:         Double?
    var carbsG:           Double?
    var fatG:             Double?

    init(
        id:              UUID    = UUID(),
        krogerProductId: String? = nil,
        name:            String,
        brand:           String? = nil,
        quantity:        Int     = 1,
        priceCents:      Int?    = nil,
        imageURL:        String? = nil,
        aisleNumber:     String? = nil,
        calories:        Int?    = nil,
        proteinG:        Double? = nil,
        carbsG:          Double? = nil,
        fatG:            Double? = nil
    ) {
        self.id              = id
        self.krogerProductId = krogerProductId
        self.name            = name
        self.brand           = brand
        self.quantity        = quantity
        self.priceCents      = priceCents
        self.imageURL        = imageURL
        self.aisleNumber     = aisleNumber
        self.calories        = calories
        self.proteinG        = proteinG
        self.carbsG          = carbsG
        self.fatG            = fatG
    }

    // MARK: Computed

    var hasMacros: Bool {
        calories != nil || proteinG != nil
    }

    var displayPrice: String {
        guard let cents = priceCents else { return "" }
        return String(format: "$%.2f", Double(cents) / 100.0)
    }

    var totalCalories: Int? {
        guard let c = calories else { return nil }
        return c * quantity
    }
}
