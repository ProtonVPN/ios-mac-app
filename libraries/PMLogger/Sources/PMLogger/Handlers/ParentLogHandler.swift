//
//  Created on 2023-01-26.
//
//  Copyright (c) 2023 Proton AG
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

/// Parent class for all our log formatters. Should not be used as-is but rather as a parent class for other handlers.
open class ParentLogHandler: LogHandler {

    public var formatter: PMLogFormatter
    public var logLevel = Logging.Logger.Level.trace
    public var metadata = Logging.Logger.Metadata()

    public init(formatter: PMLogFormatter, logLevel: Logger.Level = Logging.Logger.Level.trace, metadata: Logger.Metadata = Logging.Logger.Metadata()) {
        self.formatter = formatter
        self.logLevel = logLevel
        self.metadata = metadata
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            return metadata[key]
        }
        set(newValue) {
            metadata[key] = newValue
        }
    }

}
