//
//  ProfileStorage.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

class ProfileStorage {
    
    private static let storageVersion = 1
    private static let versionKey     = "profileCacheVersion"
    
    static let contentChanged = Notification.Name("ProfileStorageContentChanged")
    
    static func fetch() -> [Profile] {
        guard let storageKey = storageKey() else {
            return []
        }
        
        let version = Storage.userDefaults().integer(forKey: versionKey)
        var profiles = [Profile]()
        if version == storageVersion {
            profiles = fetchFromMemory(storageKey: storageKey)
        }
        
        if systemProfilesPresent(in: profiles) {
            profiles = removeSystemProfiles(in: profiles)
            store(profiles)
        }
        
        return profiles
    }
    
    static func store(_ profiles: [Profile]) {
        guard let storageKey = storageKey() else { return }
        storeInMemory(profiles, storageKey: storageKey)
        DispatchQueue.main.async { NotificationCenter.default.post(name: contentChanged, object: profiles) }
    }
    
    // MARK: - Private static functions
    private static func storageKey() -> String? {
        guard let authCredentials = AuthKeychain.fetch() else { return nil }
        return "profiles_" + authCredentials.username
    }
    
    private static func fetchFromMemory(storageKey: String) -> [Profile] {
        if let data = Storage.userDefaults().data(forKey: storageKey),
            let userProfiles = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Profile] {
                return userProfiles
        }
        return []
    }
    
    private static func storeInMemory(_ profiles: [Profile], storageKey: String) {
        Storage.userDefaults().set(self.storageVersion, forKey: versionKey)
        Storage.userDefaults().set(NSKeyedArchiver.archivedData(withRootObject: profiles), forKey: storageKey)
    }
    
    private static func removeSystemProfiles(in profiles: [Profile]) -> [Profile] {
        return profiles.filter({ $0.profileType != .system })
    }
    
    private static func systemProfilesPresent(in profiles: [Profile]) -> Bool {
        return !profiles.filter({ $0.profileType == .system }).isEmpty
    }
    
}
