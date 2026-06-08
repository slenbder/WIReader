import Foundation

@Observable
final class AIViewModel {
    var streamedResponse: String = ""
    var isLoading: Bool = false

    private let client: AIAPIClientProtocol = OpenRouterClient()

    func whoIs(name: String, context: String) async {
        isLoading = true
        streamedResponse = ""
        let messages = [AIMessage(role: "user", content: AIPromptBuilder.whoIsPrompt(name: name, context: context))]
        do {
            for try await token in client.stream(messages: messages, system: AIPromptBuilder.systemPrompt) {
                streamedResponse += token
            }
        } catch {
            streamedResponse = "Ошибка: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func summarizeChapter(book: Book, chapterIndex: Int) async {
        isLoading = true
        streamedResponse = ""
        let messages = [AIMessage(role: "user", content: AIPromptBuilder.chapterSummaryPrompt(chapterText: ""))]
        do {
            streamedResponse = try await client.complete(messages: messages, system: nil)
        } catch {
            streamedResponse = "Ошибка: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
