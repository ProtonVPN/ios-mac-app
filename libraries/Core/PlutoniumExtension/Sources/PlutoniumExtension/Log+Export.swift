//
//  Created on 24/04/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Logging
import os.log
import PMLogger

// Global logger for Plutonium extension
package let log: Logging.Logger = .init(label: "ProtonVPN.Plutonium.logger")

// MARK: - Public Logging Setup

/// Setup logging infrastructure for Plutonium extension (called from main.swift)
public func setupPlutoniumLogging() {
    let multiplexLogHandler: MultiplexLogHandler
    do {
        let logFile = try getPlutoniumLogFileURL()
        let fileLogHandler = FileLogHandler(logFile)

        // Configure rotation settings (match WireGuard)
        fileLogHandler.maxFileSize = 1024 * 100 // 100 KiB
        fileLogHandler.maxArchivedFilesCount = 1 // 1 archived file

        // Combine OSLog and file logging
        let osLogHandler = OSLogHandler(formatter: OSLogFormatter())
        multiplexLogHandler = MultiplexLogHandler([osLogHandler, fileLogHandler])

        os_log("Split tunneling logging configured with file: %{public}s", log: OSLog.default, type: .info, logFile.path)
    } catch {
        os_log("Failed to setup file logging for Split tunneling: %{public}s", log: OSLog.default, type: .error, String(describing: error))
        // Fallback to OSLog only
        multiplexLogHandler = MultiplexLogHandler([OSLogHandler(formatter: OSLogFormatter())])
    }

    // Bootstrap the logging system
    LoggingSystem.bootstrap { _ in multiplexLogHandler }
}

// Used for logs in Plutonium IPC Service
public func plutoniumIPCLog(_ message: String) {
    log.info("\(message)", category: .ipc)
}

// MARK: - Public Helpers

public enum PlutoniumLogError: Error {
    case fileNotFound
}

public func getPlutoniumLogFileURL(createIfMissing: Bool = true) throws -> URL {
    // System extension safe log location (survives system cleanups)
    let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    let logsDir = libraryDir.appendingPathComponent("Logs", isDirectory: true)

    // Ensure directory exists
    try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)

    let logFile = logsDir.appendingPathComponent("Split tunneling-Extension.log")

    // Create file if it doesn't exist
    if !FileManager.default.fileExists(atPath: logFile.path) {
        if createIfMissing {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        } else {
            throw PlutoniumLogError.fileNotFound
        }
    }

    return logFile
}
