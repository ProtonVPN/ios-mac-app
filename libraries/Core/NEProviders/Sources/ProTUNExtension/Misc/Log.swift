//
//  Created on 07/01/2026 by adam.
//
//  Copyright (c) 2026 Proton AG
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

import Domain
import Ergonomics
import OSLog

enum LoggingMode {
    case singleOutputFile
    case perSession
}

extension Logger {
    static let provider = Logger(subsystem: Subsystem.protun.rawValue, category: Category.provider.rawValue)
    static let adapter = Logger(subsystem: Subsystem.protun.rawValue, category: Category.adapter.rawValue)
    static let localAgent = Logger(subsystem: Subsystem.protun.rawValue, category: Category.localAgent.rawValue)
    static let library = Logger(subsystem: Subsystem.protun.rawValue, category: Category.library.rawValue)
}

private enum LogFilter: Sendable {
    case subsystem(Subsystem)
    case category(Category)
    indirect case or(LogFilter, LogFilter)
    indirect case and(LogFilter, LogFilter)
}

private enum Subsystem: String, CaseIterable {
    #if os(macOS)
        case protun = "ch.protonvpn.mac.ProTUN-Extension"
    #elseif os(iOS) || os(tvOS)
        case protun = "ch.protonmail.vpn.ProTUN-Extension"
    #endif
    case networkExtension = "com.apple.networkextension"
    #if os(macOS)
        case systemConfiguration = "com.apple.SystemConfiguration"
        case coreAnalytics = "com.apple.CoreAnalytics"
        case symptomsd = "com.apple.symptomsd"
    #endif
}

private enum Category: String, CaseIterable {
    case provider = "Provider"
    case adapter = "Adapter"
    case localAgent = "LocalAgent"
    case library = "Library"
}

extension Logger {
    enum LogsError: Swift.Error {
        case noContainerFound
        case noLogsFound
        case serializationFailure
    }

    private static func fetch(sinceDate: Date, predicateFormat: String? = nil) throws -> [OSLogEntryLog] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)

        let predicateFormat = predicateFormat ?? LogFilter.default.predicateFormat
        let predicate = NSPredicate(format: predicateFormat)
        let entries = try retrieveRelevantEntries(from: store, since: sinceDate, predicate: predicate)

        guard !entries.isEmpty else {
            throw LogsError.noLogsFound
        }

        try Task.checkCancellation()

        return entries
    }

    private static func retrieveRelevantEntries(
        from store: OSLogStore,
        since startDate: Date,
        predicate: NSPredicate
    ) throws -> [OSLogEntryLog] {
        let position = store.position(date: startDate)
        return try store
            .getEntries(at: position, matching: predicate)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.date > startDate }
    }

    private static func serialize(_ entries: [OSLogEntryLog]) throws -> Data {
        let text = entries.reduce(into: "") { $0 += $1.content + "\n" }
        guard let data = text.data(using: .utf8) else {
            throw LogsError.serializationFailure
        }
        return data
    }
}

extension Logger {
    private static let logsFilename = "ProTUN-Logs.log"
    private static let containerURL: URL? = try? FileManager.default.mainContainerURL

