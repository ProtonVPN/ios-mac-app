//
//  Created on 18/08/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation
import PlutoniumExtension
import VPNShared

class IPCPlutoniumService: XPCBaseService {
    override public init(withExtension machServiceName: String, logger: @escaping (String) -> Void) {
        super.init(withExtension: machServiceName, logger: logger)
    }
}

// MARK: - ProviderCommunication Overrides

extension IPCPlutoniumService {
    override public func getLogs(_ completionHandler: @escaping (Data?) -> Void) {
        log("Got getLogs XPC request for Plutonium")
        do {
            let logFile = try getPlutoniumLogFileURL(createIfMissing: false)
            let logContent = try String(contentsOf: logFile)
            completionHandler(logContent.data(using: .utf8))
        } catch {
            log("Error reading Plutonium logs: \(error)")
            completionHandler(nil)
        }
    }
}
