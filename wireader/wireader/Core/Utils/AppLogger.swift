import OSLog

enum AppLogger {
    static let general = Logger(subsystem: AppConstants.bundleID, category: "general")
    static let reader = Logger(subsystem: AppConstants.bundleID, category: "reader")
    static let ai = Logger(subsystem: AppConstants.bundleID, category: "ai")
    static let sync = Logger(subsystem: AppConstants.bundleID, category: "sync")
    static let rag = Logger(subsystem: AppConstants.bundleID, category: "rag")
}
