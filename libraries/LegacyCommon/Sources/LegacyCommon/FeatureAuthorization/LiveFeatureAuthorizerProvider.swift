//
//  Created on 15/08/2023.
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

import Dependencies
import Foundation

public struct LiveFeatureAuthorizerProvider: FeatureAuthorizerProvider {
    @Dependency(\.credentialsProvider) var credentialsProvider
    @Dependency(\.featureFlagProvider) var featureFlagProvider

    private var maxTier: Int {
        credentialsProvider.credentials?.maxTier ?? .freeTier
    }

    public func authorizer<Feature: AppFeature>(
        for _: Feature.Type
    ) -> () -> FeatureAuthorizationResult {
        {
            Feature.canUse(
                userTier: maxTier,
                featureFlags: featureFlagProvider.getFeatureFlags()
            )
        }
    }

    public func authorizer<Feature: ModularAppFeature>(
        forSubFeatureOf feature: Feature.Type
    ) -> (Feature) -> FeatureAuthorizationResult {
        { feature in
            feature.canUse(
                userTier: maxTier,
                featureFlags: featureFlagProvider.getFeatureFlags()
            )
        }
    }

    public func authorizer<Feature: ModularAppFeature>(
        for feature: Feature.Type
    ) -> Authorizer<Feature> {
        Authorizer(canUse: { feature in
            feature.canUse(
                userTier: maxTier,
                featureFlags: featureFlagProvider.getFeatureFlags()
            )
        })
    }
}
