//
//  AnnouncementStorageMock.swift
//  vpncore - Created on 2020-10-19.
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
//

#if DEBUG
import Foundation

public class AnnouncementStorageMock: AnnouncementStorage {
    public var announcements: [Announcement]
    
    public init(_ announcements: [Announcement] = []) {
        self.announcements = announcements
    }
    
    public func fetch() -> [Announcement] {
        return announcements
    }
    
    public func store(_ objects: [Announcement]) {
        self.announcements = objects
        NotificationCenter.default.post(name: AnnouncementStorageNotifications.contentChanged, object: objects)
    }

    public func clear() {
        announcements = []
    }
}

public class AnnouncementStorageFactoryMock: AnnouncementStorageFactory {
    public var announcementStorage: AnnouncementStorage
    
    public init(_ announcementStorage: AnnouncementStorage) {
        self.announcementStorage = announcementStorage
    }
    
    public func makeAnnouncementStorage() -> AnnouncementStorage {
        return self.announcementStorage
    }
}

extension Array where Element == Announcement {
    /// Helper for testing if array contains concrete Announcement
    public func containsAnnouncement(withId id: String) -> Bool {
        return self.contains(where: {
            $0.notificationID == id
        })
    }
}
#endif
