//
//  Created on 10/02/2026 by Max Kupetskyi.
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

import Foundation

public enum WireGuardLogPaths {
    private static let wireGuardTextLogFilename = "WireGuard.log"
    private static let wireGuardBinaryLogFilename = "WireGuard.bin"
    private static let wireGuardLastErrorFilename = "last-error.txt"

    public static func sharedContainerURL(appGroup: String) -> URL? {
        #if os(macOS)
            FileManager.default.temporaryDirectory
        #else
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        #endif
    }

    public static func logsDirectoryURL(appGroup: String) -> URL? {
        guard let root = sharedContainerURL(appGroup: appGroup) else { return nil }
        #if os(tvOS)
            // tvOS can restrict writes at app-group root; use a cache subfolder.
            return root
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Caches", isDirectory: true)
                .appendingPathComponent("Logs", isDirectory: true)
        #else
            return root
        #endif
    }

    public static func binaryLogURL(appGroup: String) -> URL? {
        logsDirectoryURL(appGroup: appGroup)?.appendingPathComponent(wireGuardBinaryLogFilename)
    }

    public static func textLogURL(appGroup: String) -> URL? {
        logsDirectoryURL(appGroup: appGroup)?.appendingPathComponent(wireGuardTextLogFilename)
    }

    public static func lastErrorURL(appGroup: String) -> URL? {
        sharedContainerURL(appGroup: appGroup)?.appendingPathComponent(wireGuardLastErrorFilename)
    }
}
