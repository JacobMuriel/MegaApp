import SwiftUI
import SwiftData

// MARK: - AislesView
//
// Groups cart items by Kroger aisle number so you can walk the store in order.
// Items without an aisle number appear under "Uncategorised".

struct AislesView: View {
    var cartVM: CartViewModel

    @Query private var items: [CartItem]
    @Environment(\.modelContext) private var modelContext

    private var grouped: [(aisle: String, items: [CartItem])] {
        cartVM.groupedByAisle(items)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(grouped, id: \.aisle) { group in
                        Section(header: aisleHeader(group.aisle)) {
                            ForEach(group.items) { item in
                                AisleItemRow(item: item)
                            }
                            .onDelete { offsets in
                                offsets.map { group.items[$0] }.forEach { cartVM.removeItem($0, context: modelContext) }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Aisles")
    }

    // MARK: - Aisle header

    private func aisleHeader(_ aisle: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "tag.fill")
                .font(.caption)
                .foregroundStyle(Theme.Cartly.primaryAccent)
            Text("Aisle \(aisle)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Cartly.textPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "map")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Cartly.textSecondary)
            Text("No items in cart")
                .font(.headline)
                .foregroundStyle(Theme.Cartly.textSecondary)
            Text("Add products in the Search tab and they'll appear here grouped by aisle.")
                .font(.subheadline)
                .foregroundStyle(Theme.Cartly.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - AisleItemRow

private struct AisleItemRow: View {
    let item: CartItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Cartly.textPrimary)
                if let brand = item.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(Theme.Cartly.textSecondary)
                }
            }
            Spacer()
            Text("×\(item.quantity)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.Cartly.textSecondary)
        }
        .padding(.vertical, 2)
    }
}
