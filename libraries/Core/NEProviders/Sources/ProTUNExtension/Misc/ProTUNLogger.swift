//
//  Created on 20/05/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import OSLog
import protun

final class ProTUNLogger: ClientLogger {
    func log(level: LogLevel, message: String) {
        switch level {
        case .trace:
            Logger.library.trace("\(message, privacy: .public)")
        case .debug:
            Logger.library.debug("\(message, privacy: .public)")
        case .info:
            Logger.library.info("\(message, privacy: .public)")
        case .warn:
            Logger.library.warning("\(message, privacy: .public)")
        case .error:
            Logger.library.error("\(message, privacy: .public)")
        @unknown default:
            Logger.library.info("\(message, privacy: .public)")
        }
    }
}
