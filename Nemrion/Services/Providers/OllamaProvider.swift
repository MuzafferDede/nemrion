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

                    var responseText = ""
                    var isThinking = false
                    for try await line in bytes.lines {
                        guard line.isEmpty == false else { continue }
                        let data = Data(line.utf8)
                        let chunk = try JSONDecoder().decode(ChatChunk.self, from: data)
                        if chunk.done { break }

                        if let thinking = chunk.message?.thinking, thinking.isEmpty == false {
                            if isThinking == false {
                                isThinking = true
                            }
                            continuation.yield(.thinking(thinking))
                            continue
                        }

                        guard let content = chunk.message?.content, content.isEmpty == false else { continue }
                        if PromptBuilder.containsThinkingStart(content) {
                            if isThinking == false {
                                isThinking = true
                            }
                        }
                        let hasThinkingEnd = PromptBuilder.containsThinkingEnd(content)
                        if isThinking, hasThinkingEnd == false, PromptBuilder.containsThinkingStart(content) == false {
                            isThinking = false
                            continuation.yield(.thinkingEnded)
                        }
                        if isThinking {
                            let visibleThinking = PromptBuilder.displayThinkingContent(from: content)
                            if visibleThinking.isEmpty == false {
                                continuation.yield(.thinking(visibleThinking))
                            }
                        }
                        if isThinking, hasThinkingEnd {
                            isThinking = false
                            continuation.yield(.thinkingEnded)
                        }

                        responseText += content
                    }

                    if isThinking {
                        continuation.yield(.thinkingEnded)
                    }
                    let sanitizedResponse = PromptBuilder.removingThinkingArtifacts(from: responseText)
                    if sanitizedResponse.isEmpty == false {
                        continuation.yield(.content(sanitizedResponse))
                    }
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

    static func removingThinkingArtifacts(from text: String) -> String {
        var result = text
        let patterns = [
            #"<\|channel\>thought\s*.*?<channel\|>"#,
            #"<think>.*?</think>"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.dotMatchesLineSeparators, .caseInsensitive]
            ) else {
                continue
            }

            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func containsThinkingStart(_ text: String) -> Bool {
        text.range(of: #"<\|channel\>thought|<think>"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func containsThinkingEnd(_ text: String) -> Bool {
        text.range(of: #"<channel\|>|</think>"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func displayThinkingContent(from text: String) -> String {
        var result = text
        let patterns = [
            #"<channel\|>.*"#,
            #"</think>.*"#,
            #"<\|channel\>thought\s*"#,
            #"<channel\|>"#,
            #"<think>"#,
            #"</think>"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
                continue
            }

            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result
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
