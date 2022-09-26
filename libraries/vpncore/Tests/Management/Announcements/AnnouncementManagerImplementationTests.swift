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
@testable import vpncore

extension Offer {
    static let empty: Offer = Offer(label: "", url: "", action: nil, behaviors: nil, icon: "", panel: nil)
}

class AnnouncementManagerImplementationTests: XCTestCase {

    private var storage: AnnouncementStorageMock = AnnouncementStorageMock()
    private var manager: AnnouncementManagerImplementation!
    
    override func setUp() {
        super.setUp()
        
        storage.store([
            Announcement(notificationID: "1-no-offer",
                         startTime: Date(),
                         endTime: .distantFuture,
                         type: .default,
                         offer: nil),
            Announcement(notificationID: "2-with-offer",
                         startTime: Date(),
                         endTime: .distantFuture,
                         type: .default,
                         offer: Offer.empty),
            Announcement(notificationID: "2-with-offer-one-time",
                         startTime: Date(),
                         endTime: .distantFuture,
                         type: .oneTime,
                         offer: Offer.empty),
            Announcement(notificationID: "3-ended",
                         startTime: Date(),
                         endTime: .distantPast,
                         type: .default,
                         offer: Offer.empty),
            Announcement(notificationID: "3-future",
                         startTime: .distantFuture,
                         endTime: .distantFuture,
                         type: .default,
                         offer: Offer.empty),
        ])
        
        manager = AnnouncementManagerImplementation(factory: AnnouncementStorageFactoryMock(storage))
    }
    
    func testFetchesOnlyCurrentNotifications(){
        let filtered = manager.fetchCurrentAnnouncements()
        XCTAssert(filtered.containsAnnouncement(withId: "2-with-offer"))
        XCTAssert(filtered.containsAnnouncement(withId: "2-with-offer-one-time"))
        XCTAssertEqual(filtered.count, 2)
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

    func testDistinguishesWhenUnreadAnnsArePresent() {
        XCTAssert(manager.hasUnreadAnnouncements)
        let announcements = manager.fetchCurrentAnnouncements()
        announcements.forEach {
            manager.markAsRead(announcement: $0)
        }
        XCTAssertFalse(manager.hasUnreadAnnouncements)
    }

    func testDistinguishesWhenUnreadOneTimeAnnouncementsArePresent() {
        XCTAssert(manager.hasUnreadOneTimeAnnouncements)
        let announcements = manager.fetchCurrentAnnouncements()
        announcements.forEach {
            manager.markAsRead(announcement: $0)
        }
        XCTAssertFalse(manager.hasUnreadOneTimeAnnouncements)
    }
    
}
