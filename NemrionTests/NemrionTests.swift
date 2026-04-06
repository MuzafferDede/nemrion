import Testing
@testable import Nemrion

@Test
func promptBuilderIncludesCoreRewriteInstructions() {
    let prompt = PromptBuilder.polish(
        source: "When I try to get into know you more, I am not really sure how can I do it tho.",
        instruction: ""
    )

    #expect(prompt.contains("Return only the rewritten text."))
    #expect(prompt.contains("Preserve the original meaning."))
}
