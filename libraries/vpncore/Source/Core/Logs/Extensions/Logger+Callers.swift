//
//  Copyright (c) 2021 Proton AG
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

import Logging

// Only levels that we actually use are added here
extension Logging.Logger {
    
    public func debug(_ message: @autoclosure () -> Message,
                      category: Logger.Category? = nil,
                      event: Logger.Event? = nil,
                      metadata: @autoclosure @escaping () -> Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        
        self.log(level: .debug, message(), metadata: getMeta(metadata, category: category, event: event)(), source: source(), file: file, function: function, line: line)
    }
    
    public func info(_ message: @autoclosure () -> Message,
                     category: Logger.Category? = nil,
                     event: Logger.Event? = nil,
                     metadata: @autoclosure @escaping () -> Metadata? = nil,
                     source: @autoclosure () -> String? = nil,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        
        self.log(level: .info, message(), metadata: getMeta(metadata, category: category, event: event)(), source: source(), file: file, function: function, line: line)
    }
    
    public func warning(_ message: @autoclosure () -> Message,
                        category: Logger.Category? = nil,
                        event: Logger.Event? = nil,
                        metadata: @autoclosure @escaping () -> Metadata? = nil,
                        source: @autoclosure () -> String? = nil,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        
        self.log(level: .warning, message(), metadata: getMeta(metadata, category: category, event: event)(), source: source(), file: file, function: function, line: line)
    }
    
    public func error(_ message: @autoclosure () -> Message,
                      category: Logger.Category? = nil,
                      event: Logger.Event? = nil,
                      metadata: @autoclosure @escaping () -> Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        
        self.log(level: .error, message(), metadata: getMeta(metadata, category: category, event: event)(), source: source(), file: file, function: function, line: line)
    }
    
    /// Metadata predefined keys
    public enum MetaKey: String {
        case category
        case event
    }
    
    /// Add our own category and event into metada data
    private func getMeta(_ originalMetadata: @escaping () -> Metadata?, category: Logger.Category? = nil, event: Logger.Event? = nil) -> (() -> Metadata?) {
        return {
            var res: Metadata = originalMetadata() ?? Metadata()
            if let category = category {
                res[MetaKey.category.rawValue] = .string(category.rawValue)
            }
            if let event = event {
                res[MetaKey.event.rawValue] = .string(event.rawValue)
            }
            return res
        }
    }
    
}
