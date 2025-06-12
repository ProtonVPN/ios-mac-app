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

@testable import Announcement
import Domain
import Foundation

public class AnnouncementStorageFactoryMock: AnnouncementStorageFactory {
    public var announcementStorage: AnnouncementStorage

    public init(_ announcementStorage: AnnouncementStorage) {
        self.announcementStorage = announcementStorage
    }

    public func makeAnnouncementStorage() -> AnnouncementStorage {
        announcementStorage
    }
}

extension [Announcement] {
    /// Helper for testing if array contains concrete Announcement
    public func containsAnnouncement(withId id: String) -> Bool {
        contains(where: {
            $0.notificationID == id
        })
    }
}
