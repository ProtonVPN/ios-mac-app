//
//  Created on 02/07/2026 by Max Kupetskyi.
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

import Domain
import OrderedCollections
import Sharing

public extension SharedKey where Self == UserScopedAppStorageKey<OrderedSet<RecentConnection>?> {
    /// The user's recent connections
    static var recentConnections: Self {
        .json("RecentConnections", scope: .userId)
    }
}

public extension SharedKey where Self == UserScopedAppStorageKey<DefaultConnectionPreference?> {
    /// The user's *persisted* default-connection preference
    ///
    /// - Note: distinct from the in-memory `.defaultConnectionPreference` runtime value; this is the
    ///   on-disk backing that survives launches.
    static var storedDefaultConnectionPreference: Self {
        .json("DefaultConnectionPreference")
    }
}
