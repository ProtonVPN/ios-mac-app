//
//  Logger.swift
//  ProtonMail
//
//  Created by Yanfeng Zhang on 5/4/15.
//  Copyright (c) 2015 ArcTouch. All rights reserved.
//
import Foundation
import Sentry

public class PMLog {
    
    public static let logsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs", isDirectory: true)
    
    #if os(OSX)
        private static let daysToKeep = 10
    #else
        private static let daysToKeep = 1 // only keep the latest day's worth of logs for simplicity and storage
    #endif
    
    public static func logFile() -> URL? {
        do {
            let _ = try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: false, attributes: nil)
        } catch {}
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: Date())
        return logsDirectory.appendingPathComponent("\(date).log", isDirectory: false)
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
    
    public static func D(_ message: String, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        let log = "\(Date()) : \((file as NSString).lastPathComponent) : \(function) : \(line) : \(column) - \(message)"
        print(log)
        
        guard let logPath = logFile() else { return }
        
        removeOldLogs()
        
        do {
            let fileHandle = try FileHandle(forWritingTo: logPath)
            fileHandle.seekToEndOfFile()
            fileHandle.write("\(log)\n".data(using: .utf8)!)
            fileHandle.closeFile()
        } catch {
            do {
                try "\(log)\n".data(using: .utf8)?.write(to: logPath)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    public static func ET(_ message: String, file: String = #file, function: String = #function, line: Int = #line, column: Int = #column) {
        PMLog.D(message, file: file, function: function, line: line, column: column)
        
        // Send to Sentry along with stacktrace
        Client.shared?.snapshotStacktrace {
            let event = Event(level: .error)
            event.message = message
            Client.shared?.appendStacktrace(to: event)
            Client.shared?.send(event: event)
        }
    }
    
    private static func removeOldLogs() {
        do {
            let logsUrls = try FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let logs = logsUrls
                .filter { $0.absoluteString.hasSuffix(".log") }
                .sorted { $0.absoluteString > $1.absoluteString }
            
            try logs.enumerated().forEach {
                let (index, url) = $0
                
                if index >= daysToKeep {
                    try FileManager.default.removeItem(at: url)
                }
            }
        } catch let e { print(e) }
    }
}
