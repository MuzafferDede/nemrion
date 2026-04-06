import Foundation

protocol AIProvider: Sendable {
    func healthCheck() async -> DependencyStatus
    func availableModels() async throws -> [ProviderModel]
    func streamRewrite(request: GenerationRequest) -> AsyncThrowingStream<String, Error>
}
