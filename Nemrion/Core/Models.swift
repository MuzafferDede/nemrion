import AppKit
import Foundation

struct AppSettings: Codable, Equatable {
    var provider: ProviderKind = .ollama
    var modelName: String = ""
    var isThinkingEnabled: Bool = false
    var hotKeyDisplay: String = "Shift-Command-Space"
}

enum ProviderKind: String, CaseIterable, Identifiable, Codable {
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama:
            return "Ollama"
        }
    }
}

struct ProviderModel: Identifiable, Hashable {
    let id: String
    let title: String
}

struct GenerationRequest: Sendable {
    let sourceText: String
    let instruction: String
    let model: String
    let isThinkingEnabled: Bool

    var usesThinking: Bool {
        isThinkingEnabled && Self.supportsThinking(model: model)
    }

    static func supportsThinking(model: String) -> Bool {
        let normalizedModel = model.lowercased()
        return normalizedModel.hasPrefix("gemma4")
            || normalizedModel.hasPrefix("qwen3")
            || normalizedModel.hasPrefix("deepseek-r1")
    }
}

struct CapturedSelection: Sendable {
    let text: String
    let appName: String
    let bundleIdentifier: String?
    let bounds: CGRect?
}

enum DependencyStatus: Equatable {
    case checking
    case warmingModel
    case ready
    case ollamaMissing
    case ollamaStopped
    case unavailable(String)

    var title: String {
        switch self {
        case .checking:
            return "Checking local model runtime"
        case .warmingModel:
            return "Loading selected model"
        case .ready:
            return "Ollama Ready"
        case .ollamaMissing:
            return "Install Ollama"
        case .ollamaStopped:
            return "Start Ollama"
        case let .unavailable(message):
            return message
        }
    }
}

enum RewritePhase: Equatable {
    case idle
    case capturing
    case generating
    case ready
    case failure(String)
}

enum NemrionError: LocalizedError {
    case accessibilityDenied
    case noSelection
    case replacementFailed
    case providerUnavailable(String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Nemrion needs Accessibility access to capture and replace text reliably."
        case .noSelection:
            return "No selected text was found. Select text in another app and try again."
        case .replacementFailed:
            return "Nemrion could not apply the rewritten text back into the source app."
        case let .providerUnavailable(reason):
            return reason
        case .malformedResponse:
            return "The AI provider returned an invalid response."
        }
    }
}
