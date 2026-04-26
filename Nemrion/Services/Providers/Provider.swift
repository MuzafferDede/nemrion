import Foundation

protocol AIProvider: Sendable {
    func healthCheck() async -> DependencyStatus
    func availableModels() async throws -> [ProviderModel]
    func streamRewrite(request: GenerationRequest) -> AsyncThrowingStream<GenerationStreamEvent, Error>
}

enum GenerationStreamEvent: Sendable, Equatable {
    case content(String)
    case thinking(String)
    case thinkingEnded
}