    // Flushing to a file & using the file's metadata as our lastFlushDate
    // so that each flush only appends the newest entries from the OSLogStore.
    @discardableResult
    static func flushToFile(filename: String? = nil) throws -> URL {
        guard let containerURL else {
            throw LogsError.noContainerFound
        }

        let dstURL = containerURL.appending(path: filename ?? Self.logsFilename)
        let lastFlushDate = dstURL.contentModificationDate
        let sinceDate = lastFlushDate ?? AppStartup.processStartDate ?? .distantPast

        do {
            let entries = try fetch(sinceDate: sinceDate)
            let data = try serialize(entries)

            if let handle = try? FileHandle(forWritingTo: dstURL) {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: dstURL, options: .atomic)
            }
            // The write above already stamped the mtime with the wall clock, which is later than the newest entry we
            // wrote: refine it so the next flush doesn't skip entries logged while we were fetching and writing.
            // Best effort on purpose, the data is already on disk and the unrefined mtime only costs us that sliver.
            let watermark = entries.last?.date ?? sinceDate
            try? FileManager.default.setAttributes([.modificationDate: watermark], ofItemAtPath: dstURL.path())
            return dstURL
        } catch LogsError.noLogsFound where FileManager.default.fileExists(atPath: dstURL.path()) {
            return dstURL // no new entries since last flush
        }
    }

    static func flushSession() throws {
        try flushToFile(filename: "ProTUN-Logs-Session-\(Date.now.timeIntervalSince1970)")
    }

    static func retrieveSessionArchive(fileManager: FileManager = .default) throws -> URL {
        guard let containerURL else {
            throw LogsError.serializationFailure
        }
        let archiveFolderURL = fileManager.temporaryDirectory.appending(path: "ProTUN-Archive")
        try fileManager.createDirectory(at: archiveFolderURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: archiveFolderURL)
        }
        let files = try fileManager
            .contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { $0.lastPathComponent.hasPrefix("ProTUN-Logs-Session-") }
        guard !files.isEmpty else {
            throw LogsError.noLogsFound
        }
        for fileURL in files {
            try fileManager.copyItem(at: fileURL, to: archiveFolderURL.appending(component: fileURL.lastPathComponent))
        }
        let outputArchiveURL = containerURL.appending(component: "ProTUN-Archive.zip")
        if fileManager.fileExists(atPath: outputArchiveURL.path()) {
            try fileManager.removeItem(at: outputArchiveURL)
        }
        try createZip(fromDirectory: archiveFolderURL, to: outputArchiveURL)
        return outputArchiveURL
    }

    private static func createZip(fromDirectory directoryURL: URL, to finalURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var moveError: (any Swift.Error)?

        coordinator.coordinate(
            readingItemAt: directoryURL,
            options: .forUploading,
            error: &coordinationError
        ) { tempZipURL in
            do {
                try? FileManager.default.removeItem(at: finalURL)
                try FileManager.default.moveItem(at: tempZipURL, to: finalURL)
            } catch {
                moveError = error
            }
        }

        if let error = coordinationError {
            throw error
        }
        if let error = moveError {
            throw error
        }
    }
}

private extension LogFilter {
    static let `default`: [Self] = [
        .or(
            .subsystem(.protun),
            .subsystem(.networkExtension)
        ),
    ]
}

private extension Collection<LogFilter> {
    var predicateFormat: String {
        reduce("") { $0 + $1.predicateFormat }
    }
}

private extension LogFilter {
    var predicateFormat: String {
        switch self {
        case let .subsystem(subsystem):
            "subsystem == '\(subsystem.rawValue)'"
        case let .category(category):
            "category == '\(category.rawValue)'"
        case let .or(lhs, rhs):
            "(\(lhs.predicateFormat)) || (\(rhs.predicateFormat))"
        case let .and(lhs, rhs):
            "(\(lhs.predicateFormat)) && (\(rhs.predicateFormat))"
        }
    }
}

private extension OSLogEntryLog {
    private nonisolated(unsafe) static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    var content: String {
        let dateString = Self.formatter.string(from: date)
        return """
        \(dateString) | \(subsystem) | \(category.isEmpty ? "_" : category) | \(level.descriptionUppercased) | \(composedMessage)
        """
    }
}

private extension OSLogEntryLog.Level {
    var description: String {
        switch self {
        case .undefined: "undefined"
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        @unknown default: "default"
        }
    }

    var descriptionUppercased: String {
        switch self {
        case .undefined: "UNDEFINED"
        case .debug: "DEBUG"
        case .info: "INFO"
        case .notice: "NOTICE"
        case .error: "ERROR"
        case .fault: "FAULT"
        @unknown default: "DEFAULT"
        }
    }
}

private extension URL {
    var contentModificationDate: Date? {
        try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
