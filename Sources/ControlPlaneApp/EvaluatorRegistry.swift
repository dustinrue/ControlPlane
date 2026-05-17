import Foundation
import ControlPlaneSDK

/// Stores loaded evaluator plugins and vends them by ID.
actor EvaluatorRegistry {
    private var evaluators: [String: any EvaluatorPlugin] = [:]

    func register(_ evaluator: any EvaluatorPlugin) {
        evaluators[evaluator.pluginIdentifier] = evaluator
        log("Evaluator registered: \(evaluator.pluginIdentifier)", CPLogger.plugins)
    }

    func evaluator(for id: String) -> (any EvaluatorPlugin)? {
        evaluators[id]
    }

    func list() -> [EvaluatorInfo] {
        evaluators.values.map { e in
            EvaluatorInfo(
                id: e.pluginIdentifier,
                displayName: e.pluginDisplayName,
                version: e.pluginVersion,
                operators: e.supportedOperators()
            )
        }.sorted { $0.id < $1.id }
    }

    func count() -> Int {
        evaluators.count
    }
}
