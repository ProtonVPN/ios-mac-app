//
//  Created on 22/07/2024.
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

import ProtonCoreFeatureFlags
import Domain

extension FeatureFlagsRepository {
    static let isRedesigniOSEnabled: Bool = {
        if !isFlagEnabled(.redesigniOSKillSwitch) || isFlagEnabled(.redesigniOS), #available(iOS 17, *) {
            return true
        }
        return false
    }()

    static let isConnectionFeatureEnabled: Bool = {
        !isFlagEnabled(.useConnectionFeatureKillSwitch) || isFlagEnabled(.useConnectionFeature) && isRedesigniOSEnabled
    }()

    private static func isFlagEnabled(_ flag: VPNFeatureFlagType) -> Bool {
        FeatureFlagsRepository.shared.isEnabled(flag)
    }
}
