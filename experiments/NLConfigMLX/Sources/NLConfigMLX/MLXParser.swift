import Foundation
import HuggingFace     // HubClient, Repo.ID
import MLX
import MLXLLM
import MLXHuggingFace  // HuggingFaceDownloaderError (from mlx-swift-lm)
import MLXLMCommon
import Tokenizers      // AutoTokenizer

// MARK: - Model state

enum ModelState: Equatable {
    case downloading(fraction: Double, detail: String)
    case loading
    case ready
    case failed(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

// MARK: - Output schema (plain Codable — no @Generable macros needed)

struct ParsedConfig: Decodable {
    var profileName: String
    var confidenceThreshold: Double
    var createProfile: Bool
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

// MARK: - Known action vocabulary

private let knownActionIDs: Set<String> = [
    "com.controlplane.action.open",
    "com.controlplane.action.openurl",
    "com.controlplane.action.openandhide",
    "com.controlplane.action.quitapplication",
    "com.controlplane.action.shellscript",
    "com.controlplane.action.shortcut",
    "com.controlplane.action.speak",
    "com.controlplane.action.mountvolume",
    "com.controlplane.action.unmountvolume",
    "com.controlplane.action.desktopbackground",
    "com.controlplane.action.togglewifi",
    "com.controlplane.action.starttimemachine",
    "com.controlplane.action.preventdisplaysleep",
    "com.controlplane.action.preventsystemsleep",
    "com.controlplane.action.startscreensaver",
    "com.controlplane.action.lockkeychain",
    "com.controlplane.action.networklocation",
    "com.controlplane.action.defaultprinter",
]

// MARK: - HuggingFace bridge types
//
// These mirror what the MLXHuggingFace macros (#hubDownloader, #huggingFaceTokenizerLoader)
// expand to, written out manually to avoid needing the MLXHuggingFaceMacros compiler plugin.

private struct HubBridge: Downloader {
    private let upstream: HuggingFace.HubClient

    init(_ upstream: HuggingFace.HubClient = HuggingFace.HubClient()) {
        self.upstream = upstream
    }

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Foundation.Progress) -> Void
    ) async throws -> URL {
        guard let repoID = HuggingFace.Repo.ID(rawValue: id) else {
            throw HuggingFaceDownloaderError.invalidRepositoryID(id)
        }
        let rev = revision ?? "main"
        return try await upstream.downloadSnapshot(
            of: repoID,
            revision: rev,
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }
}

private struct TransformersLoader: TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return TokenizerBridge(upstream)
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

// MARK: - Parser

// Model to use. Qwen3-4B-4bit is confirmed in LLMTypeRegistry.
// Try "mlx-community/Qwen3.5-4B-4bit" if you want to test the newer variant.
private let modelID = "mlx-community/Qwen3-4B-4bit"

@MainActor
class MLXParser: ObservableObject {
    @Published var modelState: ModelState = .downloading(fraction: 0, detail: "Starting…")
    @Published var result: ParsedConfig?
    @Published var isLoading = false
    @Published var error: String?
    @Published var rawResponse: String?
    @Published var decodedAttempt: String?

    private var container: ModelContainer?

    init() {
        Task { await loadModel() }
    }

    // MARK: - Model loading

    private func loadModel() async {
        // Keep GPU memory cache small so model weights fit comfortably.
        Memory.cacheLimit = 20 * 1024 * 1024

        let config = ModelConfiguration(id: modelID)

        do {
            let loadedContainer = try await LLMModelFactory.shared.loadContainer(
                from: HubBridge(),
                using: TransformersLoader(),
                configuration: config,
                progressHandler: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        let detail = Self.formatProgress(progress)
                        self?.modelState = .downloading(fraction: progress.fractionCompleted, detail: detail)
                    }
                }
            )

            modelState = .loading

            // Brief yield so the UI updates to "Loading…" before the model
            // is pulled into memory (which can take a second or two).
            try await Task.sleep(for: .milliseconds(100))

            container = loadedContainer
            modelState = .ready

        } catch {
            modelState = .failed("Failed to load model: \(error.localizedDescription)")
        }
    }

    private static func formatProgress(_ progress: Progress) -> String {
        let pct = Int(progress.fractionCompleted * 100)
        if progress.totalUnitCount > 0 {
            let done = ByteCountFormatter.string(
                fromByteCount: progress.completedUnitCount,
                countStyle: .file
            )
            let total = ByteCountFormatter.string(
                fromByteCount: progress.totalUnitCount,
                countStyle: .file
            )
            return "\(done) / \(total) (\(pct)%)"
        }
        return "\(pct)%"
    }

    // MARK: - Inference

    func parse(input: String) async {
        guard let container, case .ready = modelState else { return }
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isLoading = true
        result = nil
        error = nil
        rawResponse = nil
        decodedAttempt = nil

        do {
            // New session per request — we don't want prior conversation history
            // affecting the structured output.
            let session = ChatSession(
                container,
                instructions: ControlPlaneVocabulary.systemPrompt,
                generateParameters: GenerateParameters(
                    maxTokens: 1024,
                    temperature: 0   // deterministic output for structured JSON
                )
            )

            // Append /no_think to suppress Qwen3's chain-of-thought mode,
            // which would pollute the JSON response with <think>...</think> blocks.
            let promptWithFlag = input + " /no_think"
            let text = try await session.respond(to: promptWithFlag)

            rawResponse = text
            result = try decodeConfig(from: text)

        } catch let decodeError as DecodingError {
            self.error = "JSON parse error: \(decodeError.localizedDescription)"
        } catch {
            self.error = "Model error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - JSON extraction

    private func decodeConfig(from text: String) throws -> ParsedConfig {
        let cleaned = extractJSON(from: text)
        decodedAttempt = cleaned
        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "NLConfigMLX", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not encode response as UTF-8"])
        }
        var config = try JSONDecoder().decode(ParsedConfig.self, from: data)

        // Strip any hallucinated action IDs outside the known vocabulary.
        let before = config.actions.count
        config.actions = config.actions.filter { knownActionIDs.contains($0.actionID) }
        if config.actions.count < before {
            print("[MLXParser] Dropped \(before - config.actions.count) action(s) with unknown actionID")
        }
        return config
    }

    /// Three-stage extraction: strip thinking blocks → strip code fences → brace scan.
    private func extractJSON(from text: String) -> String {
        var s = text

        // Stage 1: remove Qwen3 <think>...</think> blocks entirely.
        if let thinkStart = s.range(of: "<think>"),
           let thinkEnd = s.range(of: "</think>") {
            s.removeSubrange(thinkStart.lowerBound...thinkEnd.upperBound)
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Stage 2: strip markdown code fences (```json ... ``` or ``` ... ```).
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

        // Stage 3: if still not starting with {, find outermost braces.
        if !s.hasPrefix("{") {
            if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
                s = String(s[start...end])
            }
        }

        return s
    }
}
