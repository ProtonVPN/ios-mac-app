//
//  AnnouncementStorageUserDefaultsTests.swift
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

import XCTest
@testable import LegacyCommon

class AnnouncementStorageUserDefaultsTests: XCTestCase {
    
    private var storage: AnnouncementStorageUserDefaults!
    private var userDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
        
        storage = AnnouncementStorageUserDefaults(userDefaults: userDefaults, keyNameProvider: StaticKeyNameProvider())
    }
    
    override func tearDown() {
        super.tearDown()
        userDefaults.removePersistentDomain(forName: #file)
    }
    
    func testStoreAndFetchWorks() {
        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "id"))
        storage.store([Announcement.mock(id: "id")])
        userDefaults.synchronize()
        XCTAssert(storage.fetch().containsAnnouncement(withId: "id"))
    }
    
    func testStoringPreservesIsReadFlag() {
        var announcements = ["1", "2", "3"].map(Announcement.mock(id:))
        storage.store(announcements)
        
        XCTAssertFalse(announcements[0].wasRead)
        announcements[0].isRead = true
        storage.store(announcements)
        
        let announcementsRead = storage.fetch()
        XCTAssert(announcementsRead[0].wasRead)
    }
    
    func testNotificationIsFiredOnStore() {
        expectationNotificationFired = XCTestExpectation(description: "AnnouncementStorageNotifications.contentChanged was fired")
        NotificationCenter.default.addObserver(self, selector: #selector(notificationFired), name: AnnouncementStorageNotifications.contentChanged, object: nil)
        
        storage.store([])
        
        wait(for: [expectationNotificationFired], timeout: 0.2)
        NotificationCenter.default.removeObserver(self)
    }
    
    private var expectationNotificationFired: XCTestExpectation!
    
    @objc func notificationFired() {
        expectationNotificationFired.fulfill()
    }
    
}

fileprivate extension Announcement {
    static func mock(id: String) -> Self {
        Self(notificationID: id, startTime: Date(), endTime: Date(), type: Announcement.NotificationType.default.rawValue, offer: nil, reference: nil)
    }
}

fileprivate class StaticKeyNameProvider: KeyNameProvider {
    public var storageKey: String {
        return "announcements"
    }
}
