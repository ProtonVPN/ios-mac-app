//
//  AnnouncementRefresherImplementationTests.swift
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
import ProtonCoreNetworking
@testable import Announcement

class AnnouncementRefresherImplementationTests: XCTestCase {
    
    private var storage: AnnouncementStorageMock = AnnouncementStorageMock()

    override class func tearDown() {
        AnnouncementClient.testValue = AnnouncementClient {
            return .init(notifications: [])
        }
    }

    func testCallsAPIOnRefresh() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")

        AnnouncementClient.testValue = AnnouncementClient {
            expectationApiWasCalled.fulfill()
            return .init(notifications: [])
        }

        let factory = AnnouncementRefresherImplementationFactory(announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory)
        refresher.tryRefreshing()
        
        wait(for: [expectationApiWasCalled], timeout: 0.2)
    }
    
    func testDoNotRefreshTooOften() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")
        expectationApiWasCalled.expectedFulfillmentCount = 1
        expectationApiWasCalled.assertForOverFulfill = true
        
        let factory = AnnouncementRefresherImplementationFactory(announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory)

        AnnouncementClient.testValue = AnnouncementClient {
            expectationApiWasCalled.fulfill()
            return .init(notifications: [])
        }
        refresher.tryRefreshing()
        
        wait(for: [expectationApiWasCalled], timeout: 1)
        refresher.tryRefreshing()
    }
    
    func testRefreshesAfterMinTimePassed() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")
        expectationApiWasCalled.expectedFulfillmentCount = 2
        expectationApiWasCalled.assertForOverFulfill = true

        AnnouncementClient.testValue = AnnouncementClient {
            expectationApiWasCalled.fulfill()
            return .init(notifications: [])
        }
        let factory = AnnouncementRefresherImplementationFactory(announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory, refreshInterval: 0)
        refresher.tryRefreshing()
        refresher.tryRefreshing()
        
        wait(for: [expectationApiWasCalled], timeout: 0.2)
    }
    
    func testSavesNewAnnouncementsToStorage() {
        let storage: AnnouncementStorageMock = AnnouncementStorageMock()
        storage.store([
            Announcement(notificationID: "oldDefault", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.default.rawValue, offer: nil, reference: nil),
            Announcement(notificationID: "oldOneTime", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.oneTime.rawValue, offer: nil, reference: nil)
        ])

        AnnouncementClient.testValue = AnnouncementClient {
            return .init(notifications: [
                Announcement(
                    notificationID: "newDefault",
                    startTime: Date(),
                    endTime: Date(),
                    type: Announcement.NotificationType.default.rawValue,
                    offer: nil,
                    reference: nil
                ),
                Announcement(
                    notificationID: "newOneTime",
                    startTime: Date(),
                    endTime: Date(),
                    type: Announcement.NotificationType.oneTime.rawValue,
                    offer: nil,
                    reference: nil
                )
            ])
        }

        let factory = AnnouncementRefresherImplementationFactory(announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory, refreshInterval: 0)

        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldDefault"))
        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldOneTime"))
        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "newDefault"))
        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "newOneTime"))
        
        refresher.tryRefreshing()

        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "oldDefault"))
        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "oldOneTime"))
        XCTAssert(storage.fetch().containsAnnouncement(withId: "newDefault"))
        XCTAssert(storage.fetch().containsAnnouncement(withId: "newOneTime"))
    }
    
    func testDoesntSaveNewAnnouncementsToStorageOnError() {
        let storage: AnnouncementStorageMock = AnnouncementStorageMock()
        storage.store([
            Announcement(notificationID: "oldDefault", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.default.rawValue, offer: nil, reference: nil),
            Announcement(notificationID: "oldOneTime", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.oneTime.rawValue, offer: nil, reference: nil)]
        )

        AnnouncementClient.testValue = AnnouncementClient {
            throw ResponseError.unknownError
        }

        let factory = AnnouncementRefresherImplementationFactory(announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory, refreshInterval: 0)

        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldDefault"))
        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldOneTime"))
        XCTAssertEqual(storage.fetch().count, 2)
        
        refresher.tryRefreshing()

        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldDefault"))
        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldOneTime"))
        XCTAssertEqual(storage.fetch().count, 2)
    }
    
}

fileprivate class AnnouncementRefresherImplementationFactory: AnnouncementRefresherImplementation.Factory {
    
    public var announcementStorage: AnnouncementStorage
    
    public init(announcementStorage: AnnouncementStorage) {
        self.announcementStorage = announcementStorage
    }

    func makeAnnouncementStorage() -> AnnouncementStorage {
        return announcementStorage
    }
}
