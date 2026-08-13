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
import VPNShared

public extension NetShieldType {
    /// Determines whether a given NetShield level can be used according to feature flags and
    /// the NetShieldFeatureSettings on the credentials fetched during login (supports different
    /// NetShield levels for different Business plans).
    func canUse(
        userTier: VpnTier,
        featureFlags: FeatureFlags,
        netshieldSettings: NetShieldFeatureSettings?,
        isBusiness: Bool
    ) -> FeatureAuthorizationResult {
        if isDisabled { return .failure(.featureDisabled) }
        let base = canUse(userTier: userTier, featureFlags: featureFlags)
        guard case .success = base else { return base }
        return isHidden(by: netshieldSettings, isBusiness: isBusiness) ? .failure(.featureDisabled) : .success
    }

    /// Whether the given NetShield level should be hidden from the UI, either due to business
    /// account policies or because a given level is disabled as a feature.
    func isHidden(by settings: NetShieldFeatureSettings?, isBusiness: Bool) -> Bool {
        if isDisabled { return true }
        guard isBusiness, let settings else { return false }
        switch self {
        case .off:
            return false
        case .level1:
            return !settings.malware
        case .level2:
            return !settings.adsAndTrackers
        case .level3:
            return !settings.adultContent
        }
    }
}

public struct NetShieldPropertyProvider {
    /// Get the current NetShield type
    public var getNetShieldType: () -> NetShieldType

    /// Set the NetShield type
    public var setNetShieldType: (NetShieldType) -> Void

    /// Get the last active (non-off) NetShield type
    public var getLastActiveNetShieldType: () -> NetShieldType

    /// Stream of NetShield type changes
    public var netShieldTypeStream: () -> AsyncStream<NetShieldType>

    public init(
        getNetShieldType: @escaping () -> NetShieldType,
        setNetShieldType: @escaping (NetShieldType) -> Void,
        getLastActiveNetShieldType: @escaping () -> NetShieldType,
        netShieldTypeStream: @escaping () -> AsyncStream<NetShieldType>
    ) {
        self.getNetShieldType = getNetShieldType
        self.setNetShieldType = setNetShieldType
        self.getLastActiveNetShieldType = getLastActiveNetShieldType
        self.netShieldTypeStream = netShieldTypeStream
    }
}

// MARK: - Dependency Key

extension NetShieldPropertyProvider: DependencyKey {
    private enum StorageKey: String {
        case netShield = "NetShield"
        case lastActive = "LastActiveNetShield"
    }

    public static let liveValue: Self = {
        @Sendable
        func netShieldStorage() -> UserScopedAppStorageKey<NetShieldType?> {
            .rawInt(StorageKey.netShield.rawValue)
        }
        @Sendable
        func lastActiveStorage() -> UserScopedAppStorageKey<NetShieldType?> {
            .rawInt(StorageKey.lastActive.rawValue)
        }

        /// Resolves the tier/flag readers and the credentials client from the *current* dependency
        /// scope, returning a dependency-free authorization closure.
        @Sendable
        func makeAuthorize() -> @Sendable (NetShieldType) -> FeatureAuthorizationResult {
            @SharedReader(.userTier) var userTier: VpnTier?
            @SharedReader(.featureFlags) var featureFlags: FeatureFlags
            @Dependency(\.credentialsProvider) var credentialsProvider
            let tierReader = $userTier
            let flagsReader = $featureFlags
            return { level in
                level.canUse(
                    userTier: tierReader.wrappedValue ?? .free,
                    featureFlags: flagsReader.wrappedValue,
                    netshieldSettings: credentialsProvider.netShield,
                    isBusiness: credentialsProvider.isBusiness
                )
            }
        }

        /// The level to fall back to whenever nothing usable is stored.
        @Sendable
        func defaultType(
            authorize: @Sendable (NetShieldType) -> FeatureAuthorizationResult
        ) -> NetShieldType {
            authorize(.level2) == .success ? .level2 : .off
        }

        /// The stored value clamped by authorization, or `nil` when nothing is stored.
        @Sendable
        func clampedStoredValue(
            _ stored: NetShieldType?,
            authorize: @Sendable (NetShieldType) -> FeatureAuthorizationResult
        ) -> NetShieldType? {
            guard let stored else { return nil }
            guard authorize(stored).isAllowed else {
                return defaultType(authorize: authorize)
            }
            return stored
        }

        let getNetShieldType: () -> NetShieldType = {
            let authorize = makeAuthorize()
            let storage = netShieldStorage()
            guard let value = clampedStoredValue(storage.currentValue(), authorize: authorize) else {
                let fallback = defaultType(authorize: authorize)
                storage.setCurrentValue(fallback)
                return fallback
            }
            return value
        }

        let setNetShieldType: (NetShieldType) -> Void = { newValue in
            netShieldStorage().setCurrentValue(newValue)
            if newValue != .off {
                // Remember the last active level so the V1 UI can toggle off/on.
                lastActiveStorage().setCurrentValue(newValue)
            }
        }

        return Self(
            getNetShieldType: getNetShieldType,
            setNetShieldType: setNetShieldType,
            getLastActiveNetShieldType: {
                let authorize = makeAuthorize()
                if let lastActive = clampedStoredValue(lastActiveStorage().currentValue(), authorize: authorize) {
                    return lastActive
                }
                return getNetShieldType()
            },
            netShieldTypeStream: {
                let authorize = makeAuthorize()
                return netShieldStorage().mappedStream { stored in
                    clampedStoredValue(stored, authorize: authorize) ?? defaultType(authorize: authorize)
                }
            }
        )
    }()

    #if DEBUG
        public static let testValue: Self = {
            let changeSubject = CurrentValueSubject<NetShieldType, Never>(.off)
            return .init(
                getNetShieldType: { changeSubject.value },
                setNetShieldType: { changeSubject.send($0) },
                getLastActiveNetShieldType: { .level1 },
                netShieldTypeStream: {
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
    var netShieldPropertyProvider: NetShieldPropertyProvider {
        get { self[NetShieldPropertyProvider.self] }
        set { self[NetShieldPropertyProvider.self] = newValue }
    }
}
