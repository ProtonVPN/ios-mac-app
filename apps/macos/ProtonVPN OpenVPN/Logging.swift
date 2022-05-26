//
//  Created on 2022-05-26.
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
import SwiftyBeaver
import os.log

struct LogSettings {

    // Name for OSLog subsystem. Should start with `PROTON-` for easier debugging.
    static let osLogSubsystem = "PROTON-OVPN"

    // Settings for oslog
    static let osLog = OSLog(subsystem: osLogSubsystem, category: "OpenVPN")

    // Can be deleted after we stop supporting macOS 10.15
    static let logFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent("OpenVPN.log")
}

class OSLogDestination: BaseDestination {

    override public var defaultHashValue: Int { return 10 }

    public override init() {
        super.init()
    }

    override open func send(_ level: SwiftyBeaver.Level, msg: String, thread: String,
                                file: String, function: String, line: Int, context: Any? = nil) -> String? {
        let formattedString = super.send(level, msg: msg, thread: thread, file: file, function: function, line: line, context: context)

        if let str = formattedString {
            os_log("%{public}s", log: LogSettings.osLog, type: level.osLogType, str)
        }
        return formattedString
    }

}

extension SwiftyBeaver.Level {
    public var osLogType: OSLogType {
        switch self {
        case .verbose:
            return OSLogType.debug
        case .debug:
            return OSLogType.debug
        case .info:
            return OSLogType.info
        case .warning:
            return OSLogType.error
        case .error:
            return OSLogType.error
        }
    }
}
