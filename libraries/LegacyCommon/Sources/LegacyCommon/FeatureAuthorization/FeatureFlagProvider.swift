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

import Foundation
import Dependencies

public struct FeatureFlagProvider: DependencyKey {
    var getFeatureFlags: () -> FeatureFlags
    var setFeatureFlags: (FeatureFlags) -> Void

    public static var liveValue: FeatureFlagProvider = FeatureFlagProvider(
        getFeatureFlags: { PropertiesManager().featureFlags },
        setFeatureFlags: { PropertiesManager().featureFlags = $0 }
    )

    #if DEBUG
    public static var testValue: FeatureFlagProvider = .constant(flags: .allEnabled)

    public static func constant(flags: FeatureFlags) -> FeatureFlagProvider {
        return FeatureFlagProvider(
            getFeatureFlags: { flags },
            setFeatureFlags: { _ in }
        )
    }
    #endif
}

extension FeatureFlagProvider {
    public subscript(_ keyPath: KeyPath<FeatureFlags, Bool>) -> Bool {
        getFeatureFlags()[keyPath: keyPath]
    }
}

extension DependencyValues {
    public var featureFlagProvider: FeatureFlagProvider {
        get { self[FeatureFlagProvider.self] }
        set { self[FeatureFlagProvider.self] = newValue }
    }
}
