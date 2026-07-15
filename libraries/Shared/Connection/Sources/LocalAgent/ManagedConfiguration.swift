//
//  Created on 10/07/2026.
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

/// The OS-enforced provider properties the app mirrors into the real NE preferences on macOS, where the root System
/// Extension can't write them itself. Published by the extension whenever it persists a configuration change.
public struct ManagedConfiguration: Sendable, Equatable {
    public var includeAllNetworks: Bool
    public var excludeLocalNetworks: Bool
    public var isOnDemandEnabled: Bool?
    public var requestId: UUID?

    public init(includeAllNetworks: Bool, excludeLocalNetworks: Bool, isOnDemandEnabled: Bool?, requestId: UUID?) {
        self.includeAllNetworks = includeAllNetworks
        self.excludeLocalNetworks = excludeLocalNetworks
        self.isOnDemandEnabled = isOnDemandEnabled
        self.requestId = requestId
    }
}
