//
//  Created on 09/08/2023.
//
//  Copyright (c) 2023 Proton AG
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

import CommonNetworking
import Dependencies
import Foundation

extension FeatureFlagProvider: DependencyKey {
    public static var liveValue: FeatureFlagProvider = .init(
        getFeatureFlags: {
            @Dependency(\.propertiesManager) var propertiesManager
            return propertiesManager.featureFlags
        },
        setFeatureFlags: {
            @Dependency(\.propertiesManager) var propertiesManager
            propertiesManager.featureFlags = $0
        }
    )
}
