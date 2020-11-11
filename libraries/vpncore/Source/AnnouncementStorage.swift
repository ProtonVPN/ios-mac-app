//
//  AnnouncementStorage.swift
//  vpncore - Created on 2020-10-07.
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
//

import Foundation

public protocol AnnouncementStorage {
    func fetch() -> [Announcement]
    func store(_ objects: [Announcement])
}

public protocol AnnouncementStorageFactory {
    func makeAnnouncementStorage() -> AnnouncementStorage
}

public struct AnnouncementStorageNotifications {
    public static let contentChanged = Notification.Name("AnnouncementStorage_ContentChanged")
}

public class AnnouncementStorageUserDefaults: AnnouncementStorage {
    
    let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    public func fetch() -> [Announcement] {
        guard let data = userDefaults.data(forKey: storageKey),
              let result = try? JSONDecoder().decode([Announcement].self, from: data) else {
                return []
        }
        return result
    }
    
    public func store(_ objects: [Announcement]) {
        // Read and apply isRead flags from current objects
        let current = fetch().reduce(into: [String: Bool]()) { result, element in
            result[element.notificationID] = element.isRead
        }
        let objectsWithReadFlag: [Announcement] = objects.map {
            var announcement = $0
            announcement.setAsRead((current[$0.notificationID] ?? false) || $0.wasRead)
            return announcement
        }
        // Save
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(objectsWithReadFlag)
            userDefaults.set(jsonData, forKey: storageKey)
            DispatchQueue.main.async { NotificationCenter.default.post(name: AnnouncementStorageNotifications.contentChanged, object: objects) }
        } catch let error {
            PMLog.ET(error)
        }
    }
 
    // MARK: - Private
    
    var storageKey: String {
        return "announcements_" + (AuthKeychain.fetch()?.username ?? "")
    }
    
}
