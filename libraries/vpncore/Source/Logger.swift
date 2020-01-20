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
import Sentry

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
        
        fileprivate var sentryLevel: SentrySeverity {
            switch self {
            case .fatal:
                return .fatal
            case .error:
                return .error
            case .warn:
                return .warning
            case .info:
                return .info
            case .debug, .trace:
                return .debug
            }
        }
    }
    
    public static let logsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs", isDirectory: true)
    
    private static let maxLogLines = 200
    
    public static func setupSentry(dsn: String) {
        // Create a Sentry client and start crash handler
        do {
            Client.shared = try Client(dsn: dsn)
            try Client.shared?.startCrashHandler()
            
            Client.shared?.beforeSerializeEvent = { event in
                guard let debugMeta = event.debugMeta else { return }
                event.debugMeta = Array(debugMeta.prefix(50)) // prevents hitting 16KB cap on Sentry gzip requests
            }
        } catch let error {
            printToConsole("\(error)")
            // Wrong DSN or KSCrash not installed
        }
    }
    
    public static func logFile() -> URL? {
        do {
            _ = try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: false, attributes: nil)
        } catch {}
        
        let file = logsDirectory.appendingPathComponent("ProtonVPN.log", isDirectory: false)
        
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
    
    public static func D(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        let log = "\(Date()) : \(level.description) : \((file as NSString).lastPathComponent) : \(function) : \(line) : \(column) - \(message)"
        printToConsole(log)
        
        guard let logPath = logFile() else { return }
        
        pruneLogs()
        
        do {
            let fileHandle = try FileHandle(forWritingTo: logPath)
            fileHandle.seekToEndOfFile()
            fileHandle.write("\(log)\n".data(using: .utf8)!)
            fileHandle.closeFile()
        } catch {
            do {
                try "\(log)\n".data(using: .utf8)?.write(to: logPath)
            } catch {
                printToConsole(error.localizedDescription)
            }
        }
    }
    
    public static func ET(_ message: String, level: LogLevel = .error, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        PMLog.D(message, level: .error, file: file, function: function, line: line, column: column)
        
        // Send to Sentry along with stacktrace
        Client.shared?.snapshotStacktrace {
            let event = Event(level: level.sentryLevel)
            event.message = message
            Client.shared?.appendStacktrace(to: event)
            Client.shared?.send(event: event)
        }
    }
    
    public static func ET(_ error: Error, level: LogLevel = .error, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        ET(error.localizedDescription, level: level)
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
        print(text)
        #endif
    }
    // swiftlint:enable no_print
}
