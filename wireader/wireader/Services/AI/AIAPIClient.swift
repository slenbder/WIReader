import Foundation

struct AIMessage {
    let role: String
    let content: String
}

protocol AIAPIClientProtocol {
    func complete(messages: [AIMessage], system: String?) async throws -> String
    func stream(messages: [AIMessage], system: String?) -> AsyncThrowingStream<String, Error>
}
