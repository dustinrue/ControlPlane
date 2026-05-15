import Foundation
import FoundationModels

// MARK: - Output schema

/// Structured output schema.
/// Plain Codable structs — avoids @Generable macros so this can build with CLI tools.
/// The system prompt describes the exact JSON shape; we decode the model's string response.
struct ParsedConfig: Decodable {
    var profileName: String
    var confidenceThreshold: Double
    var explanation: String
    var assumptions: [String]
    var rules: [ParsedRule]
    var actions: [ParsedAction]
}

struct ParsedRule: Decodable {
    var name: String
    var sensorID: String
    var readingKey: String
    var operatorID: String
    var comparandValue: String
    var weight: Double
    var negate: Bool
}

struct ParsedAction: Decodable {
    var actionID: String
    var trigger: String
    var configEntries: [ConfigEntry]
}

struct ConfigEntry: Decodable {
    var key: String
    var value: String
}

// MARK: - Parser

@MainActor
class NLParser: ObservableObject {
    @Published var result: ParsedConfig?
    @Published var isLoading = false
    @Published var error: String?
    @Published var rawResponse: String?      // exact text from the model
    @Published var decodedAttempt: String?   // text we actually fed to the JSON decoder
    @Published var modelAvailable: Bool = false

    init() {
        checkAvailability()
    }

    private func checkAvailability() {
        if #available(macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                modelAvailable = true
            case .unavailable(let reason):
                error = unavailabilityReason(reason)
                modelAvailable = false
            }
        } else {
            error = "Foundation Models requires macOS 26 or later."
            modelAvailable = false
        }
    }

    func parse(input: String) async {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isLoading = true
        result = nil
        error = nil
        rawResponse = nil
        decodedAttempt = nil

        if #available(macOS 26, *) {
            do {
                let session = LanguageModelSession(
                    instructions: ControlPlaneVocabulary.systemPrompt
                )
                // Use unstructured string response — @Generable macros require Xcode toolchain.
                // The system prompt dictates the JSON shape; we decode it ourselves.
                let response = try await session.respond(to: input)
                let text = response.content
                rawResponse = text        // always capture before attempting decode
                result = try decodeConfig(from: text)
            } catch let decodeError as DecodingError {
                self.error = "JSON parse error: \(decodeError.localizedDescription)"
            } catch {
                self.error = "Model error: \(error.localizedDescription)"
            }
        } else {
            error = "Foundation Models requires macOS 26 or later."
        }

        isLoading = false
    }

    // MARK: - JSON extraction

    /// Extracts JSON from the model response and decodes it.
    /// Records the cleaned text in `decodedAttempt` so failures can be debugged.
    private func decodeConfig(from text: String) throws -> ParsedConfig {
        let cleaned = extractJSON(from: text)
        decodedAttempt = cleaned
        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "NLConfig", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not encode model response as UTF-8"])
        }
        return try JSONDecoder().decode(ParsedConfig.self, from: data)
    }

    /// Three-stage extraction: code fences → brace scan → raw fallback.
    private func extractJSON(from text: String) -> String {
        // Stage 1: strip markdown code fences (```json ... ``` or ``` ... ```)
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fenceStart = s.range(of: "```") {
            if let fenceEnd = s.range(of: "```", options: .backwards),
               fenceEnd.lowerBound != fenceStart.lowerBound {
                let inner = s[fenceStart.upperBound..<fenceEnd.lowerBound]
                if let newline = inner.firstIndex(of: "\n") {
                    s = String(inner[inner.index(after: newline)...])
                } else {
                    s = String(inner)
                }
                s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Stage 2: if the result doesn't start with { find the outermost braces.
        // This handles any residual preamble or suffix the model added.
        if !s.hasPrefix("{") {
            if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
                s = String(s[start...end])
            }
        }

        return s
    }

    @available(macOS 26, *)
    private func unavailabilityReason(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence. An Apple Silicon Mac with Apple Intelligence enabled is required."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Enable it in System Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            return "The on-device model is downloading or not yet ready. Try again in a few minutes."
        @unknown default:
            return "Apple Intelligence is not available on this device."
        }
    }
}
