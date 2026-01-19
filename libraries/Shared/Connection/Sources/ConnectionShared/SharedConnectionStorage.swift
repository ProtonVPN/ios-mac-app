//
//  Created on 13/01/2026 by Chris Janusiewicz.
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

import Dependencies

// If we want to keep things really light-weight in the network extension,
// we can extract the defaults provider to a smaller, e.g. `SharedErgonomics` library.
import SharedErgonomics

public enum SharedConnectionStorage {
    private enum StorageKeys: String {
        case lastDisconnectError = "LastDisconnectError"
    }

    public static var lastDisconnectError: String? {
        get {
            @Dependency(\.defaultsProvider) var provider
            return provider.getDefaults().string(forKey: StorageKeys.lastDisconnectError.rawValue)
        }
        set {
            @Dependency(\.defaultsProvider) var provider
            provider.getDefaults().set(newValue, forKey: StorageKeys.lastDisconnectError.rawValue)
        }
    }
}
