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

import Foundation
import Dependencies

public struct LiveFeatureAuthorizerProvider: FeatureAuthorizerProvider {
    @Dependency(\.credentialsProvider) var credentialsProvider
    @Dependency(\.featureFlagProvider) var featureFlagProvider

    private var accountDetails: (plan: String, tier: Int) {
        let credentials = credentialsProvider.credentials
        return (
            credentials?.planName ?? "free",
            credentials?.maxTier ?? .freeTier
        )
    }

    public func authorizer<Feature: AppFeature>(
        for feature: Feature.Type
    ) -> () -> FeatureAuthorizationResult {
        return {
            let (plan, tier) = accountDetails

            return Feature.canUse(
                onPlan: plan,
                userTier: tier,
                featureFlags: featureFlagProvider.getFeatureFlags()
            )
        }
    }

    public func authorizer<Feature: ModularAppFeature>(
        forSubFeatureOf feature: Feature.Type
    ) -> (Feature) -> FeatureAuthorizationResult {
        return { feature in
            let (plan, tier) = accountDetails

            return feature.canUse(
                onPlan: plan,
                userTier: tier,
                featureFlags: featureFlagProvider.getFeatureFlags()
            )
        }
    }

    public func authorizer<Feature: ModularAppFeature>(
        for feature: Feature.Type
    ) -> Authorizer<Feature> {
        return Authorizer(canUse: { feature in
            let (plan, tier) = accountDetails

            return feature.canUse(
                onPlan: plan,
                userTier: tier,
                featureFlags: featureFlagProvider.getFeatureFlags()
            )
        })
    }
}
