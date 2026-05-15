import Foundation
import FoundationModels

// MARK: - Output schema

/// Structured output schema for the model.
/// @Generable tells Foundation Models to produce valid JSON matching this shape.
@Generable
struct ParsedConfig {
    @Guide(description: "Short descriptive profile name")
    var profileName: String

    @Guide(description: "Confidence threshold 0.1–1.0; use 1.0 for single-rule profiles")
    var confidenceThreshold: Double

    @Guide(description: "Plain English explanation of what this configuration does")
    var explanation: String

    @Guide(description: "Assumptions made about ambiguous parts of the request")
    var assumptions: [String]

    var rules: [ParsedRule]
    var actions: [ParsedAction]
}

@Generable
struct ParsedRule {
    @Guide(description: "Human-readable label for this rule")
    var name: String

    @Guide(description: "Sensor identifier, e.g. com.controlplane.sensors.wifi")
    var sensorID: String

    @Guide(description: "Reading key within the sensor snapshot, e.g. ssid")
    var readingKey: String

    @Guide(description: "Operator identifier, e.g. equals, greaterThan, isTrue")
    var operatorID: String

    @Guide(description: "Comparand value as a string; booleans as 'true'/'false'")
    var comparandValue: String

    @Guide(description: "Confidence weight 0.1–1.0; use 1.0 for a single definitive rule")
    var weight: Double

    @Guide(description: "True to invert the match — rule fires when condition is ABSENT")
    var negate: Bool
}

@Generable
struct ParsedAction {
    @Guide(description: "Action plugin identifier, e.g. com.controlplane.action.open")
    var actionID: String

    @Guide(description: "onActivate or onDeactivate")
    var trigger: String

    var configEntries: [ConfigEntry]
}

@Generable
struct ConfigEntry {
    var key: String
    var value: String
}

// MARK: - Parser

@MainActor
class NLParser: ObservableObject {
    @Published var result: ParsedConfig?
    @Published var isLoading = false
    @Published var error: String?
    @Published var modelAvailable: Bool = false

    init() {
        checkAvailability()
    }

    private func checkAvailability() {
        if #available(macOS 15.4, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                modelAvailable = true
            case .unavailable(let reason):
                error = unavailabilityReason(reason)
                modelAvailable = false
            }
        } else {
            error = "Foundation Models requires macOS 15.4 or later."
            modelAvailable = false
        }
    }

    func parse(input: String) async {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isLoading = true
        result = nil
        error = nil

        if #available(macOS 15.4, *) {
            do {
                let session = LanguageModelSession(
                    instructions: ControlPlaneVocabulary.systemPrompt
                )
                let response = try await session.respond(
                    to: input,
                    generating: ParsedConfig.self
                )
                result = response.content
            } catch {
                self.error = "Model error: \(error.localizedDescription)"
            }
        } else {
            error = "Foundation Models requires macOS 15.4 or later."
        }

        isLoading = false
    }

    @available(macOS 15.4, *)
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
