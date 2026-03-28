import Foundation
import Observation

// MARK: - PlanViewModel
//
// Generates 3-tier meal ideas from the current pantry via GPT-4o-mini.
// Results are grouped into tiers and cached in-memory until explicitly regenerated.

@Observable
@MainActor
final class PlanViewModel {

    var mealIdeas:    [MealIdea] = []
    var isLoading     = false
    var errorMessage: String? = nil

    // Grouped by tier for display
    var pantryOnlyMeals:       [MealIdea] { mealIdeas.filter { $0.tier == MealTier.pantryOnly.rawValue       } }
    var pantryPlusMeals:       [MealIdea] { mealIdeas.filter { $0.tier == MealTier.pantryPlus.rawValue       } }
    var needsIngredientsMeals: [MealIdea] { mealIdeas.filter { $0.tier == MealTier.needsIngredients.rawValue } }

    func generate(pantryItems: [PantryItem]) {
        guard !isLoading else { return }
        isLoading    = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let simple = pantryItems.map { "\($0.name)\($0.statusEnum == .out ? " (out)" : "")" }
                mealIdeas  = try await OpenAIService.shared.generateMealIdeas(pantryItems: simple)
            } catch {
                errorMessage = "Couldn't generate meal ideas: \(error.localizedDescription)"
            }
        }
    }
}
