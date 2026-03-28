import SwiftUI

// MARK: - App switcher state

enum ActiveApp: String, CaseIterable {
    case fitness = "Fitness"
    case cartly  = "Cartly"
}

// MARK: - Root content view

/// Top-level shell: persistent TopNavBar + conditional mini-app shell.
/// Switching between shells is an instant conditional render — no push/transition animation.
struct ContentView: View {
    @State private var activeApp: ActiveApp = .fitness

    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(activeApp: $activeApp)
            Divider()
            // No animation on switch — mirrors the RN version's animation='none'
            Group {
                switch activeApp {
                case .fitness: FitnessShell()
                case .cartly:  CartlyShell()
                }
            }
            .animation(nil, value: activeApp)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Top navigation bar

struct TopNavBar: View {
    @Binding var activeApp: ActiveApp

    private var accentColor: Color {
        activeApp == .fitness ? Theme.Fitness.primaryAccent : Theme.Cartly.primaryAccent
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Logo mark + app name
            HStack(spacing: 6) {
                Image(systemName: activeApp == .fitness ? "bolt.fill" : "cart.fill")
                    .foregroundStyle(accentColor)
                    .animation(.easeInOut(duration: 0.2), value: activeApp)
                Text("MegaApp")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Spacer()

            // Segmented switcher — pill style
            HStack(spacing: 2) {
                ForEach(ActiveApp.allCases, id: \.self) { app in
                    Button {
                        activeApp = app
                    } label: {
                        Text(app.rawValue)
                            .font(.subheadline)
                            .fontWeight(activeApp == app ? .semibold : .regular)
                            .foregroundStyle(activeApp == app ? .white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                activeApp == app
                                    ? (app == .fitness ? Theme.Fitness.primaryAccent : Theme.Cartly.primaryAccent)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: Theme.CornerRadius.button)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.regularMaterial)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, TreadmillSegment.self, PantryItem.self, CartItem.self], inMemory: true)
}
