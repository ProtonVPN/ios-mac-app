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

import Sharing

// Per-user keys migrated off the legacy `PropertiesManager` per-user methods. The current username
// is resolved internally from `\.authKeychain`, and the on-disk key (`baseKey + username`) matches
// the legacy representation, so existing profiles are read transparently.

public extension SharedKey where Self == UserScopedAppStorageKey<String?> {
    /// The auto-connect profile id for the current user. Legacy key: `AutoConnect_<username>`.
    static var autoConnectProfileId: Self {
        .string("AutoConnect_")
    }

    /// The quick-connect profile id for the current user. Legacy key: `QuickConnect_<username>`.
    static var quickConnect: Self {
        .string("QuickConnect_")
    }
}
