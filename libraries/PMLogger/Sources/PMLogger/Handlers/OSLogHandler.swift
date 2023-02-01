//
//  Created on 2022-04-21.
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
import os.log

public final class OSLogHandler: ParentLogHandler {

    override public func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let text = formatter.formatMessage(level, message: message.description, function: function, file: file, line: line, metadata: convert(metadata: metadata), date: Date())
        os_log("%{public}s", log: OSLog(subsystem: "PROTON-APP", category: "\(metadata?[Logging.Logger.MetaKey.category.rawValue] ?? "")"), type: level.osLogType, text)
    }

}

extension Logging.Logger.Level {
    public var osLogType: OSLogType {
        switch self {
        case .trace:
            return OSLogType.default
        case .debug:
            return OSLogType.debug
        case .info:
            return OSLogType.info
        case .notice:
            return OSLogType.info
        case .warning:
            return OSLogType.error
        case .error:
            return OSLogType.error
        case .critical:
            return OSLogType.fault
        }
    }
}
