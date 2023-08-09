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
import XCTestDynamicOverlay
import VPNShared

public protocol FeatureAuthorizer {
    func authorizer<T: AppFeature>(forSubFeatureOf feature: T.Type) -> (T.SubFeature) -> Bool
    // Can we constrain this to AppFeature where SubFeature == Void? Otherwise implement this as canUse(allSubFeatures)
    func authorizer<T: AppFeature>(for feature: T.Type) -> () -> Bool
}

public struct LiveFeatureAuthorizer: FeatureAuthorizer {
    @Dependency(\.planProvider) var planProvider
    @Dependency(\.featureFlagProvider) var featureFlagProvider

    public func authorizer<T: AppFeature>(forSubFeatureOf feature: T.Type) -> (T.SubFeature) -> Bool {
        return { subFeature in
            feature.canUse(
                subFeature,
                onPlan: planProvider.plan,
                featureFlags: featureFlagProvider.getFeatureFlags()
            )
        }
    }

    public func authorizer<T: AppFeature>(for feature: T.Type) -> () -> Bool {
        return {
            feature.canUseAllSubFeatures(
                onPlan: planProvider.plan,
                featureFlags: featureFlagProvider.getFeatureFlags()
            )
        }
    }
}

public protocol AppFeature {
    associatedtype SubFeature

    static func canUseAllSubFeatures(onPlan plan: AccountPlan, featureFlags: FeatureFlags) -> Bool
    static func canUse(_ subFeature: SubFeature, onPlan plan: AccountPlan, featureFlags: FeatureFlags) -> Bool
}

extension AppFeature where SubFeature: CaseIterable {
    static func canUseAllSubFeatures(onPlan plan: AccountPlan, featureFlags: FeatureFlags) -> Bool {
        return SubFeature.allCases
            .allSatisfy { canUse($0, onPlan: plan, featureFlags: featureFlags) }
    }
}

extension AppFeature where SubFeature == Void {
    static func canUseAllSubFeatures(onPlan plan: AccountPlan, featureFlags: FeatureFlags) -> Bool {
        canUse((), onPlan: plan, featureFlags: featureFlags)
    }
}

// MARK: Dependencies conformances

enum FeatureAuthorizerKey: DependencyKey {
    public static var liveValue: FeatureAuthorizer { LiveFeatureAuthorizer() }
    public static var mock: MockFeatureAuthorizer { MockFeatureAuthorizer() }
}

extension DependencyValues {
    public var featureAuthorizer: FeatureAuthorizer {
        get { self[FeatureAuthorizerKey.self] }
        set { self[FeatureAuthorizerKey.self] = newValue }
    }
}
