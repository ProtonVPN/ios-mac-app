//
//  AnnouncementManagerTests.swift
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

class AnnouncementManagerImplementationTests: XCTestCase {

    private var storage: AnnouncementStorageMock = AnnouncementStorageMock()
    private var manager: AnnouncementManagerImplementation!
    
    override func setUp() {
        super.setUp()
        
        storage.store([
            Announcement(notificationID: "1-no-offer", startTime: Date(), endTime: Date(timeIntervalSinceNow: 888), type: 0, offer: nil),
            Announcement(notificationID: "2-with-offer", startTime: Date(), endTime: Date(timeIntervalSinceNow: 888), type: 0, offer: Offer(label: "", url: "", icon: "")),
            Announcement(notificationID: "3-ended", startTime: Date(), endTime: Date(timeIntervalSinceNow: -1), type: 0, offer: Offer(label: "", url: "", icon: "")),
            Announcement(notificationID: "3-future", startTime: Date(timeIntervalSinceNow: 888), endTime: Date(timeIntervalSinceNow: 8889), type: 0, offer: Offer(label: "", url: "", icon: "")),
        ])
        
        manager = AnnouncementManagerImplementation(factory: AnnouncementStorageFactoryMock(storage))
    }
    
    func testFetchesOnlyCurrentNotifications(){
        let filtered = manager.fetchCurrentAnnouncements()
        XCTAssert(filtered.containsAnnouncement(withId: "2-with-offer"))
        XCTAssertFalse(filtered.containsAnnouncement(withId: "1-no-offer"))
        XCTAssertFalse(filtered.containsAnnouncement(withId: "3-ended"))
        XCTAssertFalse(filtered.containsAnnouncement(withId: "3-future"))
    }
    
    func testMarksAsRead() {
        let announcement = manager.fetchCurrentAnnouncements()[0]
        XCTAssertFalse(announcement.wasRead)
        manager.markAsRead(announcement: announcement)
        let announcement2 = manager.fetchCurrentAnnouncements()[0]
        XCTAssert(announcement2.wasRead)
    }
    
    func testDistinguoshesWhenUnreadAnnsArePresent() {
        XCTAssert(manager.hasUnreadAnnouncements)
        let announcements = manager.fetchCurrentAnnouncements()
        announcements.forEach {
            manager.markAsRead(announcement: $0)
        }
        XCTAssertFalse(manager.hasUnreadAnnouncements)
    }
    
}
