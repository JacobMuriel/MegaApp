import SwiftUI

// MARK: - CartlyShell
//
// Bottom-tab container for the Cartly mini-app.
// CartViewModel is owned here so all tabs can reference the same cart state.

struct CartlyShell: View {
    @State private var cartVM = CartViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                PantryView()
            }
            .tabItem { Label("Pantry", systemImage: "cabinet") }

            NavigationStack {
                SearchView(cartVM: cartVM)
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                PlanView()
            }
            .tabItem { Label("Plan", systemImage: "fork.knife") }

            NavigationStack {
                CartView(cartVM: cartVM)
            }
            .tabItem { Label("Cart", systemImage: "cart") }

            NavigationStack {
                AislesView(cartVM: cartVM)
            }
            .tabItem { Label("Aisles", systemImage: "map") }
        }
        .tint(Theme.Cartly.primaryAccent)
    }
}

#Preview {
    CartlyShell()
        .modelContainer(for: [PantryItem.self, CartItem.self], inMemory: true)
}
