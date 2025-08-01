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

public protocol PortForwardingPropertyProvider: FeaturePropertyProvider {
    /// Current Port Forwarding
    var portForwarding: Bool? { get set }
}

public protocol PortForwardingPropertyProviderFactory {
    func makePortForwardingPropertyProvider() -> PortForwardingPropertyProvider
}

public class PortForwardingPropertyProviderImplementation: PortForwardingPropertyProvider {
    private let key = "PortForwarding_"

    @Dependency(\.featureAuthorizerProvider) private var featureAuthorizerProvider
    private var canUse: Bool {
        let authorizer = featureAuthorizerProvider.authorizer(for: PortForwardingFeature.self)
        return authorizer().isAllowed
    }

    public var portForwarding: Bool? {
        get {
            guard canUse else { return nil }

            @Dependency(\.defaultsProvider) var provider
            guard let current = provider.getDefaults().userValue(forKey: key) as? Bool else {
                return false // false is the default value
            }

            return current
        }
        set {
            @Dependency(\.defaultsProvider) var provider
            provider.getDefaults().setUserValue(newValue, forKey: key)
            executeOnUIThread {
                AppEvent.portForwarding.post(newValue)
            }
        }
    }

    public func adjustAfterPlanChange(from _: Int, to tier: Int) {
        guard tier.isPaidTier else {
            portForwarding = false
            return
        }

        portForwarding = true
    }

    public init() {}
}

public struct PortForwardingFeature: PaidAppFeature {
    public static let featureFlag: KeyPath<FeatureFlags, Bool>? = \.portForwarding
}
