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

import Combine
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

    /// Stream of port forwarding changes
    public var portForwardingStream: () -> AsyncStream<Bool?>

    /// Adjust settings after plan change
    public var adjustAfterPlanChangeClosure: (_ from: Int, _ to: Int) -> Void

    public init(
        getPortForwarding: @escaping () -> Bool?,
        setPortForwarding: @escaping (Bool?) -> Void,
        portForwardingStream: @escaping () -> AsyncStream<Bool?>,
        adjustAfterPlanChange: @escaping (Int, Int) -> Void
    ) {
        self.getPortForwarding = getPortForwarding
        self.setPortForwarding = setPortForwarding
        self.portForwardingStream = portForwardingStream
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

        let getPortForwarding: () -> Bool? = {
            guard canUse() else { return nil }

            guard let current = defaultsProvider.getDefaults().userValue(forKey: key) as? Bool else {
                return false // false is the default value
            }

            return current
        }

        // Create a shared subject for broadcasting changes
        let initialValue = getPortForwarding()
        let changeSubject = CurrentValueSubject<Bool?, Never>(initialValue)

        let setPortForwarding: (Bool?) -> Void = { newValue in
            defaultsProvider.getDefaults().setUserValue(newValue, forKey: key)
            changeSubject.send(newValue)
        }

        return Self(
            getPortForwarding: getPortForwarding,
            setPortForwarding: setPortForwarding,
            portForwardingStream: {
                AsyncStream { continuation in
                    let cancellable = changeSubject
                        .removeDuplicates()
                        .sink { value in
                            continuation.yield(value)
                        }
                    continuation.onTermination = { _ in
                        cancellable.cancel()
                    }
                }
            },
            adjustAfterPlanChange: { _, tier in
                guard tier.isPaidTier else {
                    setPortForwarding(false)
                    return
                }
            }
        )
    }()

    #if DEBUG
        public static let testValue: Self = {
            let changeSubject = CurrentValueSubject<Bool?, Never>(false)

            return .init(
                getPortForwarding: { changeSubject.value },
                setPortForwarding: { newValue in
                    changeSubject.send(newValue)
                },
                portForwardingStream: {
                    AsyncStream { continuation in
                        let cancellable = changeSubject
                            .removeDuplicates()
                            .sink { value in
                                continuation.yield(value)
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                },
                adjustAfterPlanChange: { _, _ in }
            )
        }()
    #endif
}

public extension DependencyValues {
    var portForwardingPropertyProvider: PortForwardingPropertyProvider {
        get { self[PortForwardingPropertyProvider.self] }
        set { self[PortForwardingPropertyProvider.self] = newValue }
    }
}
