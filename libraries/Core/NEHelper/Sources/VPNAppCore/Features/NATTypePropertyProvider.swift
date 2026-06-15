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
        let storage: UserScopedAppStorageKey<NATType?> = .rawInt(key)

        let canUse: () -> Bool = {
            @SharedReader(.userTier) var userTier: Int?
            @Shared(.featureFlags) var featureFlags: FeatureFlags
            return NATFeature.canUse(userTier: userTier ?? .freeTier, featureFlags: featureFlags).isAllowed
        }

        let getNATType: () -> NATType = {
            guard canUse() else { return .default }
            return storage.currentValue() ?? .default
        }

        return Self(
            getNATType: getNATType,
            setNATType: { storage.setCurrentValue($0) },
            natTypeStream: { storage.mappedStream { _ in getNATType() } }
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
