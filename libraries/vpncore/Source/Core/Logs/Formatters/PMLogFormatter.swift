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

public protocol PMLogFormatter {
    func formatMessage(_ level: Logging.Logger.Level, message: String, function: String, file: String, line: UInt, metadata: [String: String], date: Date) -> String // swiftlint:disable:this function_parameter_count
}

// `Logging.` has to be prepended in some cases because this file is also included in WireGuard extension, which has its own `Logger` class.
extension PMLogFormatter {
    /// Extract category and  event from metada. Return metadata without extracted elements.
    func extract(metadata: [String: String]) -> (String, String, String) { // swiftlint:disable:this large_tuple
        let category = metadata[Logging.Logger.MetaKey.category.rawValue] != nil ? " [\(metadata[Logging.Logger.MetaKey.category.rawValue]!)]" : ""
        let event = metadata[Logging.Logger.MetaKey.event.rawValue] != nil ? " [\(metadata[Logging.Logger.MetaKey.event.rawValue]!)]" : ""
        
        let keysToRemove = [Logging.Logger.MetaKey.category.rawValue, Logging.Logger.MetaKey.event.rawValue]
        let metaClean = metadata.filter { key, value in !keysToRemove.contains(key) }
        
        let metaString = !metaClean.isEmpty ? " \(metaClean)" : ""
        return (category, event, metaString)
    }
}
