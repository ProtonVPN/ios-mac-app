//
//  ConsoleLogFormatter.swift
//  Core
//
//  Created by Jaroslav on 2021-11-12.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Logging

public class ConsoleLogFormatter: PMLogFormatter {
    
    private let dateFormatter = ISO8601DateFormatter()

    public init() {
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    public func formatMessage(_ level: Logging.Logger.Level, message: String, function: String, file: String, line: UInt, metadata: [String: String], date: Date) -> String {// swiftlint:disable:this function_parameter_count
        let dateTime = dateFormatter.string(from: date)
        let (category, event, meta) = extract(metadata: metadata)
        return "\(level.emoji) \(dateTime) \(level)\(category)\(event) \(message)\(meta)"
    }
    
    /// Extract category and  event from metada. Return metadata without extracted elements.
    private func extract(metadata: [String: String]) -> (String, String, String) { // swiftlint:disable:this large_tuple
        let category = metadata[PVPNLogHelper.MetaKey.category.rawValue] != nil ? " [\(metadata[PVPNLogHelper.MetaKey.category.rawValue]!)]" : ""
        let event = metadata[PVPNLogHelper.MetaKey.event.rawValue] != nil ? " [\(metadata[PVPNLogHelper.MetaKey.event.rawValue]!)]" : ""
        
        let keysToRemove = [PVPNLogHelper.MetaKey.category.rawValue, PVPNLogHelper.MetaKey.event.rawValue]
        let metaClean = metadata.filter { key, value in !keysToRemove.contains(key) }
        
        let metaString = !metaClean.isEmpty ? " \(metaClean)" : ""
        return (category, event, metaString)
    }
}
