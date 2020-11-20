//
//  AnnouncementStorageUserDefaultsTests.swift
//  vpncore - Created on 2020-10-19.
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

import vpncore
import XCTest

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
        storage.store([Announcement(notificationID: "id", startTime: Date(), endTime: Date(), type: 0, offer: nil)])
        userDefaults.synchronize()
        XCTAssert(storage.fetch().containsAnnouncement(withId: "id"))
    }
    
    func testStoringPreservesIsReadFlag() {
        var announcements = [
            Announcement(notificationID: "1", startTime: Date(), endTime: Date(), type: 0, offer: nil),
            Announcement(notificationID: "2", startTime: Date(), endTime: Date(), type: 0, offer: nil),
            Announcement(notificationID: "3", startTime: Date(), endTime: Date(), type: 0, offer: nil),
        ]
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
        
        wait(for: [expectationNotificationFired], timeout:0.2)
        NotificationCenter.default.removeObserver(self)
    }
    
    private var expectationNotificationFired: XCTestExpectation!
    
    @objc func notificationFired() {
        expectationNotificationFired.fulfill()
    }
    
}

fileprivate class StaticKeyNameProvider: KeyNameProvider {
    public var storageKey: String {
        return "announcements"
    }
}
