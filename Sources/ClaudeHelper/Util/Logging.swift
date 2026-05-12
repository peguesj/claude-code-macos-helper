import Foundation
import OSLog

enum Log {
    private static let logger = Logger(subsystem: "io.pegues.ClaudeHelper", category: "main")
    static func info(_ msg: String)    { logger.info("\(msg, privacy: .public)") }
    static func warn(_ msg: String)    { logger.warning("\(msg, privacy: .public)") }
    static func error(_ msg: String)   { logger.error("\(msg, privacy: .public)") }
    static func debug(_ msg: String)   { logger.debug("\(msg, privacy: .public)") }
}
