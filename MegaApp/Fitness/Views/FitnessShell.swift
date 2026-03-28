import SwiftUI

// MARK: - FitnessShell
//
// Bottom-tab container for the Fitness mini-app.
// Owns the shared RunRecoveryManager so History + OutdoorRun
// can both reference the same undo state.

struct FitnessShell: View {
    @StateObject private var recovery = RunRecoveryManager()

    var body: some View {
        TabView {
            NavigationStack {
                HistoryView(recovery: recovery)
            }
            .tabItem { Label("History", systemImage: "list.bullet") }

            NavigationStack {
                StatsView()
            }
            .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .tint(Theme.Fitness.primaryAccent)
    }
}

#Preview {
    FitnessShell()
        .modelContainer(for: [WorkoutSession.self, TreadmillSegment.self], inMemory: true)
}
