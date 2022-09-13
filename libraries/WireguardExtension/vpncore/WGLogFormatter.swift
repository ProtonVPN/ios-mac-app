//
//  Created on 2022-02-24.
//
//  Copyright (c) 2022 Proton AG
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

class WGLogFormatter: PMLogFormatter {

    private let jsonEncoder = JSONEncoder()

    public init() {
    }

    public func formatMessage(_ level: Logging.Logger.Level, message: String, function: String, file: String, line: UInt, metadata: [String: String], date: Date) -> String {// swiftlint:disable:this function_parameter_count
        let (category, event, meta) = extract(metadata: metadata)
        var metaString = ""
        if !meta.isEmpty, let metaJsonData = try? jsonEncoder.encode(meta) {
            metaString = String(data: metaJsonData, encoding: .utf8) ?? ""
        }
        return "\(level.stringValue) | \(category.uppercased())\(event.uppercased()) | \(message) | \(metaString)"
    }

}

extension Logging.Logger.Level {
    var stringValue: String {
        switch self {
        case .trace:
            return "TRACE"
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO "
        case .notice:
            return "NOTIC"
        case .warning:
            return "WARN "
        case .error:
            return "ERROR"
        case .critical:
            return "FATAL"
        }
    }
}
