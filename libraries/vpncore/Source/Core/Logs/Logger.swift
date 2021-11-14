//
//  Logger.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import OSLog
import Logging

public class PMLog {
    
    public enum LogLevel {
        case fatal, error, warn, info, debug, trace
        
        fileprivate var description: String {
            switch self {
            case .fatal:
                return "FATAL"
            case .error:
                return "ERROR"
            case .warn:
                return "WARN"
            case .info:
                return "INFO"
            case .debug:
                return "DEBUG"
            case .trace:
                return "TRACE"
            }
        }
    }
    
    public static let logsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs", isDirectory: true)
    
    private static let maxLogLines = 2000
    
    public static func logFile(_ filename: String = "ProtonVPN.log") -> URL? {
        do {
            _ = try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: false, attributes: nil)
        } catch {}
        
        let file = logsDirectory.appendingPathComponent(filename, isDirectory: false)
        
        #if !os(OSX)
        do {
            try (file as NSURL).setResourceValue( URLFileProtection.complete, forKey: .fileProtectionKey)
        } catch {}
        #endif
        
        return file
    }
    
    public static func logsContent() -> String {
        do {
            guard let logFile = logFile() else {
                return ""
            }
            return try String(contentsOf: logFile, encoding: .utf8)
        } catch {
            return ""
        }
    }
    
    public static func D(_ message: String, level: LogLevel = .info, filename: String = "ProtonVPN.log", file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        let log = "\(Date()) : \(level.description) : \((file as NSString).lastPathComponent) : \(function) : \(line) : \(column) - \(message)"
        printToConsole(log)
        
        guard let logPath = logFile(filename) else { return }
        
        pruneLogs()
        
        do {
            let fileHandle = try FileHandle(forWritingTo: logPath)
            fileHandle.seekToEndOfFile()
            fileHandle.write("\(log)\n".data(using: .utf8)!)
            fileHandle.closeFile()
        } catch {
            dump(logs: log, toFile: filename)
        }
    }
    
    public static func ET(_ message: String, level: LogLevel = .error, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        PMLog.D(message, level: .error, file: file, function: function, line: line, column: column)
    }
    
    public static func ET(_ error: Error, level: LogLevel = .error, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        ET(error.localizedDescription, level: level)
    }
    
    /// Dumps given string into a log file.
    /// Will overwrite the file if it's present.
    public static func dump(logs: String, toFile filename: String) {
        guard let logPath = logFile(filename) else { return }
        do {
            try "\(logs)".data(using: .utf8)?.write(to: logPath)
        } catch {
            printToConsole(error.localizedDescription)
        }
    }
    
    private static func pruneLogs() {
        do {
            guard let logUrl = logFile() else { return }
            
            let logContents = try String(contentsOf: logUrl, encoding: .utf8)
            let lines = logContents.components(separatedBy: .newlines)
            if lines.count > maxLogLines {
                let prunedLines = Array(lines.dropFirst(lines.count - maxLogLines))
                let replacementText = prunedLines.joined(separator: "\n")
                try replacementText.data(using: .utf8)?.write(to: logUrl)
            }
        } catch let error { printToConsole(error.localizedDescription) }
    }
    
    // swiftlint:disable no_print
    public static func printToConsole(_ text: String) {
        #if DEBUG
//        os_log("%@", text)
        #endif
    }
    // swiftlint:enable no_print
}

public class PVPNLogHelper {
    
    public enum MetaKey: String {
        case category
        case event
    }
    
    public enum Category: String {
        case connection = "conn"
        case connectionConnect = "conn.connect"
        case connectionDisconnect = "conn.disconnect"
        case localAgent = "local_agent"
        case ui
        case user
        case userCert = "user_cert"
        case userPlan = "user_plan"
        case api
        case net
        case `protocol`
        case app
        case os
        case settings
    }

    public enum Event: String {
        case currentState = "current_state"
        case stateChange = "state_change"
        case error
        case trigger
        case scan
        case scanFailed = "scan_failed"
        case scanResult = "scan_result"
        case start
        case connected
        case serverSelected = "server_selected"
        case switchFailed = "switch_failed"
        case log
        case status
        case connect
        case disconnect
        case currentCertificate = "current_cert"
        case refresh
        case revoked
        case newCertificate = "new_cert"
        case refreshError = "refresh_error"
        case scheduleRefresh = "schedule_refresh"
        case currentPlan = "current_plan"
        case change
        case maxSessionsReached = "max_sessions_reached"
        case request
        case response
        case currentNetwork = "current_network"
        case networkUnavailable = "network_unavailable"
        case networkChanged = "network_changed"
        case processStart = "process_start"
        case crash
        case updateCheck = "update_check"
        case info
        case currentSettings = "current_settings"
    }
    
    public static func setupLogsForApp() {
        LoggingSystem.bootstrap {_ in
            return ConsoleLogHandler()
        }

    }
    
}
