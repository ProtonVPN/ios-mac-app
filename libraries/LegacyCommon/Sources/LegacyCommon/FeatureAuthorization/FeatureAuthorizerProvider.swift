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

/// `FeatureAuthorizerProvider` exposes an interface for generating feature authorizers for features defined using the
/// `AppFeature` or `ModularAppFeature` protocols.
///
/// Check `FeatureAuthorizerProviderTests` for example usage.
public protocol FeatureAuthorizerProvider {

    /// Returns an authorizer for the given feature
    func authorizer<T: AppFeature>(for feature: T.Type) -> () -> FeatureAuthorizationResult

    /// Returns a sub-feature authorizer for the given feature.
    func authorizer<T: ModularAppFeature>(forSubFeatureOf feature: T.Type) -> (T) -> FeatureAuthorizationResult

    /// Returns a small wrapper struct that includes some convenience functions on top of the sub-feature authorizer.
    func authorizer<T: ModularAppFeature>(for feature: T.Type) -> Authorizer<T>
}

public typealias FeatureAuthorizationResult = Result<None, FeatureAuthorizationFailureReason>

extension FeatureAuthorizationResult {
    public static var success: FeatureAuthorizationResult {
        .success(nil)
    }

    public var isAllowed: Bool {
        guard case .success = self else { return false }
        return true
    }

    public var requiresUpgrade: Bool {
        guard case .failure(.requiresUpgrade) = self else { return false }
        return true
    }

    public var featureDisabled: Bool {
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
    let canUse: (_ subFeature: Feature) -> FeatureAuthorizationResult

    var canUseAnySubFeature: FeatureAuthorizationResult {
        Feature.allCases.reduce(into: .failure(.featureDisabled)) { result, subFeature in
            let subFeatureResult = canUse(subFeature)
            result = subFeatureResult == .success ? .success : result
        }
    }

    var canUseAllSubFeatures: FeatureAuthorizationResult {
        Feature.allCases.reduce(into: .success) { result, subFeature in
            let subFeatureResult = canUse(subFeature)
            result = subFeatureResult == .success ? result : subFeatureResult
        }
    }
}

/// Represents a feature with no sub-features or 'levels' that may need authorization logic
public protocol AppFeature {
    static func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult
}

public protocol PaidAppFeature: AppFeature {
    static var featureFlag: KeyPath<FeatureFlags, Bool>? { get }
    static func minTier(featureFlags: FeatureFlags) -> Int
    static var includedAccountPlans: [String]? { get }
    static var excludedAccountPlans: [String]? { get }
}

extension PaidAppFeature {
    public static var featureFlag: KeyPath<FeatureFlags, Bool>? {
        nil
    }

    public static func minTier(featureFlags: FeatureFlags) -> Int {
        CoreAppConstants.VpnTiers.basic
    }

    public static var includedAccountPlans: [String]? {
        nil
    }

    public static var excludedAccountPlans: [String]? {
        nil
    }

    public static func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult {
        if let featureFlag {
            guard featureFlags[keyPath: featureFlag] else {
                return .failure(.featureDisabled)
            }
        }

        if let excludedAccountPlans {
            guard !excludedAccountPlans.contains(plan) else {
                return .failure(.requiresUpgrade)
            }
        }

        if let includedAccountPlans {
            guard includedAccountPlans.contains(plan) else {
                return .failure(.requiresUpgrade)
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
    func canUse(onPlan plan: String, userTier: Int, featureFlags: FeatureFlags) -> FeatureAuthorizationResult
}

public enum FeatureAuthorizerKey: DependencyKey {
    public static var liveValue: FeatureAuthorizerProvider { LiveFeatureAuthorizerProvider() }

    #if DEBUG
    public static var testValue: FeatureAuthorizerProvider { MockFeatureAuthorizerProvider() }

    public static func constant(_ result: FeatureAuthorizationResult) -> FeatureAuthorizerProvider {
        return ConstantFeatureAuthorizerProvider(result: result)
    }
    #endif
}

extension DependencyValues {
    public var featureAuthorizerProvider: FeatureAuthorizerProvider {
        get { self[FeatureAuthorizerKey.self] }
        set { self[FeatureAuthorizerKey.self] = newValue }
    }
}
