import Foundation
import SwiftData
import SwiftUI

// MARK: - InsightsEngine
//
// Cross-app recommendations layer. Reads from both WorkoutSession and PantryItem
// stores and calls GPT-4o-mini to produce typed Insight objects.
//
// Design goal: as session and pantry history accumulates, recommendations become
// more personalised. We pass a rolling 30-day context window to the system prompt
// so the model can spot longitudinal patterns (e.g. always sluggish on Mondays,
// protein deficit correlating with perceived-effort drops).
//
// Call sites:
//   • ContentView.onAppear
//   • After any WorkoutSession save
//   • After any PantryItem save
// These are all @MainActor contexts, so `@MainActor` on the class is appropriate.

@MainActor
final class InsightsEngine: ObservableObject {

    @Published var insights: [Insight] = []
    @Published var isLoading = false

    private let openAI = OpenAIService.shared

    // MARK: - Generate insights

    /// Fetches the latest insights.  `sessions` and `pantryItems` are passed in
    /// rather than fetched here so the caller (which holds a ModelContext) controls
    /// the query.
    func generate(sessions: [WorkoutSession], pantryItems: [PantryItem]) {
        guard !isLoading else { return }
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                // Rule-based insights run synchronously (cheap, no API call)
                var result = ruleBasedInsights(sessions: sessions, pantryItems: pantryItems)

                // AI-generated insights use a 30-day rolling context window
                let aiInsights = try await aiGeneratedInsights(sessions: sessions, pantryItems: pantryItems)
                result.append(contentsOf: aiInsights)

                insights = result
            } catch {
                // Don't surface AI errors to the user — fall back to rule-based only
                insights = ruleBasedInsights(sessions: sessions, pantryItems: pantryItems)
            }
        }
    }

    // MARK: - Rule-based (deterministic, no API call)

    private func ruleBasedInsights(sessions: [WorkoutSession], pantryItems: [PantryItem]) -> [Insight] {
        var result: [Insight] = []
        let cal     = Calendar.current
        let today   = cal.startOfDay(for: Date())

        // Calorie balance: compare calories burned (last 7 days) vs pantry calories
        let recentSessions = sessions.filter { cal.dateComponents([.day], from: $0.date, to: today).day ?? 99 <= 7 }
        let caloriesBurned = recentSessions.compactMap(\.calories).reduce(0, +)
        if caloriesBurned > 2000 {
            result.append(Insight(
                type:    .calorieBalance,
                title:   "High Output Week",
                body:    "You burned \(caloriesBurned) kcal over the last 7 days. Make sure you're fuelling adequately.",
                urgency: .medium
            ))
        }

        // Post-workout recovery: last session was an outdoor run or bike today
        if let last = sessions.sorted(by: { $0.date > $1.date }).first,
           cal.isDateInToday(last.date),
           last.activityType == ActivityType.outdoorRun.rawValue || last.activityType == ActivityType.bike.rawValue {
            result.append(Insight(
                type:    .postWorkoutRecovery,
                title:   "Recovery Opportunity",
                body:    "You just finished a \(last.activityTypeEnum.displayName.lowercased()). A high-protein snack within 30 minutes helps muscle recovery.",
                urgency: .low
            ))
        }

        // Low pantry items
        let outItems = pantryItems.filter { $0.status == PantryStatus.out.rawValue }
        if !outItems.isEmpty {
            let names = outItems.prefix(3).map(\.name).joined(separator: ", ")
            result.append(Insight(
                type:    .groceryGap,
                title:   "Pantry Gap",
                body:    "\(names)\(outItems.count > 3 ? " and \(outItems.count - 3) more" : "") are out. Add them to your cart.",
                urgency: .medium
            ))
        }

        return result
    }

    // MARK: - AI-generated (rolling 30-day context window)

    private func aiGeneratedInsights(sessions: [WorkoutSession], pantryItems: [PantryItem]) async throws -> [Insight] {
        let cutoff   = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent   = sessions.filter { $0.date >= cutoff }

        // Build a concise context string — keep token count manageable
        let sessionSummary = recent.prefix(50).map { s in
            "\(Format.dateShort(s.date)) \(s.activityTypeEnum.displayName) \(Format.duration(s.durationSeconds))" +
            (s.distanceMiles.map { " \(Format.decimal($0, places: 2))mi" } ?? "") +
            (s.calories.map { " \($0)kcal" } ?? "")
        }.joined(separator: "\n")

        let pantryContext = pantryItems.map { "\($0.name) (\($0.statusEnum.label))" }.joined(separator: ", ")

        let system = """
        You are a personal fitness and nutrition coach. Based on the user's recent workout history and current pantry,
        generate 1-3 personalised, actionable insights.
        Return a JSON array (no markdown fences) of objects:
          type:    "preWorkout" | "postWorkoutRecovery" | "calorieBalance" | "groceryGap" | "trend"
          title:   string (short, ≤ 40 chars)
          body:    string (1-2 sentences, specific and actionable)
          urgency: "low" | "medium" | "high"
        Be specific — reference actual numbers from the data when possible.
        """
        let user = "Last 30 days sessions:\n\(sessionSummary)\n\nPantry: \(pantryContext)"

        let raw   = try await openAI.chat(system: system, user: user, temperature: 0.4)
        let clean = OpenAIService.stripFences(raw)
        let data  = clean.data(using: .utf8) ?? Data()

        struct RawInsight: Decodable {
            let type: String; let title: String; let body: String; let urgency: String
        }
        let decoded = try JSONDecoder().decode([RawInsight].self, from: data)
        return decoded.map { r in
            Insight(
                type:    InsightType(rawValue: r.type) ?? .trend,
                title:   r.title,
                body:    r.body,
                urgency: InsightUrgency(rawValue: r.urgency) ?? .low
            )
        }
    }
}

// MARK: - Insight model

struct Insight: Identifiable {
    let id      = UUID()
    let type:    InsightType
    let title:   String
    let body:    String
    let urgency: InsightUrgency
}

enum InsightType: String {
    case calorieBalance    = "calorieBalance"
    case preWorkout        = "preWorkout"
    case postWorkoutRecovery = "postWorkoutRecovery"
    case groceryGap        = "groceryGap"
    case trend             = "trend"
}

enum InsightUrgency: String {
    case low, medium, high

    var color: Color {
        switch self {
        case .low:    return Theme.Fitness.textSecondary
        case .medium: return Theme.Fitness.warning
        case .high:   return Theme.Fitness.danger
        }
    }
}

