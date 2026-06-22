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
import NetworkExtension
import os
import ProTUNExtension

private let tunnelDataXPCLog = Logger(subsystem: "ch.protonvpn.mac.protun", category: "TunnelDataXPC")

/// The extension's own Mach service, declared as `NEMachServiceName` in Info.plist. Used for establishing the
/// ``RawChannel``s between the extension and the application.
private func machServiceName() -> String {
    guard let networkExtension = Bundle.main.object(forInfoDictionaryKey: "NetworkExtension") as? [String: Any],
          let name = networkExtension["NEMachServiceName"] as? String else {
        fatalError("NEMachServiceName is missing from the Info.plist")
    }
    return name
}

let tunnelDataXPCService = TunnelDataXPCService(
    machServiceName: machServiceName(),
    log: { tunnelDataXPCLog.log("\($0, privacy: .public)") }
)

autoreleasepool {
    NEProvider.startSystemExtensionMode()
    tunnelDataXPCService.startListener()
}

dispatchMain()
