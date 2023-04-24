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
///
/// - Important: The documentation states that LogHandler implementations must be structs (VPNAPPL-1753).
/// If something strange is going on, check that it's not because this, and concrete log handlers, are classes.
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

    open func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) { // swiftlint:disable:this function_parameter_count
        // Without this method, instead of a proper method of subclasses, method with the same signature
        // on LogHandler extension is called. Which leads to infinite loop.
        // Some info can be found here: https://github.com/apple/swift-log/issues/248
        fatalError("Please override this method")
    }

}
