//
//  Created on 15.02.2022.
//
//  Copyright (c) 2022 Proton AG
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
import Ergonomics
import Foundation
import VPNShared

public struct SafeModePropertyProvider {
    /// Get the current safe mode state
    public var getSafeMode: () -> Bool?

    /// Set the safe mode state
    public var setSafeMode: (Bool?) -> Void

    /// Adjust settings after plan change
    public var adjustAfterPlanChangeClosure: (_ from: Int, _ to: Int) -> Void

    public init(
        getSafeMode: @escaping () -> Bool?,
        setSafeMode: @escaping (Bool?) -> Void,
        adjustAfterPlanChange: @escaping (Int, Int) -> Void
    ) {
        self.getSafeMode = getSafeMode
        self.setSafeMode = setSafeMode
        self.adjustAfterPlanChangeClosure = adjustAfterPlanChange
    }
}

extension SafeModePropertyProvider: FeaturePropertyProvider {
    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        adjustAfterPlanChangeClosure(oldTier, tier)
    }
}

public struct SafeModeFeature: PaidAppFeature {
    public static let featureFlag: KeyPath<FeatureFlags, Bool>? = \.safeMode
}

// MARK: - Dependency Key

extension SafeModePropertyProvider: DependencyKey {
    private static let key = "SafeMode"

    public static let liveValue: Self = {
        @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider
        @Dependency(\.defaultsProvider) var defaultsProvider

        let canUse: () -> Bool = {
            let authorizer = featureAuthorizerProvider.authorizer(for: SafeModeFeature.self)
            return authorizer().isAllowed
        }

        return Self(
            getSafeMode: {
                guard canUse() else { return nil }

                guard let current = defaultsProvider.getDefaults().userValue(forKey: key) as? Bool else {
                    return true // true is the default value
                }

                return current
            },
            setSafeMode: { newValue in
                defaultsProvider.getDefaults().setUserValue(newValue, forKey: key)
                executeOnUIThread {
                    AppEvent.safeMode.post(newValue)
                }
            },
            adjustAfterPlanChange: { _, tier in
                guard tier.isPaidTier else {
                    defaultsProvider.getDefaults().setUserValue(false, forKey: key)
                    executeOnUIThread {
                        AppEvent.safeMode.post(false)
                    }
                    return
                }

                defaultsProvider.getDefaults().setUserValue(true, forKey: key)
                executeOnUIThread {
                    AppEvent.safeMode.post(true)
                }
            }
        )
    }()

    #if DEBUG
        public static let testValue: Self = .init(
            getSafeMode: { true },
            setSafeMode: { _ in },
            adjustAfterPlanChange: { _, _ in }
        )
    #endif
}

public extension DependencyValues {
    var safeModePropertyProvider: SafeModePropertyProvider {
        get { self[SafeModePropertyProvider.self] }
        set { self[SafeModePropertyProvider.self] = newValue }
    }
}
