//
//  Logger+Callers.swift
//  Core
//
//  Created by Jaroslav on 2021-11-12.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Logging

// Only levels that we actually use are added here
extension Logger {
    
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      category: PVPNLogHelper.Category,
                      event: PVPNLogHelper.Event? = nil,
                      metadata: @autoclosure @escaping () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        
        self.log(level: .debug, message(), metadata: getMeta(metadata, category: category, event: event)(), source: source(), file: file, function: function, line: line)
    }
    
    public func info(_ message: @autoclosure () -> Logger.Message,
                     category: PVPNLogHelper.Category,
                     event: PVPNLogHelper.Event? = nil,
                     metadata: @autoclosure @escaping () -> Logger.Metadata? = nil,
                     source: @autoclosure () -> String? = nil,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        
        self.log(level: .info, message(), metadata: getMeta(metadata, category: category, event: event)(), source: source(), file: file, function: function, line: line)
    }
    
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        category: PVPNLogHelper.Category,
                        event: PVPNLogHelper.Event? = nil,
                        metadata: @autoclosure @escaping () -> Logger.Metadata? = nil,
                        source: @autoclosure () -> String? = nil,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        
        self.log(level: .warning, message(), metadata: getMeta(metadata, category: category, event: event)(), source: source(), file: file, function: function, line: line)
    }
    
    public func error(_ message: @autoclosure () -> Logger.Message,
                      category: PVPNLogHelper.Category,
                      event: PVPNLogHelper.Event? = nil,
                      metadata: @autoclosure @escaping () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        
        self.log(level: .error, message(), metadata: getMeta(metadata, category: category, event: event)(), source: source(), file: file, function: function, line: line)
    }
    
    /// Add our own category and event into metada data
    private func getMeta(_ originalMetadata: @escaping () -> Logger.Metadata?, category: PVPNLogHelper.Category, event: PVPNLogHelper.Event? = nil) -> (() -> Logger.Metadata?) {
        return {
            var res: Logger.Metadata = originalMetadata() ?? Logger.Metadata()
            res[PVPNLogHelper.MetaKey.category.rawValue] = .string(category.rawValue)
            if let event = event {
                res[PVPNLogHelper.MetaKey.event.rawValue] = .string(event.rawValue)
            }
            return res
        }
    }
    
}
