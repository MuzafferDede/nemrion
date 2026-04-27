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
    #expect(messages[0].content.contains("Return exactly the text that should replace the selection."))
    #expect(messages[0].content.contains("usable if pasted over the selected text with no editing"))
    #expect(messages[0].content.contains("Do not include any surrounding metadata"))
    #expect(messages[0].content.contains("<|think|>") == false)
    #expect(messages[1].content.contains("<source_text>\nthis sentence need fix\n</source_text>"))
    #expect(messages[1].content.contains("<rewrite_instruction>\nMake it concise.\n</rewrite_instruction>"))
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
func inlineThinkingParserStreamsVisibleContent() {
    var parser = InlineThinkingStreamParser()

    let events = parser.consume("This is ")
        + parser.consume("visible")
        + parser.finish()

    #expect(events == [.content("This is "), .content("visible")])
}

@Test
func inlineThinkingParserRemovesSplitThinkTags() {
    var parser = InlineThinkingStreamParser()

    let events = parser.consume("<thi")
        + parser.consume("nk>hidden")
        + parser.consume("</thi")
        + parser.consume("nk>Visible")
        + parser.finish()

    #expect(events == [.thinking("hidden"), .thinkingEnded, .content("Visible")])
}

@Test
func inlineThinkingParserHandlesChannelThoughtTokens() {
    var parser = InlineThinkingStreamParser()

    let events = parser.consume("<|channel>thought\nPlan")
        + parser.consume(" it<channel|>Done")
        + parser.finish()

    #expect(events == [.thinking("\nPlan"), .thinking(" it"), .thinkingEnded, .content("Done")])
}
