//
//  Created on 2022-02-15.
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

/// Default implementation that lists all possible log files
public class DefaultLogFilesProvider: LogFilesProvider {
    public var logFiles: [(String, URL?)]

    public init(vpnManager: VpnManagerProtocol, logFileManager: LogFileManager, appLogFilename: String) {
        logFiles = [
            (LocalizedString.applicationLogs, logFileManager.getFileUrl(named: appLogFilename)), // Application logs
            (LocalizedString.applicationLogs, vpnManager.logFile(for: .ike)), // Empty for apple's ikev2 implementation
            (LocalizedString.openVpnLogs, vpnManager.logFile(for: .openVpn(.undefined))),
            (LocalizedString.wireguardLogs, vpnManager.logFile(for: .wireGuard))
        ]
    }
}
