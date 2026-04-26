import Testing
@testable import Nemrion

@Test
func promptBuilderUsesChatRolesForOllama() {
    let messages = PromptBuilder.polishMessages(
        source: "this sentence need fix",
        instruction: "Make it concise.",
        model: "llama3.2",
        isThinkingEnabled: false
    )

    #expect(messages.map(\.role) == ["system", "user"])
    #expect(messages[0].content.contains("Return only the rewritten text."))
    #expect(messages[0].content.contains("<|think|>") == false)
    #expect(messages[1].content.contains("User text:\nthis sentence need fix"))
    #expect(messages[1].content.contains("Additional instruction:\nMake it concise."))
}

@Test
func promptBuilderUsesGemmaThinkingToken() {
    let messages = PromptBuilder.polishMessages(
        source: "this sentence need fix",
        instruction: "",
        model: "gemma4:e4b",
        isThinkingEnabled: true
    )

    #expect(messages[0].content.hasPrefix("<|think|>\n"))
    #expect(PromptBuilder.usesGemmaThinkingToken("gemma4"))
    #expect(PromptBuilder.usesGemmaThinkingToken("llama3.2") == false)
}

@Test
func generationRequestOnlyUsesThinkingForSupportedModels() {
    #expect(GenerationRequest.supportsThinking(model: "gemma4:latest"))
    #expect(GenerationRequest.supportsThinking(model: "qwen3-coder:latest"))
    #expect(GenerationRequest.supportsThinking(model: "deepseek-r1:8b"))
    #expect(GenerationRequest.supportsThinking(model: "qwen2.5:3b") == false)

    let unsupportedRequest = GenerationRequest(
        sourceText: "hello",
        instruction: "",
        model: "tinyllama:latest",
        isThinkingEnabled: true
    )

    #expect(unsupportedRequest.usesThinking == false)
}

@Test
func promptBuilderRemovesThinkingArtifacts() {
    let text = """
    <|channel>thought
    I should rewrite this internally.
    <channel|>
    This sentence needs fixing.
    """

    #expect(PromptBuilder.removingThinkingArtifacts(from: text) == "This sentence needs fixing.")
    #expect(PromptBuilder.removingThinkingArtifacts(from: "<think>hidden</think>Visible") == "Visible")
}

@Test
func promptBuilderExtractsDisplayableThinkingContent() {
    #expect(PromptBuilder.displayThinkingContent(from: "<|channel>thought\nPlan the rewrite.") == "Plan the rewrite.")
    #expect(PromptBuilder.displayThinkingContent(from: "hidden<channel|>Final answer") == "hidden")
    #expect(PromptBuilder.displayThinkingContent(from: "<think>hidden</think>Visible") == "hidden")
}
