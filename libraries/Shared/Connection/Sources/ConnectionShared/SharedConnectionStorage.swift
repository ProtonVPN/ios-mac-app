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

import SharedErgonomics

public enum SharedConnectionStorage {
    static let lastDisconnectErrorKey: String = "LastDisconnectError"

    public static var lastDisconnectError: String? {
        get {
            @Dependency(\.defaultsProvider) var provider
            return provider.getDefaults().string(forKey: lastDisconnectErrorKey)
        }
        set {
            @Dependency(\.defaultsProvider) var provider
            provider.getDefaults().set(newValue, forKey: lastDisconnectErrorKey)
        }
    }
}
