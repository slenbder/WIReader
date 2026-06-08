import Foundation

final class OpenRouterClient: AIAPIClientProtocol {
    private let baseURL = APIConstants.openRouterBaseURL
    private let model = APIConstants.defaultModel
    private let session = URLSession.shared

    private var apiKey: String {
        // Retrieve from Keychain in production
        return ""
    }

    func complete(messages: [AIMessage], system: String?) async throws -> String {
        let request = try buildRequest(messages: messages, system: system, stream: false)
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    func stream(messages: [AIMessage], system: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(messages: messages, system: system, stream: true)
                    let (bytes, _) = try await self.session.bytes(for: request)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "), !line.contains("[DONE]") else { continue }
                        let jsonData = Data(line.dropFirst(6).utf8)
                        if let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: jsonData),
                           let token = chunk.choices.first?.delta.content {
                            continuation.yield(token)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildRequest(messages: [AIMessage], system: String?, stream: Bool) throws -> URLRequest {
        guard let url = URL(string: baseURL) else { throw WIReaderError.networkError("Invalid URL") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var allMessages: [[String: String]] = []
        if let system {
            allMessages.append(["role": "system", "content": system])
        }
        allMessages += messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = ["model": model, "messages": allMessages, "stream": stream]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

private struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}
