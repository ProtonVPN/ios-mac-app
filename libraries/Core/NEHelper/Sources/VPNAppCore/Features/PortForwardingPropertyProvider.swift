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
import Sharing

public struct PortForwardingPropertyProvider {
    /// Get the current port forwarding state
    public var getPortForwarding: () -> Bool?

    /// Set the port forwarding state
    public var setPortForwarding: (Bool?) -> Void

    /// Stream of port forwarding changes
    public var portForwardingStream: () -> AsyncStream<Bool?>

    public init(
        getPortForwarding: @escaping () -> Bool?,
        setPortForwarding: @escaping (Bool?) -> Void,
        portForwardingStream: @escaping () -> AsyncStream<Bool?>
    ) {
        self.getPortForwarding = getPortForwarding
        self.setPortForwarding = setPortForwarding
        self.portForwardingStream = portForwardingStream
    }
}

// MARK: - Dependency Key

extension PortForwardingPropertyProvider: DependencyKey {
    private static let key = "PortForwarding_"

    public static let liveValue: Self = {
        @Sendable
        func storage() -> UserScopedAppStorageKey<Bool?> {
            .bool(key)
        }

        @Sendable
        func effectiveValue(
            stored: Bool?,
            userTier: VpnTier,
            featureFlags: FeatureFlags
        ) -> Bool? {
            guard PortForwardingFeature.canUse(userTier: userTier, featureFlags: featureFlags).isAllowed else {
                return nil
            }
            return stored ?? false // false is the default value
        }

        let getPortForwarding: () -> Bool? = {
            @SharedReader(.userTier) var userTier: VpnTier?
            @SharedReader(.featureFlags) var featureFlags: FeatureFlags
            return effectiveValue(
                stored: storage().currentValue(),
                userTier: userTier.orFree,
                featureFlags: featureFlags
            )
        }

        return Self(
            getPortForwarding: getPortForwarding,
            setPortForwarding: { storage().setCurrentValue($0) },
            portForwardingStream: {
                @SharedReader(.userTier) var userTier: VpnTier?
                @SharedReader(.featureFlags) var featureFlags: FeatureFlags
                let tierReader = $userTier
                let flagsReader = $featureFlags
                return storage().mappedStream { stored in
                    effectiveValue(
                        stored: stored,
                        userTier: tierReader.wrappedValue ?? .free,
                        featureFlags: flagsReader.wrappedValue
                    )
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
                }
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
