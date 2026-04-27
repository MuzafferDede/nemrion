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

    func streamRewrite(request: GenerationRequest) -> AsyncThrowingStream<GenerationStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var urlRequest = URLRequest(url: baseURL.appending(path: "/api/chat"))
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body = ChatRequest(
                        model: request.model,
                        messages: PromptBuilder.polishMessages(
                            source: request.sourceText,
                            instruction: request.instruction,
                            model: request.model,
                            isThinkingEnabled: request.usesThinking
                        ),
                        stream: true,
                        think: request.usesThinking,
                        options: GenerateOptions(temperature: 0.25)
                    )

                    urlRequest.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorText = ""
                        for try await line in bytes.lines {
                            errorText += line
                        }
                        throw NemrionError.providerUnavailable(
                            PromptBuilder.ollamaErrorMessage(statusCode: httpResponse.statusCode, responseBody: errorText)
                        )
                    }

                    var isThinking = false
                    var inlineParser = InlineThinkingStreamParser()
                    var didEmitContent = false

                    func yield(_ event: GenerationStreamEvent) {
                        if case .content = event {
                            didEmitContent = true
                        }
                        continuation.yield(event)
                    }

                    for try await line in bytes.lines {
                        guard line.isEmpty == false else { continue }
                        let data = Data(line.utf8)
                        let chunk = try JSONDecoder().decode(ChatChunk.self, from: data)
                        if chunk.done { break }

                        if let thinking = chunk.message?.thinking, thinking.isEmpty == false {
                            if isThinking == false {
                                isThinking = true
                            }
                            yield(.thinking(thinking))
                            continue
                        }

                        guard let content = chunk.message?.content, content.isEmpty == false else { continue }
                        if isThinking {
                            isThinking = false
                            yield(.thinkingEnded)
                        }
                        for event in inlineParser.consume(content) {
                            yield(event)
                        }
                    }

                    if isThinking {
                        yield(.thinkingEnded)
                    }
                    for event in inlineParser.finish() {
                        yield(event)
                    }
                    guard didEmitContent else { throw NemrionError.malformedResponse }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private struct InlineThinkingStreamParser {
    private var pending = ""
    private var isThinking = false

    mutating func consume(_ chunk: String) -> [GenerationStreamEvent] {
        var events: [GenerationStreamEvent] = []
        var text = pending + chunk
        pending = ""

        while text.isEmpty == false {
            if isThinking {
                if let match = firstMatch(in: text, tokens: Self.thinkingEndTokens) {
                    let thinking = String(text[..<match.range.lowerBound])
                    if thinking.isEmpty == false {
                        events.append(.thinking(thinking))
                    }
                    events.append(.thinkingEnded)
                    isThinking = false
                    text = String(text[match.range.upperBound...])
                } else {
                    let split = splitTrailingPossibleTokenPrefix(text, tokens: Self.thinkingEndTokens)
                    if split.emit.isEmpty == false {
                        events.append(.thinking(split.emit))
                    }
                    pending = split.pending
                    break
                }
            } else {
                if let match = firstMatch(in: text, tokens: Self.thinkingStartTokens) {
                    let visible = String(text[..<match.range.lowerBound])
                    if visible.isEmpty == false {
                        events.append(.content(visible))
                    }
                    isThinking = true
                    text = String(text[match.range.upperBound...])
                } else {
                    let split = splitTrailingPossibleTokenPrefix(text, tokens: Self.thinkingStartTokens)
                    if split.emit.isEmpty == false {
                        events.append(.content(split.emit))
                    }
                    pending = split.pending
                    break
                }
            }
        }

        return events
    }

    mutating func finish() -> [GenerationStreamEvent] {
        defer {
            pending = ""
            isThinking = false
        }

        guard pending.isEmpty == false else {
            return isThinking ? [.thinkingEnded] : []
        }

        if isThinking {
            return [.thinking(pending), .thinkingEnded]
        }
        return [.content(pending)]
    }

    private static let thinkingStartTokens = ["<think>", "<|channel>thought"]
    private static let thinkingEndTokens = ["</think>", "<channel|>"]

    private func firstMatch(in text: String, tokens: [String]) -> (range: Range<String.Index>, token: String)? {
        tokens
            .compactMap { token in
                text.range(of: token, options: .caseInsensitive).map { (range: $0, token: token) }
            }
            .min { lhs, rhs in
                lhs.range.lowerBound < rhs.range.lowerBound
            }
    }

    private func splitTrailingPossibleTokenPrefix(
        _ text: String,
        tokens: [String]
    ) -> (emit: String, pending: String) {
        guard text.isEmpty == false else { return ("", "") }

        let lowercasedText = text.lowercased()
        let lowercasedTokens = tokens.map { $0.lowercased() }
        var longestPrefixLength = 0

        for length in 1...text.count {
            let suffixStart = lowercasedText.index(lowercasedText.endIndex, offsetBy: -length)
            let suffix = String(lowercasedText[suffixStart...])
            if lowercasedTokens.contains(where: { $0.hasPrefix(suffix) }) {
                longestPrefixLength = length
            }
        }

        guard longestPrefixLength > 0 else { return (text, "") }

        let splitIndex = text.index(text.endIndex, offsetBy: -longestPrefixLength)
        return (String(text[..<splitIndex]), String(text[splitIndex...]))
    }
}

