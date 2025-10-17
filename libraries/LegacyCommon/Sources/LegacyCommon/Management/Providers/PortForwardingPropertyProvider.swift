//
//  Created on 17/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Domain
import Ergonomics
import Foundation
import VPNShared

public struct PortForwardingPropertyProvider {
    /// Get the current port forwarding state
    public var getPortForwarding: () -> Bool?

    /// Set the port forwarding state
    public var setPortForwarding: (Bool?) -> Void

    /// Adjust settings after plan change
    public var adjustAfterPlanChangeClosure: (_ from: Int, _ to: Int) -> Void

    public init(
        getPortForwarding: @escaping () -> Bool?,
        setPortForwarding: @escaping (Bool?) -> Void,
        adjustAfterPlanChange: @escaping (Int, Int) -> Void
    ) {
        self.getPortForwarding = getPortForwarding
        self.setPortForwarding = setPortForwarding
        self.adjustAfterPlanChangeClosure = adjustAfterPlanChange
    }
}

extension PortForwardingPropertyProvider: FeaturePropertyProvider {
    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        adjustAfterPlanChangeClosure(oldTier, tier)
    }
}

public struct PortForwardingFeature: PaidAppFeature {
    public static func canUse(userTier: Int, featureFlags _: FeatureFlags) -> FeatureAuthorizationResult {
        guard userTier.isPaidTier else { return .failure(.requiresUpgrade) }
        return .success
    }
}

// MARK: - Dependency Key

extension PortForwardingPropertyProvider: DependencyKey {
    private static let key = "PortForwarding_"

    public static let liveValue: Self = {
        @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider
        @Dependency(\.defaultsProvider) var defaultsProvider

        let canUse: () -> Bool = {
            let authorizer = featureAuthorizerProvider.authorizer(for: PortForwardingFeature.self)
            return authorizer().isAllowed
        }

        return Self(
            getPortForwarding: {
                guard canUse() else { return nil }

                guard let current = defaultsProvider.getDefaults().userValue(forKey: key) as? Bool else {
                    return false // false is the default value
                }

                return current
            },
            setPortForwarding: { newValue in
                defaultsProvider.getDefaults().setUserValue(newValue, forKey: key)
                executeOnUIThread {
                    AppEvent.portForwarding.post(newValue)
                }
            },
            adjustAfterPlanChange: { _, tier in
                guard tier.isPaidTier else {
                    defaultsProvider.getDefaults().setUserValue(false, forKey: key)
                    executeOnUIThread {
                        AppEvent.portForwarding.post(false)
                    }
                    return
                }

                defaultsProvider.getDefaults().setUserValue(true, forKey: key)
                executeOnUIThread {
                    AppEvent.portForwarding.post(true)
                }
            }
        )
    }()

    #if DEBUG
        public static let testValue: Self = .init(
            getPortForwarding: { false },
            setPortForwarding: { _ in },
            adjustAfterPlanChange: { _, _ in }
        )
    #endif
}

public extension DependencyValues {
    var portForwardingPropertyProvider: PortForwardingPropertyProvider {
        get { self[PortForwardingPropertyProvider.self] }
        set { self[PortForwardingPropertyProvider.self] = newValue }
    }
}
