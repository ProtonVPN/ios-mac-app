//
//  Created on 21/05/2026.
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

public enum LocalAgent {
    /// Used for guessing which user-changed setting resulted in a policy violation error server-side.
    public enum SettingType: Codable {
        case netshieldLevel
        case bouncing
        case portForwarding
        case splitTcp
        case safeMode
        case randomNat
    }
}

package extension NetShieldType {
    var shouldObserveNetShieldStats: Bool {
        switch self {
        case .off, .level1:
            false
        case .level2, .level3:
            true
        }
    }
}
