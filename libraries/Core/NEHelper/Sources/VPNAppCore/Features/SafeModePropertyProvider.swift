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

public struct SafeModePropertyProvider {
    /// Get the current safe mode state (`nil` when the user is not authorized)
    public var getSafeMode: () -> Bool?

    /// Set the safe mode state
    public var setSafeMode: (Bool?) -> Void

    /// Stream of safe mode changes
    public var safeModeStream: () -> AsyncStream<Bool?>

    public init(
        getSafeMode: @escaping () -> Bool?,
        setSafeMode: @escaping (Bool?) -> Void,
        safeModeStream: @escaping () -> AsyncStream<Bool?>
    ) {
        self.getSafeMode = getSafeMode
        self.setSafeMode = setSafeMode
        self.safeModeStream = safeModeStream
    }
}

// MARK: - Dependency Key

extension SafeModePropertyProvider: DependencyKey {
    private static let key = "SafeMode"

    public static let liveValue: Self = {
        let storage: UserScopedAppStorageKey<Bool?> = .bool(key)

        let canUse: () -> Bool = {
            @SharedReader(.userTier) var userTier: Int?
            @Shared(.featureFlags) var featureFlags: FeatureFlags
            return SafeModeFeature.canUse(userTier: userTier ?? .freeTier, featureFlags: featureFlags).isAllowed
        }

        let getSafeMode: () -> Bool? = {
            guard canUse() else { return nil }
            return storage.currentValue() ?? true // true is the default value
        }

        return Self(
            getSafeMode: getSafeMode,
            setSafeMode: { storage.setCurrentValue($0) },
            safeModeStream: { storage.mappedStream { _ in getSafeMode() } }
        )
    }()

    #if DEBUG
        public static let testValue: Self = {
            let changeSubject = CurrentValueSubject<Bool?, Never>(true)
            return .init(
                getSafeMode: { changeSubject.value },
                setSafeMode: { changeSubject.send($0) },
                safeModeStream: {
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
    var safeModePropertyProvider: SafeModePropertyProvider {
        get { self[SafeModePropertyProvider.self] }
        set { self[SafeModePropertyProvider.self] = newValue }
    }
}
