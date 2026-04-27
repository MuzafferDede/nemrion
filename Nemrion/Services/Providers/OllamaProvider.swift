import Foundation

struct OllamaProvider: AIProvider {
    private let session: URLSession = .shared
    private let baseURL = URL(string: "http://127.0.0.1:11434")!
    private static let installPaths = [
        "/Applications/Ollama.app",
        "\(NSHomeDirectory())/Applications/Ollama.app"
    ]

    func healthCheck() async -> DependencyStatus {
        guard isInstalled else { return .ollamaMissing }

        do {
            let (_, response) = try await session.data(for: makeRequest(path: "/api/tags", timeout: 2))
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .ready
            }
            return .ollamaStopped
        } catch {
            return .ollamaStopped
        }
    }

    func availableModels() async throws -> [ProviderModel] {
        let (data, _) = try await session.data(for: makeRequest(path: "/api/tags"))
        let response = try JSONDecoder().decode(TagListResponse.self, from: data)
        return response.models.map { ProviderModel(id: $0.name, title: $0.name) }
    }

    func prewarm(model: String) async {
        guard model.isEmpty == false else { return }

        do {
            let request = try makeJSONRequest(
                path: "/api/generate",
                timeout: 20,
                body: PrewarmRequest(
                    model: model,
                    prompt: " ",
                    stream: false,
                    keepAlive: "10m",
                    options: PrewarmOptions()
                )
            )

            _ = try await session.data(for: request)
        } catch {
            // Prewarming is best effort; normal generation still surfaces provider errors.
        }
    }

    func streamRewrite(request: GenerationRequest) -> AsyncThrowingStream<GenerationStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try makeJSONRequest(path: "/api/chat", body: makeChatRequest(for: request))
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

                    var stream = OllamaStreamAccumulator()

                    for try await line in bytes.lines {
                        guard line.isEmpty == false else { continue }
                        let data = Data(line.utf8)
                        let chunk = try JSONDecoder().decode(ChatChunk.self, from: data)
                        if chunk.done { break }

                        for event in stream.events(from: chunk) {
                            continuation.yield(event)
                        }
                    }

                    for event in stream.finish() {
                        continuation.yield(event)
                    }
                    guard stream.didEmitContent else { throw NemrionError.malformedResponse }
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

    private var isInstalled: Bool {
        let fileManager = FileManager.default
        return Self.installPaths.contains { fileManager.fileExists(atPath: $0) }
    }

    private func makeRequest(path: String, method: String = "GET", timeout: TimeInterval? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let timeout {
            request.timeoutInterval = timeout
        }
        return request
    }

    private func makeJSONRequest<T: Encodable>(
        path: String,
        timeout: TimeInterval? = nil,
        body: T
    ) throws -> URLRequest {
        var request = makeRequest(path: path, method: "POST", timeout: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func makeChatRequest(for request: GenerationRequest) -> ChatRequest {
        ChatRequest(
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
    }
}

private struct OllamaStreamAccumulator {
    private(set) var didEmitContent = false
    private var isThinking = false
    private var inlineParser = InlineThinkingStreamParser()

    mutating func events(from chunk: ChatChunk) -> [GenerationStreamEvent] {
        if let thinking = chunk.message?.thinking, thinking.isEmpty == false {
            isThinking = true
            return [.thinking(thinking)]
        }

        guard let content = chunk.message?.content, content.isEmpty == false else { return [] }

        var events: [GenerationStreamEvent] = []
        if isThinking {
            isThinking = false
            events.append(.thinkingEnded)
        }
        events.append(contentsOf: inlineParser.consume(content))
        return recordContent(in: events)
    }

    mutating func finish() -> [GenerationStreamEvent] {
        var events: [GenerationStreamEvent] = []
        if isThinking {
            isThinking = false
            events.append(.thinkingEnded)
        }
        events.append(contentsOf: inlineParser.finish())
        return recordContent(in: events)
    }

    private mutating func recordContent(in events: [GenerationStreamEvent]) -> [GenerationStreamEvent] {
        if events.contains(where: {
            if case .content = $0 { return true }
            return false
        }) {
            didEmitContent = true
        }
        return events
    }
}

struct InlineThinkingStreamParser {
    private var pending = ""
    private var isThinking = false

    mutating func consume(_ chunk: String) -> [GenerationStreamEvent] {
        var events: [GenerationStreamEvent] = []
        var text = pending + chunk
        pending = ""

        while text.isEmpty == false {
            if isThinking {
                if let range = firstMatch(in: text, tokens: Self.thinkingEndTokens) {
                    let thinking = String(text[..<range.lowerBound])
                    if thinking.isEmpty == false {
                        events.append(.thinking(thinking))
                    }
                    events.append(.thinkingEnded)
                    isThinking = false
                    text = String(text[range.upperBound...])
                } else {
                    let split = splitForPossibleToken(text, tokens: Self.thinkingEndTokens)
                    if split.emit.isEmpty == false {
                        events.append(.thinking(split.emit))
                    }
                    pending = split.pending
                    break
                }
            } else {
                if let range = firstMatch(in: text, tokens: Self.thinkingStartTokens) {
                    let visible = String(text[..<range.lowerBound])
                    if visible.isEmpty == false {
                        events.append(.content(visible))
                    }
                    isThinking = true
                    text = String(text[range.upperBound...])
                } else {
                    let split = splitForPossibleToken(text, tokens: Self.thinkingStartTokens)
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

    private func firstMatch(in text: String, tokens: [String]) -> Range<String.Index>? {
        tokens
            .compactMap { token in
                text.range(of: token, options: .caseInsensitive)
            }
            .min { lhs, rhs in
                lhs.lowerBound < rhs.lowerBound
            }
    }

    private func splitForPossibleToken(
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
    You rewrite selected text for direct replacement in the user's document.

    Task:
    Make the selected text natural, clear, and polished.
    Preserve the original meaning.
    Repair likely intended wording when the sentence is awkward or broken.
    Do not add facts.

    Response format:
    Return exactly the text that should replace the selection.
    The response must be usable if pasted over the selected text with no editing.
    Do not include any surrounding metadata, commentary, formatting, markup, or restatement of the source.
    """

    private static func polishUserMessage(source: String, instruction: String) -> String {
        var message = """
        Rewrite the content inside <source_text>. Return only replacement text.

        <source_text>
        \(source)
        </source_text>
        """
        if instruction.isEmpty == false {
            message += """

            <rewrite_instruction>
            \(instruction)
            </rewrite_instruction>
            """
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

private struct PrewarmRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
    let keepAlive: String
    let options: PrewarmOptions

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case stream
        case keepAlive = "keep_alive"
        case options
    }
}

private struct PrewarmOptions: Encodable {
    let numPredict: Int = 1

    enum CodingKeys: String, CodingKey {
        case numPredict = "num_predict"
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
}

private struct ChatChunk: Decodable {
    let message: ChatMessage?
    let done: Bool
}

private struct OllamaErrorResponse: Decodable {
    let error: String
}
