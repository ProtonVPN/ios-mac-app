//
//  Created on 2021-11-22.
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
import Logging

public protocol FileLogHandlerDelegate: class {
    func didCreateNewLogFile()
    func didRotateLogFile()
}

// swiftlint:disable no_print
public class FileLogHandler: LogHandler {
    
    /// After log file size reaches 50kb in size it is moved to archive and new log file is created
    public var maxFileSize = 1024 * 50
    
    /// Maximum number of log files that were rotated. This number doesn't include the main log file where app is writing it's logs.
    public var maxArchivedFilesCount = 1
    
    public let formatter: PMLogFormatter
    public var logLevel: Logging.Logger.Level = .trace
    public var metadata = Logging.Logger.Metadata()
    
    public weak var delegate: FileLogHandlerDelegate?
    
    private let fileUrl: URL
    private var fileHandle: FileHandle?
    private var currentSize: UInt64 = 0
    private var fileManager: FileManager = FileManager.default
    
    private var logsDirectory: URL {
        return fileUrl.deletingLastPathComponent()
    }
    
    private var queue: DispatchQueue = DispatchQueue.init(label: "FileLogHandler", qos: .background)
    
    public init(_ fileUrl: URL, formatter: PMLogFormatter = FileLogFormatter()) {
        self.fileUrl = fileUrl
        self.formatter = formatter
    }
    
    deinit {
        closeFile()
    }
    
    public func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) { // swiftlint:disable:this function_parameter_count
        let text = formatter.formatMessage(level, message: message.description, function: function, file: file, line: line, metadata: convert(metadata: metadata), date: Date())
             
        queue.async {
            if let data = (text + "\r\n").data(using: .utf8) {
                do {
                    try self.getFileHandleAtTheEndOfFile()?.writeCustom(contentsOf: data)
                } catch {
                    self.debugLog("🔴🔴 Error writing to file: \(error)")
                }
            }
            
            self.rotate()
        }
    }
    
    // MARK: - File
    
    private func openFile() throws {
        closeFile()
        try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        if !fileManager.fileExists(atPath: fileUrl.path) {
            fileManager.createFile(atPath: fileUrl.path, contents: nil, attributes: nil)
            #if !os(OSX)
            try (fileUrl as NSURL).setResourceValue( URLFileProtection.complete, forKey: .fileProtectionKey)
            #endif
            delegate?.didCreateNewLogFile()
        }

        fileHandle = try FileHandle(forWritingTo: fileUrl)
    }
    
    private func closeFile() {
        guard let fileHandle = fileHandle else {
            return
        }
        try? fileHandle.synchronizeCustom()
        try? fileHandle.closeCustom()
        
        self.fileHandle = nil
    }
    
    private func getFileHandleAtTheEndOfFile() -> FileHandle? {
        if fileHandle == nil {
            do {
                try openFile()
            } catch {
                return nil
            }
        }
        do {
            currentSize = try fileHandle?.seekToEndCustom() ?? 0
        } catch {
            currentSize = 0
        }
        return fileHandle
    }
    
    private func rotate() {
        if currentSize < 1 {
            do {
                currentSize = try fileHandle?.seekToEndCustom() ?? 0
            } catch {
                currentSize = 0
            }
        }
        guard currentSize > maxFileSize else {
            return
        }
        closeFile()
        moveToNextFile()
        removeOldFiles()
        // File will be reopened next time write operation is needed
        
        delegate?.didRotateLogFile()
    }
        
    private func moveToNextFile() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYMMddHHmmssSSS"
        let nextFileURL = fileUrl.deletingPathExtension().appendingPathExtension(dateFormatter.string(from: Date()) + "_\(UUID().uuidString).log")

        do {
            try fileManager.moveItem(at: fileUrl, to: nextFileURL)
            debugLog("🟢🟢 File rotated \(nextFileURL.lastPathComponent)")
        } catch {
            debugLog("🔴🔴 Error while moving file: \(error)")
        }
    }
    
    private func removeOldFiles() {
        let filenameWithoutExtension = fileUrl.deletingPathExtension().pathComponents.last ?? "ProtonVPN"
        do {
            let oldFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .filter { $0.pathComponents.last?.hasMatches(for: "\(filenameWithoutExtension).\\d+(_[\\d\\w\\-]+)?.log") ?? false }
            guard oldFiles.count > maxArchivedFilesCount else {
                return
            }
            
            let sortedFiles = try oldFiles.sorted {
                let date1 = try self.fileManager.attributesOfItem(atPath: $0.path)[.creationDate] as? Date
                let date2 = try self.fileManager.attributesOfItem(atPath: $1.path)[.creationDate] as? Date
                return date1!.timeIntervalSince1970 < date2!.timeIntervalSince1970
            }
            
            for i in 0 ..< sortedFiles.count - maxArchivedFilesCount {
                try fileManager.removeItem(at: sortedFiles[i])
            }
        
        } catch {
            debugLog("🔴🔴 Error while removing old logfiles: \(error)")
        }
    }
    
    // MARK: - Metadata
    
    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            return metadata[key]
        }
        set(newValue) {
            metadata[key] = newValue
        }
    }
    
    // MARK: - Debugging
    
    public func debugLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
    
}
// swiftlint:enable no_print
