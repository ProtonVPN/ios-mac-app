//
//  Created on 27/08/2026 by adam.
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

import Dependencies
import Foundation
import VPNShared

/// The FIDO portal the user is sent to when Local Agent jails the connection until they authenticate.
public enum FidoPortalLink {
    /// The portal address, prefilled with the logged in user's account name so they don't have to type it again.
    public static var urlString: String {
        @Dependency(\.authKeychain) var authKeychain
        let username = authKeychain.usernameCachedOrFetched
        guard var components = URLComponents(string: ObfuscatedConstants.fidoPortal), let username else {
            return ObfuscatedConstants.fidoPortal
        }
        components.queryItems = (components.queryItems ?? []) + [.init(name: "email", value: username)]
        return components.string ?? ObfuscatedConstants.fidoPortal
    }
}
