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
import Sharing

// Keys migrated off the legacy `PropertiesManager`, hosted alongside their value types. Each reuses
// the exact UserDefaults key and JSON on-disk representation the legacy property used.

public extension SharedKey where Self == JSONAppStorageKey<ServerChangeConfig>.Default {
    /// The change-server rate-limit configuration. Legacy key: `ServerChangeConfig` (JSON).
    static var serverChangeConfig: Self {
        Self[.json("ServerChangeConfig", default: ServerChangeConfig()), default: ServerChangeConfig()]
    }
}

public extension SharedKey where Self == JSONAppStorageKey<StreamingDictServices>.Default {
    /// The per-country streaming services catalogue. Legacy key: `streamingServices` (JSON).
    static var streamingServices: Self {
        Self[.json("streamingServices", default: StreamingDictServices()), default: StreamingDictServices()]
    }
}
