// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log
import WireGuardLoggingC

package final class Logger: @unchecked Sendable {
    enum LoggerError: Error {
        case openFailure
    }

#if swift(>=5.10)
    nonisolated(unsafe) static private(set) var global: Logger?
#else
    static private(set) var global: Logger?
#endif

    private static let lock = NSLock()

    private let log: OpaquePointer
    private let tag: String

    private init(tagged tag: String, withFilePath filePath: String) throws {
        guard let log = open_log(filePath) else { throw LoggerError.openFailure }
        self.log = log
        self.tag = tag
    }

    deinit {
        close_log(self.log)
    }

    func log(message: String) {
        write_msg_to_log(log, tag, message.trimmingCharacters(in: .newlines))
    }

    func writeLog(to targetFile: String) -> Bool {
        return write_log_to_file(targetFile, self.log) == 0
    }

    package static func configureGlobal(tagged tag: String, withFilePath filePath: String?) {
        lock.withLock {
            if Logger.global != nil {
                return
            }
            guard let filePath = filePath else {
                os_log("Unable to determine log destination path. Log will not be saved to file.", log: OSLog.default, type: .error)
                return
            }
            guard let logger = try? Logger(tagged: tag, withFilePath: filePath) else {
                os_log("Unable to open log file for writing. Log will not be saved to file.", log: OSLog.default, type: .error)
                return
            }
            Logger.global = logger
            var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
            if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                appVersion += " (\(appBuild))"
            }

            Logger.global?.log(message: "WG Extension version: \(appVersion)")
        }
    }
}

extension OSLog {
#if swift(>=6.0)
    #warning("Reevaluate whether this concurrency decoration is necessary.")
#elseif swift(>=5.10)
    nonisolated(unsafe) package static let wg = OSLog(subsystem: "PROTON-WG", category: "WireGuard")
#else
    package static let wg = OSLog(subsystem: "PROTON-WG", category: "WireGuard")
#endif
}

package func wg_log(_ type: OSLogType, staticMessage msg: StaticString) {
    os_log("%{public}s", log: OSLog.wg, type: type, String(describing: msg))
    Logger.global?.log(message: "\(type.stringValue.uppercased()) | PROTOCOL | \(msg)")
}

package func wg_log(_ type: OSLogType, message msg: String) {
    os_log("%{public}s", log: OSLog.wg, type: type, msg)
    Logger.global?.log(message: "\(type.stringValue.uppercased()) | PROTOCOL | \(msg)")
}

extension OSLogType {
    var stringValue: String {
        switch self {
        case .info:
            return "Info"
        case .debug:
            return "Debug"
        case .error:
            return "Error"
        case .fault:
            return "Fatal"
        default:
            return "Debug"
        }
    }
}
