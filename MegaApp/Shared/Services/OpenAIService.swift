import Foundation
import SwiftUI

// MARK: - OpenAIService
//
// Single actor for all OpenAI calls — Whisper transcription, pantry intent parsing,
// meal plan generation, and insights. `actor` ensures no concurrent mutations to
// shared state (URLSession is already thread-safe; the actor isolation is mostly
// a signal that callers must `await`).
//
// API key is read from Info.plist (injected at build time via MegaApp.xcconfig).

actor OpenAIService {

    static let shared = OpenAIService()

    private let apiKey: String
    private let session: URLSession

    private init() {
        self.apiKey  = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String ?? ""
        self.session = URLSession.shared
    }

    // MARK: - Whisper transcription

    /// Transcribe audio data to text using the Whisper API.
    /// - Parameter audioData: Raw audio bytes (m4a or wav).
    func transcribe(audioData: Data, fileName: String = "recording.m4a", mimeType: String = "audio/m4a") async throws -> String {
        let url       = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request   = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // model field
        body.appendFormField(name: "model", value: "whisper-1", boundary: boundary)
        // file field
        body.appendFormFile(name: "file", fileName: fileName, mimeType: mimeType, data: audioData, boundary: boundary)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, _) = try await session.data(for: request)
        struct Resp: Decodable { let text: String }
        return try JSONDecoder().decode(Resp.self, from: data).text
    }

    // MARK: - Chat completions

    /// Generic chat completion. Returns the first choice's content string.
    func chat(
        model:        String = "gpt-4o-mini",
        system:       String,
        user:         String,
        temperature:  Double = 0.7
    ) async throws -> String {
        let url     = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": user  ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
        struct Resp:   Decodable { let choices: [Choice] }
        guard let content = try JSONDecoder().decode(Resp.self, from: data).choices.first?.message.content else {
            throw OpenAIError.emptyResponse
        }
        return content
    }

    // MARK: - Pantry intent parser
    //
    // Temp 0.1 for deterministic parsing. Returns [PantryChangeIntent].
    // GPT JSON fences are stripped before parsing.

    func parsePantryIntent(transcript: String, currentPantry: [String]) async throws -> [PantryChangeIntent] {
        let system = """
        You are a pantry manager assistant. The user will describe changes to their pantry verbally.
        Return a JSON array (no markdown fences) of objects with these keys:
          itemName: string
          action:   "add" | "update" | "remove"
          newAmount: number | null
          unit: string | null
        Current pantry items for context: \(currentPantry.joined(separator: ", "))
        """
        let raw    = try await chat(system: system, user: transcript, temperature: 0.1)
        let clean  = Self.stripFences(raw)
        let data   = clean.data(using: .utf8) ?? Data()
        return try JSONDecoder().decode([PantryChangeIntent].self, from: data)
    }

    // MARK: - Meal plan generation

    /// Returns 10–12 meal ideas in 3 tiers, ranked by protein content.
    func generateMealIdeas(pantryItems: [String]) async throws -> [MealIdea] {
        let system = """
        You are a nutrition and meal planning assistant. Given a list of pantry items, generate 10-12 high-protein meal ideas.
        Return a JSON array (no markdown fences) of meal objects. Each object must have:
          id: string (UUID)
          name: string
          tier: "pantryOnly" | "pantryPlus" | "needsIngredients"
          calories: number
          proteinG: number
          carbsG: number
          fatG: number
          ingredients: [string]
          instructions: string
        Tier definitions:
          pantryOnly        — uses only items from the list
          pantryPlus        — mostly pantry items + 1-2 common additions
          needsIngredients  — requires a shopping trip
        Rank within each tier by protein content, highest first.
        """
        let user   = "Pantry: \(pantryItems.joined(separator: ", "))"
        let raw    = try await chat(system: system, user: user, temperature: 0.7)
        let clean  = Self.stripFences(raw)
        let data   = clean.data(using: .utf8) ?? Data()
        return try JSONDecoder().decode([MealIdea].self, from: data)
    }

    // MARK: - JSON fence stripping
    //
    // GPT wraps JSON in ```json … ``` even when instructed not to.
    // This strips those fences before JSON.parse / JSONDecoder.
    // Do NOT remove this — it is a documented hard rule in CLAUDE.md.

    static func stripFences(_ text: String) -> String {
        var lines   = text.components(separatedBy: "\n")
        var inFence = false
        var result: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if !inFence { result.append(line) }
        }
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting types

struct PantryChangeIntent: Codable, Identifiable {
    let id        = UUID()
    let itemName:  String
    let action:    String   // "add" | "update" | "remove"
    let newAmount: Double?
    let unit:      String?

    private enum CodingKeys: String, CodingKey {
        case itemName, action, newAmount, unit
    }
}

struct MealIdea: Codable, Identifiable {
    var id:           String
    let name:         String
    let tier:         String   // "pantryOnly" | "pantryPlus" | "needsIngredients"
    let calories:     Int
    let proteinG:     Double
    let carbsG:       Double
    let fatG:         Double
    let ingredients:  [String]
    let instructions: String

    var tierEnum: MealTier { MealTier(rawValue: tier) ?? .needsIngredients }
}

enum MealTier: String, CaseIterable, Identifiable {
    case pantryOnly        = "pantryOnly"
    case pantryPlus        = "pantryPlus"
    case needsIngredients  = "needsIngredients"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pantryOnly:       return "Pantry Only"
        case .pantryPlus:       return "Pantry + Optional"
        case .needsIngredients: return "Needs Ingredients"
        }
    }

    var color: Color {
        switch self {
        case .pantryOnly:       return Theme.Cartly.success
        case .pantryPlus:       return Theme.Cartly.warning
        case .needsIngredients: return Theme.Cartly.danger
        }
    }
}

enum OpenAIError: Error {
    case emptyResponse
    case missingAPIKey
}

// MARK: - Multipart helpers

private extension Data {
    mutating func appendFormField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendFormFile(name: String, fileName: String, mimeType: String, data fileData: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(fileData)
        append("\r\n".data(using: .utf8)!)
    }
}

