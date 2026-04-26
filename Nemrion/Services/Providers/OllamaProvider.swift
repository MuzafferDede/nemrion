import Foundation

struct OllamaProvider: AIProvider {
    private let session: URLSession = .shared
    private let baseURL = URL(string: "http://127.0.0.1:11434")!

    func healthCheck() async -> DependencyStatus {
        let fileManager = FileManager.default
        let installPaths = [
            "/Applications/Ollama.app",
            "\(NSHomeDirectory())/Applications/Ollama.app"
        ]

        let isInstalled = installPaths.contains(where: { fileManager.fileExists(atPath: $0) })
        guard isInstalled else { return .ollamaMissing }

        var request = URLRequest(url: baseURL.appending(path: "/api/tags"))
        request.timeoutInterval = 2

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .ready
            }
            return .ollamaStopped
        } catch {
            return .ollamaStopped
        }
    }

    func availableModels() async throws -> [ProviderModel] {
        let (data, _) = try await session.data(from: baseURL.appending(path: "/api/tags"))
        let response = try JSONDecoder().decode(TagListResponse.self, from: data)
        return response.models.map { ProviderModel(id: $0.name, title: $0.name) }
    }

    func streamRewrite(request: GenerationRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var urlRequest = URLRequest(url: baseURL.appending(path: "/api/generate"))
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body = GenerateRequest(
                        model: request.model,
                        prompt: PromptBuilder.polish(source: request.sourceText, instruction: request.instruction),
                        stream: true,
                        options: GenerateOptions(temperature: 0.25)
                    )

                    urlRequest.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        throw NemrionError.providerUnavailable("Ollama did not accept the request.")
                    }

                    for try await line in bytes.lines {
                        guard line.isEmpty == false else { continue }
                        let data = Data(line.utf8)
                        let chunk = try JSONDecoder().decode(GenerateChunk.self, from: data)
                        if chunk.done { break }
                        continuation.yield(chunk.response)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum PromptBuilder {
    static func polish(source: String, instruction: String) -> String {
        var prompt = """
        Rewrite the user's text so it sounds natural, clear, and polished.
        Preserve the original meaning.
        Repair likely intended wording when the sentence is awkward or broken.
        Do not add facts.
        Return only the rewritten text.

        User text:
        \(source)
        """

        if instruction.isEmpty == false {
            prompt += "\n\nAdditional instruction:\n\(instruction)"
        }

        return prompt
    }
}

private struct TagListResponse: Decodable {
    let models: [Tag]

    struct Tag: Decodable {
        let name: String
    }
}

private struct GenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
    let think: Bool = false
    let options: GenerateOptions
}

private struct GenerateOptions: Encodable {
    let temperature: Double
    let num_predict: Int = 512
    let stop: [String] = ["\n\nUser text:"]
}

private struct GenerateChunk: Decodable {
    let response: String
    let done: Bool
}
