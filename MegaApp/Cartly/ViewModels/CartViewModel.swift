import Foundation
import SwiftData
import Observation

// MARK: - CartViewModel
//
// Light wrapper around the CartItem SwiftData store. Provides macro totals
// (summed across all items × quantity) and aisle grouping for the Aisles tab.

@Observable
@MainActor
final class CartViewModel {

    // MARK: Macro totals (computed from passed-in items for reactivity)

    func totalCalories(_ items: [CartItem]) -> Int {
        items.reduce(0) { $0 + (($1.calories ?? 0) * $1.quantity) }
    }

    func totalProtein(_ items: [CartItem]) -> Double {
        items.reduce(0) { $0 + (($1.proteinG ?? 0) * Double($1.quantity)) }
    }

    func totalCarbs(_ items: [CartItem]) -> Double {
        items.reduce(0) { $0 + (($1.carbsG ?? 0) * Double($1.quantity)) }
    }

    func totalFat(_ items: [CartItem]) -> Double {
        items.reduce(0) { $0 + (($1.fatG ?? 0) * Double($1.quantity)) }
    }

    func totalPrice(_ items: [CartItem]) -> String {
        let cents = items.reduce(0) { $0 + (($1.priceCents ?? 0) * $1.quantity) }
        return String(format: "$%.2f", Double(cents) / 100.0)
    }

    // MARK: - Aisle grouping

    /// Groups cart items by their Kroger aisle number.
    /// Items without an aisle are grouped under "Uncategorised".
    func groupedByAisle(_ items: [CartItem]) -> [(aisle: String, items: [CartItem])] {
        let groups = Dictionary(grouping: items) { $0.aisleNumber ?? "Uncategorised" }
        return groups.sorted { $0.key < $1.key }.map { (aisle: $0.key, items: $0.value) }
    }

    // MARK: - Cart mutations

    func addProduct(_ product: KrogerProduct, context: ModelContext, existing: [CartItem]) {
        if let item = existing.first(where: { $0.krogerProductId == product.id }) {
            item.quantity += 1
        } else {
            let item = CartItem(
                krogerProductId: product.id,
                name:            product.name,
                brand:           product.brand,
                quantity:        1,
                priceCents:      product.priceCents,
                imageURL:        product.imageURL,
                aisleNumber:     product.aisleNumber,
                calories:        product.calories,
                proteinG:        product.proteinG,
                carbsG:          product.carbsG,
                fatG:            product.fatG
            )
            context.insert(item)
        }
        try? context.save()
    }

    func incrementQuantity(_ item: CartItem) {
        item.quantity += 1
    }

    func decrementQuantity(_ item: CartItem, context: ModelContext) {
        if item.quantity > 1 {
            item.quantity -= 1
        } else {
            context.delete(item)
        }
        try? context.save()
    }

    func removeItem(_ item: CartItem, context: ModelContext) {
        context.delete(item)
        try? context.save()
    }

    func clearCart(items: [CartItem], context: ModelContext) {
        items.forEach { context.delete($0) }
        try? context.save()
    }
}
