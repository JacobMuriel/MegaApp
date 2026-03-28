import Foundation

// MARK: - KrogerProduct
//
// Represents a product returned from the Kroger product search proxy (server.js).
// Fields mirror the proxy's JSON response schema.

struct KrogerProduct: Identifiable, Codable, Hashable {
    let id:          String
    let name:        String
    let brand:       String?
    let priceCents:  Int?
    let imageURL:    String?
    let aisleNumber: String?
    // Nutrition per serving
    let calories:    Int?
    let proteinG:    Double?
    let carbsG:      Double?
    let fatG:        Double?

    var displayPrice: String {
        guard let cents = priceCents else { return "" }
        return String(format: "$%.2f", Double(cents) / 100.0)
    }

    var hasMacros: Bool {
        calories != nil || proteinG != nil
    }

    // Coding keys to map from proxy's snake_case / camelCase responses
    enum CodingKeys: String, CodingKey {
        case id, name, brand
        case priceCents  = "price_cents"
        case imageURL    = "image_url"
        case aisleNumber = "aisle_number"
        case calories, proteinG = "protein_g", carbsG = "carbs_g", fatG = "fat_g"
    }
}

// MARK: - KrogerStore

struct KrogerStore: Identifiable, Codable {
    let id:      String
    let name:    String
    let address: String
    let city:    String
    let state:   String
    let zip:     String

    var displayAddress: String { "\(address), \(city), \(state) \(zip)" }

    enum CodingKeys: String, CodingKey {
        case id = "locationId", name, address, city, state, zip
    }
}
