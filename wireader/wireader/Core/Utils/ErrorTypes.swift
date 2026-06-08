import Foundation

enum WIReaderError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case importFailed(String)
    case parseError(String)
    case aiError(String)
    case networkError(String)
    case storageError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "File not found"
        case .unsupportedFormat: return "Unsupported file format"
        case .importFailed(let msg): return "Import failed: \(msg)"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .aiError(let msg): return "AI error: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .storageError(let msg): return "Storage error: \(msg)"
        }
    }
}
