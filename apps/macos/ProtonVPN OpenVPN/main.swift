//
//  main.swift
//  ProtonVPN - Created on 04/12/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import NetworkExtension
import SwiftyBeaver
import os.log

let ipc = IPCOvpnService(withExtension: IPCHelper.extensionMachServiceName(from: Bundle.main), logger: {
    if #available(macOS 12, *) {
        // On older systems logging to os_log will be performed through SwiftyBeaver
        os_log("%{public}s", log: OSLog(subsystem: "PROTON-OVPN", category: "OpenVPN"), type: .default, $0)

    } else { // We can't extract logs from OSLog on macos 11
        SwiftyBeaver.self.debug($0, context: nil)
    }
})

autoreleasepool {
    // Setup logging for NE
    SwiftyBeaver.self.addDestination(OSLogDestination())

    // We can't extract logs from OSLog on macos 11, so we have to save them to file
    if #unavailable(macOS 12) {
        SwiftyBeaver.self.addDestination(FileDestination(logFileURL: LogSettings.logFileUrl))
    }
    
    NEProvider.startSystemExtensionMode()
    ipc.startListener()
}

dispatchMain()
