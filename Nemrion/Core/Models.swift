import AppKit
import Foundation

struct AppSettings: Equatable {
    var provider: ProviderKind = .ollama
    var modelName: String = ""
    var hotKeyDisplay: String = "Shift-Command-Space"
}

enum ProviderKind: String, CaseIterable, Identifiable {
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama:
            return "Ollama"
        }
    }
}

enum RewriteAction: String, CaseIterable, Identifiable {
    case polish

    var id: String { rawValue }
    var title: String { "Polish" }
}

struct ProviderModel: Identifiable, Hashable {
    let id: String
    let title: String
}

struct GenerationRequest: Sendable {
    let sourceText: String
    let instruction: String
    let action: RewriteAction
    let model: String
}

struct CapturedSelection: Sendable {
    let text: String
    let appName: String
    let bundleIdentifier: String?
    let bounds: CGRect?
}

enum DependencyStatus: Equatable {
    case checking
    case ready
    case ollamaMissing
    case ollamaStopped
    case unavailable(String)

    var title: String {
        switch self {
        case .checking:
            return "Checking local model runtime"
        case .ready:
            return "Running"
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
