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

import Foundation
import Dependencies
import VPNShared

public protocol ProfileStorageFactory {
    func makeProfileStorage() -> ProfileStorage
}

// TODO: This would be a good use case for non-user defaults storage
//  - Profiles can get pretty big because they encode servers (big especially when they are SC servers)
//  - Once we move to something like Core Data for servers, we could model a relationship between profiles and servers?
public final class ProfileStorage {
    enum StorageVersion: Int, CaseIterable {
        case v1 = 1
        case v2 = 2

        static let current: StorageVersion = .v2
    }

    private static let storageVersion = StorageVersion.v2
    private static let versionKey     = "profileCacheVersion"
    
    public static let contentChanged = Notification.Name("ProfileStorageContentChanged")

    private let authKeychain: AuthKeychainHandle

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public typealias Factory = AuthKeychainHandleFactory

    public convenience init(_ factory: Factory) {
        self.init(authKeychain: factory.makeAuthKeychainHandle())
    }

    public init(authKeychain: AuthKeychainHandle) {
        self.authKeychain = authKeychain
    }
    
    func fetch() -> [Profile] {
        @Dependency(\.defaultsProvider) var provider

        var profiles: [Profile] = []

        for versionCheck in StorageVersion.allCases {
            guard let storageKey = storageKey(for: versionCheck) else {
                return []
            }

            let version = provider.getDefaults().integer(forKey: Self.versionKey)
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
        DispatchQueue.main.async { NotificationCenter.default.post(name: Self.contentChanged, object: profiles) }
    }
    
    // MARK: - Private functions

    private func storageKey(for version: StorageVersion) -> String? {
        switch version {
        case .v1:
            return authKeychain.username.map { "profiles_" + $0 }
        case .v2:
            return authKeychain.userId.map { "profiles_" + $0 }
        }
    }
    
    private func fetchFromMemory(storageKey: String) -> [Profile] {
        @Dependency(\.defaultsProvider) var provider
        guard let data = provider.getDefaults().data(forKey: storageKey) else {
            return []
        }
        if let userProfiles = try? decoder.decode([Profile].self, from: data) {
            return userProfiles
        } else {
            /// We tried decoding with JSON and failed, let's try to decode from NSKeyedUnarchiver,
            /// but first let's remove the stored data in case the NSKeyedUnarchiver crashes.
            /// Next time user launches the app, the credentials will be lost, but at least
            /// we won't start a crash cycle from which the user can't recover.
            provider.getDefaults().removeObject(forKey: storageKey)
            log.info("Removed Profile storage for \(storageKey) key before attempting to unarchive with NSKeyedUnarchiver", category: .persistence)
        }
        // Migration - try reading profiles the old way, if successful, overwrite with the new way
        if let oldUserProfiles = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Profile] {
            store(oldUserProfiles)
            log.info("Profile storage for \(storageKey) migration successful!", category: .persistence)
            return fetch()
        }
        return []
    }
    
    private func storeInMemory(_ profiles: [Profile], storageKey: String) {
        @Dependency(\.defaultsProvider) var provider
        provider.getDefaults().set(Self.storageVersion.rawValue, forKey: Self.versionKey)
        let archivedData = try? encoder.encode(profiles)
        provider.getDefaults().set(archivedData, forKey: storageKey)
    }
    
    private func removeSystemProfiles(in profiles: [Profile]) -> [Profile] {
        return profiles.filter({ $0.profileType != .system })
    }
    
    private func systemProfilesPresent(in profiles: [Profile]) -> Bool {
        return !profiles.filter({ $0.profileType == .system }).isEmpty
    }
    
}
