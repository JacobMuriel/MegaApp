import SwiftUI
import SwiftData

@main
struct MegaAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
