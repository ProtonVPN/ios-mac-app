//
//  Created on 2022-05-04.
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
import Logging

extension PacketTunnelProvider {
    func setupLogging() {
        let log = SwiftyBeaver.self
        log.addDestination(OSLogDestination())

        // Our logger
        LoggingSystem.bootstrap { _ in
            return OVPNLogHandler(formatter: OVPNLogFormatter())
        }
    }

}

class OSLogDestination: BaseDestination {

    private let osLogSettings = OSLog(subsystem: "PROTON-OVPN", category: "OpenVPN")
    override public var defaultHashValue: Int { return 10 }

    override public init() {
        super.init()
    }

    override open func send(_ level: SwiftyBeaver.Level, msg: String, thread: String,
                            file: String, function: String, line: Int, context: Any? = nil) -> String? {
        let formattedString = super.send(level, msg: msg, thread: thread, file: file, function: function, line: line, context: context)

        if let str = formattedString {
            os_log("%{public}s", log: osLogSettings, type: level.osLogType, str)
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
