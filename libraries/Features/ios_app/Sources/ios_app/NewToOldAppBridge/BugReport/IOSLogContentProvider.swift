//
//  Created on 10/11/2025 by Max Kupetskyi.
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

import Connection
import Dependencies
import Domain
import Foundation
import PMLogger

extension LogContentProvider: @retroactive DependencyKey {
    public static var liveValue: LogContentProvider = IOSLogContentProvider
}

extension LogContentProvider {
    /// Create and return a proper LogData implementation for a given log source
    static let IOSLogContentProvider: LogContentProvider = .init(getLogData: { source in
        switch source {
        case .app:
            @Dependency(\.logFileManager) var logFileManager
            let folder: URL = logFileManager
                .getFileUrl(named: appLogFilename)
                .deletingLastPathComponent()
            return AppLogContent(folder: folder)

        case .osLog:
            return OSLogContent()

        case .wireguard:
            let appGroup: String = DomainConstants.AppGroups.main
            @Dependency(\.wireguardIOSLogProvider) var wireguardIOSLogProvider
            return wireguardIOSLogProvider.logContentForAppGroup(appGroup)
        }
    })
}

let appLogFilename = "ProtonVPN.log"
