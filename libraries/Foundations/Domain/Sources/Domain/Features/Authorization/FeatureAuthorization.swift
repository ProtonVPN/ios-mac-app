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

public typealias FeatureAuthorizationResult = Result<None, FeatureAuthorizationFailureReason>

public extension FeatureAuthorizationResult {
    static var success: FeatureAuthorizationResult {
        .success(nil)
    }

    var isAllowed: Bool {
        guard case .success = self else { return false }
        return true
    }

    var requiresUpgrade: Bool {
        guard case .failure(.requiresUpgrade) = self else { return false }
        return true
    }

    var featureDisabled: Bool {
        guard case .failure(.featureDisabled) = self else { return false }
        return true
    }
}

public enum FeatureAuthorizationFailureReason: Error, Equatable {
    case featureDisabled
    case requiresUpgrade
}

/// Wrapper around the basic sub-feature authorizer, providing some convenience functions
public struct Authorizer<Feature: ModularAppFeature> {
    public let canUse: (_ subFeature: Feature) -> FeatureAuthorizationResult

    public init(canUse: @escaping (_ subFeature: Feature) -> FeatureAuthorizationResult) {
        self.canUse = canUse
    }

    public var canUseAnySubFeature: FeatureAuthorizationResult {
        Feature.allCases.reduce(into: .failure(.featureDisabled)) { result, subFeature in
            let subFeatureResult = canUse(subFeature)
            result = subFeatureResult == .success ? .success : result
        }
    }

    public var canUseAllSubFeatures: FeatureAuthorizationResult {
        Feature.allCases.reduce(into: .success) { result, subFeature in
            let subFeatureResult = canUse(subFeature)
            result = subFeatureResult == .success ? result : subFeatureResult
        }
    }
}

/// Represents a feature with no sub-features or 'levels' that may need authorization logic
public protocol AppFeature {
    static func canUse(userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult
}

public protocol PaidAppFeature: AppFeature {
    static var featureFlag: KeyPath<FeatureFlags, Bool>? { get }
    static func minTier(featureFlags: FeatureFlags) -> Int
}

public extension PaidAppFeature {
    static var featureFlag: KeyPath<FeatureFlags, Bool>? {
        nil
    }

    static func minTier(featureFlags _: FeatureFlags) -> Int {
        .paidTier
    }

    static func canUse(userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if let featureFlag {
            guard featureFlags[keyPath: featureFlag] else {
                return .failure(.featureDisabled)
            }
        }

        guard minTier(featureFlags: featureFlags) <= userTier else {
            return .failure(.requiresUpgrade)
        }

        return .success
    }
}

/// Represents a feature that may contains a number of related features, or 'levels'.
public protocol ModularAppFeature: CaseIterable {
    func canUse(userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult
}

/// Allows us to define `Equatable` `Result` types for modelling domains where there is no value associated with success
public struct None: Equatable, ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) {}
}
