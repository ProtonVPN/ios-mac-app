//
//  Created on 19/12/2024.
//
//  Copyright (c) 2024 Proton AG
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

public struct TunnelFeatures: Equatable, Sendable, Codable {

#if !os(tvOS)
    public let killSwitch: Bool
    public let excludeLocalNetworks: Bool

    public init(killSwitch: Bool, excludeLocalNetworks: Bool) {
        self.killSwitch = killSwitch
        self.excludeLocalNetworks = excludeLocalNetworks
    }
#else
    // For tvOS, these properties do not exist
    public init() {
        // No properties to initialize on tvOS
    }
#endif
}
