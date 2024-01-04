//
//  Copyright (c) 2021 Proton AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Logging

public class ConsoleLogFormatter: FileLogFormatter {
    
    override public init() {
        super.init()
        dateFormatter.timeZone = TimeZone.current
    }
        
    override public func formatMessage(_ level: Logging.Logger.Level, message: String, function: String, file: String, line: UInt, metadata: [String: String], date: Date) -> String {
        let message = super.formatMessage(level, message: message, function: function, file: file, line: line, metadata: metadata, date: date)
        return "\(level.emoji) \(message)"
    }
    
}
