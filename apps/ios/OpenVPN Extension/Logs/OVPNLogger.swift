//
//  Created on 2023-01-09.
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
import PMLogger
import os.log
import SwiftyBeaver

let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.WG.logger")

/// Log handler that uses SwiftyBeaver library, which is baked into TrustKit and must be used in OpenVPN extension.
/// By forwaring log messages to SwiftyBeaver we can leverage already working infrastructure (saving logs to file,
/// sending this data back to the epp, etc.).
public struct OVPNLogHandler: LogHandler {
    public let formatter: PMLogFormatter
    public var logLevel: Logging.Logger.Level = .trace
    public var metadata = Logging.Logger.Metadata()
    private let osLogSettings = OSLog(subsystem: "PROTON-OVPN", category: "OpenVPN")

    public init(formatter: PMLogFormatter) {
        self.formatter = formatter
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            return metadata[key]
        }
        set(newValue) {
            metadata[key] = newValue
        }
    }

    public func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) { // swiftlint:disable:this function_parameter_count
        let text = formatter.formatMessage(level, message: message.description, function: function, file: file, line: line, metadata: convert(metadata: metadata), date: Date())
        let log = SwiftyBeaver.self
        log.custom(level: level.sbLevel, message: text)
    }

    private func convert(metadata: Logging.Logger.Metadata?) -> [String: String] {
        let fullMetadata = (metadata != nil) ? self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }) : self.metadata
        return fullMetadata.reduce(into: [String: String](), { result, element in
            result[element.key] = element.value.description
        })
    }
}

extension Logging.Logger.Level {
    var sbLevel: SwiftyBeaver.Level {
        switch self {
        case .trace:
            return .verbose
        case .debug:
            return .debug
        case .info:
            return .info
        case .notice:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        case .critical:
            return .error
        }
    }
}
