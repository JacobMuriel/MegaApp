import SwiftUI
import SwiftData

// MARK: - CartView
//
// Item list with per-item quantity controls, a live macro totals grid at the top,
// and a clear-all button. Tapping the macro bar shows the full macro breakdown.

struct CartView: View {
    var cartVM: CartViewModel

    @Query private var items: [CartItem]
    @Environment(\.modelContext) private var modelContext

    @State private var showClearAlert = false

    var body: some View {
        VStack(spacing: 0) {
            if !items.isEmpty {
                macroBar
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                Divider()
            }

            if items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(items) { item in
                        CartItemRow(
                            item: item,
                            onIncrement: { cartVM.incrementQuantity(item) },
                            onDecrement: { cartVM.decrementQuantity(item, context: modelContext) }
                        )
                    }
                    .onDelete { offsets in
                        offsets.map { items[$0] }.forEach { cartVM.removeItem($0, context: modelContext) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Cart (\(items.count))")
        .toolbar {
            if !items.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear", role: .destructive) { showClearAlert = true }
                        .foregroundStyle(Theme.Cartly.danger)
                }
            }
        }
        .alert("Clear Cart?", isPresented: $showClearAlert) {
            Button("Clear All", role: .destructive) {
                cartVM.clearCart(items: items, context: modelContext)
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Macro bar

    private var macroBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            CartMacroCell(label: "Cal",     value: "\(cartVM.totalCalories(items))")
            CartMacroCell(label: "Protein", value: Format.decimal(cartVM.totalProtein(items), places: 1) + "g")
            CartMacroCell(label: "Carbs",   value: Format.decimal(cartVM.totalCarbs(items),   places: 1) + "g")
            CartMacroCell(label: "Fat",     value: Format.decimal(cartVM.totalFat(items),      places: 1) + "g")
            Spacer()
            Text(cartVM.totalPrice(items))
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.Cartly.textPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "cart")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Cartly.textSecondary)
            Text("Your cart is empty")
                .font(.headline)
                .foregroundStyle(Theme.Cartly.textSecondary)
            Text("Search for products to add them here.")
                .font(.subheadline)
                .foregroundStyle(Theme.Cartly.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - CartItemRow

private struct CartItemRow: View {
    let item:        CartItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Cartly.textPrimary)
                if let brand = item.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(Theme.Cartly.textSecondary)
                }
                if item.hasMacros {
                    HStack(spacing: 6) {
                        if let cal = item.calories {
                            Text("\(cal * item.quantity) kcal")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.Cartly.textSecondary)
                        }
                        if let p = item.proteinG {
                            Text(Format.decimal(p * Double(item.quantity), places: 1) + "g P")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.Cartly.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            // Quantity stepper
            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onDecrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.Cartly.textSecondary)
                }
                Text("\(item.quantity)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 24)
                Button(action: onIncrement) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.Cartly.primaryAccent)
                }
            }
            .buttonStyle(.plain)

            if let price = item.priceCents {
                Text(String(format: "$%.2f", Double(price * item.quantity) / 100.0))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.Cartly.textPrimary)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CartMacroCell

private struct CartMacroCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.Cartly.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.Cartly.textSecondary)
        }
    }
}