enum PromptBuilder {
    static func polishMessages(
        source: String,
        instruction: String,
        model: String,
        isThinkingEnabled: Bool
    ) -> [ChatMessage] {
        [
            ChatMessage(
                role: "system",
                content: systemInstruction(model: model, isThinkingEnabled: isThinkingEnabled)
            ),
            ChatMessage(role: "user", content: polishUserMessage(source: source, instruction: instruction))
        ]
    }

    static func usesGemmaThinkingToken(_ model: String) -> Bool {
        model.lowercased().hasPrefix("gemma4")
    }

    static func ollamaErrorMessage(statusCode: Int, responseBody: String) -> String {
        let fallback = "Ollama did not accept the request. HTTP \(statusCode)."
        guard responseBody.isEmpty == false else { return fallback }

        if
            let data = responseBody.data(using: .utf8),
            let errorResponse = try? JSONDecoder().decode(OllamaErrorResponse.self, from: data),
            errorResponse.error.isEmpty == false {
            return "Ollama did not accept the request. HTTP \(statusCode): \(errorResponse.error)"
        }

        return "Ollama did not accept the request. HTTP \(statusCode): \(responseBody)"
    }

    private static func systemInstruction(model: String, isThinkingEnabled: Bool) -> String {
        guard isThinkingEnabled, usesGemmaThinkingToken(model) else {
            return polishSystemInstruction
        }

        return "<|think|>\n\(polishSystemInstruction)"
    }

    private static let polishSystemInstruction = """
    Rewrite the user's text so it sounds natural, clear, and polished.
    Preserve the original meaning.
    Repair likely intended wording when the sentence is awkward or broken.
    Do not add facts.
    Return only the rewritten text.
    """

    private static func polishUserMessage(source: String, instruction: String) -> String {
        var message = "User text:\n\(source)"
        if instruction.isEmpty == false {
            message += "\n\nAdditional instruction:\n\(instruction)"
        }
        return message
    }
}

private struct TagListResponse: Decodable {
    let models: [Tag]

    struct Tag: Decodable {
        let name: String
    }
}

struct ChatMessage: Codable, Equatable {
    let role: String
    let content: String
    let thinking: String?

    init(role: String, content: String, thinking: String? = nil) {
        self.role = role
        self.content = content
        self.thinking = thinking
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "assistant"
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        thinking = try container.decodeIfPresent(String.self, forKey: .thinking)
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let think: Bool?
    let options: GenerateOptions
}

private struct GenerateOptions: Encodable {
    let temperature: Double
    let num_predict: Int = 512
    let stop: [String] = ["\n\nUser text:"]
}

private struct ChatChunk: Decodable {
    let message: ChatMessage?
    let done: Bool
}

private struct OllamaErrorResponse: Decodable {
    let error: String
}
