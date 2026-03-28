import SwiftUI
import SwiftData

@main
struct MegaAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { seedPantryIfNeeded() }
        }
        // Register all SwiftData models in one shared ModelContainer.
        // TreadmillSegment is included explicitly so its cascade-delete relationship
        // is resolved at container creation, not lazily.
        .modelContainer(for: [
            WorkoutSession.self,
            TreadmillSegment.self,
            PantryItem.self,
            CartItem.self
        ])
    }
}

// MARK: - First-launch pantry seed
//
// Mirrors the INITIAL_PANTRY constant from the Cartly web app (App.jsx).
// Runs once on first launch; UserDefaults flag prevents re-seeding.

private func seedPantryIfNeeded() {
    guard !UserDefaults.standard.bool(forKey: "pantry_seeded_v1") else { return }

    let container = try? ModelContainer(for: PantryItem.self)
    guard let ctx = container.map({ ModelContext($0) }) else { return }

    let seed: [(name: String, amount: Double?, unit: String?, status: String, category: String)] = [
        // Pantry Staples
        ("Barilla Penne Pasta",  0.5,  "box",       "ok",  "Pantry Staples"),
        ("Rao's Marinara Sauce", 0.25, "jar",        "low", "Pantry Staples"),
        ("Olive Oil",            0.25, "bottle",     "low", "Pantry Staples"),
        ("Garlic Powder",        nil,  nil,           "ok",  "Pantry Staples"),
        ("Onion Powder",         nil,  nil,           "ok",  "Pantry Staples"),
        ("Smoked Paprika",       nil,  nil,           "low", "Pantry Staples"),
        ("Red Pepper Flakes",    nil,  nil,           "ok",  "Pantry Staples"),
        ("Kosher Salt",          nil,  nil,           "ok",  "Pantry Staples"),
        ("Black Pepper",         nil,  nil,           "low", "Pantry Staples"),
        ("Chicken Broth",        1,    "carton",      "ok",  "Pantry Staples"),
        ("Canned Chickpeas",     2,    "cans",        "ok",  "Pantry Staples"),
        ("Jasmine Rice",         nil,  nil,           "low", "Pantry Staples"),
        // Produce
        ("Baby Spinach",         nil,  nil,           "low", "Produce"),
        ("Cherry Tomatoes",      nil,  nil,           "low", "Produce"),
        ("Yellow Onion",         1,    nil,           "low", "Produce"),
        ("Russet Potatoes",      3,    nil,           "ok",  "Produce"),
        // Dairy & Eggs
        ("Eggs",                 4,    nil,           "low", "Dairy & Eggs"),
        ("Parmesan Cheese",      nil,  nil,           "low", "Dairy & Eggs"),
        ("Greek Yogurt",         1,    "container",   "low", "Dairy & Eggs"),
        // Frozen
        ("Frozen Broccoli",      0.5,  "bag",         "ok",  "Frozen"),
    ]

    for item in seed {
        ctx.insert(PantryItem(
            name:     item.name,
            amount:   item.amount,
            unit:     item.unit,
            status:   item.status,
            category: item.category
        ))
    }
    try? ctx.save()
    UserDefaults.standard.set(true, forKey: "pantry_seeded_v1")
}
