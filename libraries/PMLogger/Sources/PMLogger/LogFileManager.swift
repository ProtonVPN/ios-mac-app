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

import Foundation
import os.log

public protocol LogFileManagerFactory {
    func makeLogFileManager() -> LogFileManager
}

public protocol LogFileManager {
    func getFileUrl(named filename: String) -> URL
    func dump(logs: String, toFile filename: String)
}

public class LogFileManagerImplementation: LogFileManager {
    
    public init() {
    }
    
    /// Returns full log files URL given its name
    public func getFileUrl(named filename: String) -> URL {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
    }
    
    /// Dumps given string into a log file.
    /// Will overwrite the file if it's present.
    public func dump(logs: String, toFile filename: String) {
        let logPath = getFileUrl(named: filename)
        do {
            try "\(logs)".data(using: .utf8)?.write(to: logPath)
        } catch {
            os_log("Error dumping logs to file: %{public}s", log: OSLog(subsystem: "PMLogger", category: "LogFileManager"), type: OSLogType.error, error as CVarArg)
        }
    }
    
}
