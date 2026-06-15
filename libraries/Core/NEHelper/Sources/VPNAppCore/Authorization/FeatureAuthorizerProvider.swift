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

import Dependencies
import Domain
import Foundation

/// `FeatureAuthorizerProvider` exposes an interface for generating feature authorizers for features defined using the
/// `AppFeature` or `ModularAppFeature` protocols.
///
/// Check `FeatureAuthorizerProviderTests` for example usage.
public protocol FeatureAuthorizerProvider {
    /// Returns an authorizer for the given feature
    func authorizer(for feature: (some AppFeature).Type) -> () -> FeatureAuthorizationResult

    /// Returns a sub-feature authorizer for the given feature.
    func authorizer<T: ModularAppFeature>(forSubFeatureOf feature: T.Type) -> (T) -> FeatureAuthorizationResult

    /// Returns a small wrapper struct that includes some convenience functions on top of the sub-feature authorizer.
    func authorizer<T: ModularAppFeature>(for feature: T.Type) -> Authorizer<T>
}

public enum FeatureAuthorizerKey: DependencyKey {
    public static var liveValue: FeatureAuthorizerProvider {
        LiveFeatureAuthorizerProvider()
    }

    #if DEBUG
        public static var testValue: FeatureAuthorizerProvider {
            MockFeatureAuthorizerProvider()
        }

        public static func constant(_ result: FeatureAuthorizationResult) -> FeatureAuthorizerProvider {
            ConstantFeatureAuthorizerProvider(result: result)
        }
    #endif
}

public extension DependencyValues {
    var featureAuthorizerProvider: FeatureAuthorizerProvider {
        get { self[FeatureAuthorizerKey.self] }
        set { self[FeatureAuthorizerKey.self] = newValue }
    }
}
