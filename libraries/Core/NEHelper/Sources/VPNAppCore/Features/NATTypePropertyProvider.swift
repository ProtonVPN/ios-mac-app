//
//  Created on 10/06/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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
import Sharing

public struct NATTypePropertyProvider {
    /// Get the current NAT type
    public var getNATType: () -> NATType

    /// Set the NAT type
    public var setNATType: (NATType) -> Void

    /// Stream of NAT type changes
    public var natTypeStream: () -> AsyncStream<NATType>

    public init(
        getNATType: @escaping () -> NATType,
        setNATType: @escaping (NATType) -> Void,
        natTypeStream: @escaping () -> AsyncStream<NATType>
    ) {
        self.getNATType = getNATType
        self.setNATType = setNATType
        self.natTypeStream = natTypeStream
    }
}

// MARK: - Dependency Key

extension NATTypePropertyProvider: DependencyKey {
    private static let key = "NATType"

    public static let liveValue: Self = {
        @Sendable
        func storage() -> UserScopedAppStorageKey<NATType?> {
            .rawInt(key)
        }

        @Sendable
        func effectiveValue(
            stored: NATType?,
            userTier: VpnTier,
            featureFlags: FeatureFlags
        ) -> NATType {
            guard NATFeature.canUse(userTier: userTier, featureFlags: featureFlags).isAllowed else {
                return .default
            }
            return stored ?? .default
        }

        let getNATType: () -> NATType = {
            @SharedReader(.userTier) var userTier: VpnTier?
            @SharedReader(.featureFlags) var featureFlags: FeatureFlags
            return effectiveValue(
                stored: storage().currentValue(),
                userTier: userTier ?? .free,
                featureFlags: featureFlags
            )
        }

        return Self(
            getNATType: getNATType,
            setNATType: { storage().setCurrentValue($0) },
            natTypeStream: {
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
            let changeSubject = CurrentValueSubject<NATType, Never>(.default)
            return .init(
                getNATType: { changeSubject.value },
                setNATType: { changeSubject.send($0) },
                natTypeStream: {
                    AsyncStream { continuation in
                        let cancellable = changeSubject
                            .removeDuplicates()
                            .sink { continuation.yield($0) }
                        continuation.onTermination = { _ in cancellable.cancel() }
                    }
                }
            )
        }()
    #endif
}

public extension DependencyValues {
    var natTypePropertyProvider: NATTypePropertyProvider {
        get { self[NATTypePropertyProvider.self] }
        set { self[NATTypePropertyProvider.self] = newValue }
    }
}
