import SwiftUI
import SwiftData

// MARK: - SearchView
//
// Kroger product search via the Express proxy (server.js on :3001).
// Flow: enter zip → pick store → search term → product grid → add to cart.

struct SearchView: View {
    var cartVM: CartViewModel

    @Query private var cartItems: [CartItem]
    @Environment(\.modelContext) private var modelContext

    @State private var vm             = SearchViewModel()
    @State private var showStorePicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Store selection banner
                storeSelectionBanner

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Cartly.textSecondary)
                    TextField("Search products…", text: $vm.query)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await vm.searchProducts() }
                        }
                    if !vm.query.isEmpty {
                        Button {
                            vm.query    = ""
                            vm.products = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Cartly.textSecondary)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
                .padding(.horizontal, Theme.Spacing.md)

                // Results
                if vm.isLoadingProducts {
                    ProgressView("Searching…")
                        .padding(.top, Theme.Spacing.xl)
                } else if vm.products.isEmpty && !vm.query.isEmpty {
                    Text("No results for \"\(vm.query)\"")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Cartly.textSecondary)
                        .padding(.top, Theme.Spacing.xl)
                } else {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(vm.products) { product in
                            ProductCard(
                                product: product,
                                inCart: cartItems.contains { $0.krogerProductId == product.id }
                            ) {
                                cartVM.addProduct(product, context: modelContext, existing: cartItems)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Theme.Cartly.warning)
                        .padding(.horizontal, Theme.Spacing.md)
                }

                Spacer(minLength: Theme.Spacing.xxl)
            }
        }
        .navigationTitle("Search")
        .sheet(isPresented: $showStorePicker) {
            StorePickerSheet(vm: vm)
        }
    }

    // MARK: - Store banner

    private var storeSelectionBanner: some View {
        Button {
            showStorePicker = true
        } label: {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Theme.Cartly.primaryAccent)
                if let store = vm.selectedStore {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Cartly.textPrimary)
                        Text(store.displayAddress)
                            .font(.caption)
                            .foregroundStyle(Theme.Cartly.textSecondary)
                    }
                } else {
                    Text("Select a store")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Cartly.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Cartly.textSecondary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Cartly.cardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.md)
    }
}

// MARK: - ProductCard

struct ProductCard: View {
    let product: KrogerProduct
    let inCart:  Bool
    let onAdd:   () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Product image placeholder
            // TODO: Replace with AsyncImage once URLs are available
            RoundedRectangle(cornerRadius: Theme.CornerRadius.button)
                .fill(Color(.systemGray5))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(Color(.systemGray3))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Cartly.textPrimary)
                    .lineLimit(2)
                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(Theme.Cartly.textSecondary)
                }
                if product.hasMacros {
                    HStack(spacing: Theme.Spacing.sm) {
                        if let cal = product.calories {
                            MacroBadge(label: "\(cal)", unit: "kcal")
                        }
                        if let p = product.proteinG {
                            MacroBadge(label: Format.decimal(p, places: 1), unit: "P")
                        }
                        if let c = product.carbsG {
                            MacroBadge(label: Format.decimal(c, places: 1), unit: "C")
                        }
                        if let f = product.fatG {
                            MacroBadge(label: Format.decimal(f, places: 1), unit: "F")
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 6) {
                if !product.displayPrice.isEmpty {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Cartly.textPrimary)
                }
                Button(action: onAdd) {
                    Image(systemName: inCart ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inCart ? Theme.Cartly.success : Theme.Cartly.primaryAccent)
                }
                .buttonStyle(.plain)
                .disabled(false)  // can add multiple quantities
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Cartly.cardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - MacroBadge

private struct MacroBadge: View {
    let label: String
    let unit:  String

    var body: some View {
        Text("\(label)\(unit)")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.Cartly.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(.systemGray5), in: Capsule())
    }
}

// MARK: - StorePickerSheet

private struct StorePickerSheet: View {
    @Bindable var vm: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    TextField("Enter ZIP code", text: $vm.zip)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    Button("Find") {
                        Task { await vm.fetchStores() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Cartly.primaryAccent)
                    .disabled(vm.zip.count < 5)
                }
                .padding(.horizontal, Theme.Spacing.md)

                if vm.isLoadingStores {
                    ProgressView("Finding stores…")
                }

                List(vm.stores) { store in
                    Button {
                        vm.selectedStore = store
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.name)
                                .font(.headline)
                                .foregroundStyle(Theme.Cartly.textPrimary)
                            Text(store.displayAddress)
                                .font(.subheadline)
                                .foregroundStyle(Theme.Cartly.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        vm.selectedStore?.id == store.id
                            ? Theme.Cartly.primaryAccent.opacity(0.08)
                            : Color.clear
                    )
                }
            }
            .padding(.top, Theme.Spacing.md)
            .navigationTitle("Select Store")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
