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

extension Logging.Logger.Level {
    public var emoji: String {
        switch self {
        case .trace:
            return "⚪"
        case .debug:
            return "🟢"
        case .info:
            return "🔵"
        case .notice:
            return "🟠"
        case .warning:
            return "🟡"
        case .error:
            return "🔴"
        case .critical:
            return "💥"
        }
    }

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
