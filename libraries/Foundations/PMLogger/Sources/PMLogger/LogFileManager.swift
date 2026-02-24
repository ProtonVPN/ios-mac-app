//
//  Created on 2021-11-23.
//
//  Copyright (c) 2021 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros
import Foundation
import os.log

@DependencyClient
public struct LogFileManager {
    /// Returns full log files URL given its name
    public var getFileUrl: (_ named: String) -> URL = { _ in URL(string: "https://proton.me")! }
    /// Dumps given string into a log file.
    /// Will overwrite the file if it's present.
    public var dump: (_ logs: String, _ toFile: String) -> Void
}

public extension DependencyValues {
    var logFileManager: LogFileManager {
        get { self[LogFileManager.self] }
        set { self[LogFileManager.self] = newValue }
    }
}

extension LogFileManager: DependencyKey {
    public static var liveValue: LogFileManager = {
        func getFileUrlLocal(named filename: String) -> URL {
            let logDirLaunchArgument = "-LogDirectory"
            let arguments = ProcessInfo.processInfo.arguments
            let logDirectory: URL = if let index = arguments.firstIndex(of: logDirLaunchArgument),
                                       case let next = arguments.index(after: index),
                                       next < arguments.count,
                                       case let dir = arguments[next],
                                       FileManager.default.fileExists(atPath: dir),
                                       let url = URL(string: dir) {
                url
            } else {
                #if os(tvOS)
                    // tvOS can reject creating custom directories directly under Library.
                    // Use Caches/Logs instead, which is writable for app sandbox data.
                    URL.applicationSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
                #else
                    URL.libraryDirectory.appendingPathComponent("Logs", isDirectory: true)
                #endif
            }

            return logDirectory.appendingPathComponent(filename, isDirectory: false)
        }

        return LogFileManager(
            getFileUrl: { filename in
                getFileUrlLocal(named: filename)
            },
            dump: { logs, filename in
                let logPath = getFileUrlLocal(named: filename)
                do {
                    try "\(logs)".data(using: .utf8)?.write(to: logPath)
                } catch {
                    os_log("Error dumping logs to file: %{public}s", log: OSLog(subsystem: "PMLogger", category: "LogFileManager"), type: OSLogType.error, error as CVarArg)
                }
            }
        )
    }()
}
