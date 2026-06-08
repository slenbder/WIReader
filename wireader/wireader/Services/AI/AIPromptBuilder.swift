import Foundation

enum AIPromptBuilder {
    static let systemPrompt = """
        Ты помощник читателя. Отвечай строго по тексту.
        Информация за пределами контекста тебе недоступна.
        Не упоминай факты о персонаже, которых нет в тексте.
        """

    static func whoIsPrompt(name: String, context: String) -> String {
        "Кто такой \(name)?\n\nКонтекст из книги:\n\(context)"
    }

    static func chapterSummaryPrompt(chapterText: String) -> String {
        "Сделай краткое содержание этой главы:\n\n\(chapterText)"
    }
}
