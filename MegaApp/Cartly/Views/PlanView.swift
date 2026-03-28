import SwiftUI
import SwiftData

// MARK: - PlanView
//
// AI-generated 3-tier meal ideas from current pantry contents.
// Tapping a card opens a bottom-sheet with full ingredients + instructions.

struct PlanView: View {
    @Query private var pantryItems: [PantryItem]

    @State private var vm           = PlanViewModel()
    @State private var selectedMeal: MealIdea? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Generate button
                Button {
                    vm.generate(pantryItems: pantryItems)
                } label: {
                    Label(
                        vm.isLoading ? "Generating…" : "Generate Meal Ideas",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Cartly.primaryAccent)
                .disabled(vm.isLoading || pantryItems.isEmpty)
                .padding(.horizontal, Theme.Spacing.md)

                if pantryItems.isEmpty {
                    Text("Add items to your pantry first.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Cartly.textSecondary)
                        .padding(.top, Theme.Spacing.lg)
                }

                if vm.isLoading {
                    ProgressView()
                        .padding(.top, Theme.Spacing.xl)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Theme.Cartly.danger)
                        .padding(.horizontal, Theme.Spacing.md)
                }

                // Tiers
                if !vm.mealIdeas.isEmpty {
                    ForEach(MealTier.allCases) { tier in
                        let meals: [MealIdea] = vm.mealIdeas.filter { $0.tier == tier.rawValue }
                        if !meals.isEmpty {
                            MealTierSection(tier: tier, meals: meals) { meal in
                                selectedMeal = meal
                            }
                        }
                    }
                }

                Spacer(minLength: Theme.Spacing.xxl)
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .navigationTitle("Meal Plan")
        .sheet(item: $selectedMeal) { meal in
            MealDetailSheet(meal: meal)
        }
    }
}

// MARK: - MealTierSection

private struct MealTierSection: View {
    let tier:     MealTier
    let meals:    [MealIdea]
    let onSelect: (MealIdea) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Tier header
            HStack(spacing: 6) {
                Circle()
                    .fill(tier.color)
                    .frame(width: 8, height: 8)
                Text(tier.displayName)
                    .font(.headline)
                    .foregroundStyle(Theme.Cartly.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.md)

            // Horizontal scroll of cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(meals) { meal in
                        MealCard(meal: meal) { onSelect(meal) }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
}

// MARK: - MealCard

private struct MealCard: View {
    let meal:     MealIdea
    let onTap:    () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(meal.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Cartly.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Macro row
                HStack(spacing: Theme.Spacing.sm) {
                    MealMacro(label: "Cal",  value: "\(meal.calories)")
                    MealMacro(label: "P",    value: Format.decimal(meal.proteinG, places: 0) + "g")
                    MealMacro(label: "C",    value: Format.decimal(meal.carbsG, places: 0)   + "g")
                    MealMacro(label: "F",    value: Format.decimal(meal.fatG, places: 0)     + "g")
                }

                Text("Tap for recipe →")
                    .font(.caption)
                    .foregroundStyle(Theme.Cartly.primaryAccent)
            }
            .padding(Theme.Spacing.md)
            .frame(width: 200)
            .background(Theme.Cartly.cardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct MealMacro: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.Cartly.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.Cartly.textSecondary)
        }
    }
}

// MARK: - MealDetailSheet

struct MealDetailSheet: View {
    let meal: MealIdea
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Macro grid
                    HStack(spacing: Theme.Spacing.sm) {
                        MetricTile(label: "Calories",  value: "\(meal.calories)")
                        MetricTile(label: "Protein",   value: Format.decimal(meal.proteinG, places: 1) + "g")
                        MetricTile(label: "Carbs",     value: Format.decimal(meal.carbsG, places: 1)   + "g")
                        MetricTile(label: "Fat",       value: Format.decimal(meal.fatG, places: 1)     + "g")
                    }

                    // Tier badge
                    HStack {
                        Circle().fill(meal.tierEnum.color).frame(width: 8, height: 8)
                        Text(meal.tierEnum.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(meal.tierEnum.color)
                    }

                    // Ingredients
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Ingredients")
                            .font(.headline)
                        ForEach(meal.ingredients, id: \.self) { ing in
                            Label(ing, systemImage: "circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Cartly.textPrimary)
                                .labelStyle(IngredientLabelStyle())
                        }
                    }

                    // Instructions
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Instructions")
                            .font(.headline)
                        Text(meal.instructions)
                            .font(.body)
                            .foregroundStyle(Theme.Cartly.textPrimary)
                    }

                    Spacer(minLength: Theme.Spacing.xxl)
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct MetricTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.Cartly.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Cartly.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.sm)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: Theme.CornerRadius.button))
    }
}

private struct IngredientLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(Theme.Cartly.primaryAccent)
            configuration.title
        }
    }
}
