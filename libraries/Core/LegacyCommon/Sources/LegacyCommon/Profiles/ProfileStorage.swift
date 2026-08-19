//
//  ProfileStorage.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros
import Domain
import Foundation
import Sharing
import VPNShared

public enum StorageVersion: Int, CaseIterable {
    case v1 = 1
    case v2 = 2

    static let current: StorageVersion = .v2
}

@DependencyClient
public struct ProfileStorage {
    public var fetch: () -> [Profile] = { [] }
    public var store: (_ profiles: [Profile], _ storageVersion: StorageVersion) -> Void = { _, _ in }
}

final class ProfileStorageImplementation {
    private static let storageVersion = StorageVersion.v2
    private static let versionKey = "profileCacheVersion"

    @Dependency(\.authKeychain) var authKeychain

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func fetch() -> [Profile] {
        @Dependency(\.defaultAppStorage) var defaults

        var profiles: [Profile] = []

        for versionCheck in StorageVersion.allCases {
            guard let storageKey = storageKey(for: versionCheck) else {
                return []
            }

            let version = defaults.integer(forKey: Self.versionKey)
            if version == versionCheck.rawValue {
                profiles.append(contentsOf: fetchFromMemory(storageKey: storageKey))
            }

            if systemProfilesPresent(in: profiles) {
                profiles = removeSystemProfiles(in: profiles)
                store(profiles)
            }
        }

        return profiles
    }

    func store(_ profiles: [Profile], storageVersion: StorageVersion = .current) {
        guard let storageKey = storageKey(for: storageVersion) else {
            log.error("Unable to store profiles without a storage key.", category: .persistence)
            return
        }
        storeInMemory(profiles, storageKey: storageKey)
    }

    // MARK: - Private functions

    private func storageKey(for version: StorageVersion) -> String? {
        switch version {
        case .v1:
            authKeychain.username.map { "profiles_" + $0 }
        case .v2:
            authKeychain.userId.map { "profiles_" + $0 }
        }
    }

    private func fetchFromMemory(storageKey: String) -> [Profile] {
        @Dependency(\.defaultAppStorage) var defaults
        guard let data = defaults.data(forKey: storageKey) else {
            log.warning("No profile data stored under key \(storageKey)", category: .persistence)
            return []
        }
        do {
            return try decoder.decode([Profile].self, from: data)
        } catch {
            log.error("Failed to decode profiles from data", category: .persistence, metadata: ["error": "\(error)"])
        }
        return []
    }

    private func storeInMemory(_ profiles: [Profile], storageKey: String) {
        @Dependency(\.defaultAppStorage) var defaults
        defaults.set(Self.storageVersion.rawValue, forKey: Self.versionKey)
        let archivedData = try? encoder.encode(profiles)
        defaults.set(archivedData, forKey: storageKey)
    }

    private func removeSystemProfiles(in profiles: [Profile]) -> [Profile] {
        profiles.filter { $0.profileType != .system }
    }

    private func systemProfilesPresent(in profiles: [Profile]) -> Bool {
        !profiles.filter { $0.profileType == .system }.isEmpty
    }
}

enum ProfileStorageKey: DependencyKey {
    static var liveValue: ProfileStorage = {
        let profileStorageImpl = ProfileStorageImplementation()
        return ProfileStorage(
            fetch: {
                profileStorageImpl.fetch()
            },
            store: { profiles, version in
                profileStorageImpl.store(profiles, storageVersion: version)
            }
        )
    }()
}

public extension DependencyValues {
    var profileStorage: ProfileStorage {
        get { self[ProfileStorageKey.self] }
        set { self[ProfileStorageKey.self] = newValue }
    }
}
