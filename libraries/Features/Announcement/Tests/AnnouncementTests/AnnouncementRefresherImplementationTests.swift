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
import Dependencies
import ProtonCoreNetworking
@testable import Announcement

class AnnouncementRefresherImplementationTests: XCTestCase {
    @Dependency(\.announcementStorage) var storage

    override class func tearDown() {
        AnnouncementClient.testValue = AnnouncementClient {
            .init(notifications: [])
        }
    }

    func testCallsAPIOnRefresh() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")

        AnnouncementClient.testValue = AnnouncementClient {
            expectationApiWasCalled.fulfill()
            return .init(notifications: [])
        }

        let refresher = AnnouncementRefresherImplementation()
        refresher.tryRefreshing()

        wait(for: [expectationApiWasCalled], timeout: 0.2)
    }

    func testDoNotRefreshTooOften() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")
        expectationApiWasCalled.expectedFulfillmentCount = 1
        expectationApiWasCalled.assertForOverFulfill = true

        withDependencies {
            $0.announcementClient = .init {
                expectationApiWasCalled.fulfill()
                return .init(notifications: [])
            }
        } operation: {
            let refresher = AnnouncementRefresherImplementation()

            refresher.tryRefreshing()

            wait(for: [expectationApiWasCalled], timeout: 1)
            refresher.tryRefreshing()
        }
    }

    func testRefreshesAfterMinTimePassed() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")
        expectationApiWasCalled.expectedFulfillmentCount = 2
        expectationApiWasCalled.assertForOverFulfill = true

        AnnouncementClient.testValue = AnnouncementClient {
            expectationApiWasCalled.fulfill()
            return .init(notifications: [])
        }
        let refresher = AnnouncementRefresherImplementation(refreshInterval: 0)
        refresher.tryRefreshing()
        refresher.tryRefreshing()

        wait(for: [expectationApiWasCalled], timeout: 0.2)
    }

    func testSavesNewAnnouncementsToStorage() async {
        storage.store([
            Announcement(notificationID: "oldDefault", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.default.rawValue, offer: nil, reference: nil),
            Announcement(notificationID: "oldOneTime", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.oneTime.rawValue, offer: nil, reference: nil)
        ])

        await withDependencies {
            $0.announcementClient = AnnouncementClient {
                .init(notifications: [
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
        } operation: {
            let refresher = AnnouncementRefresherImplementation(refreshInterval: 0)

            XCTAssert(storage.fetch().containsAnnouncement(withId: "oldDefault"))
            XCTAssert(storage.fetch().containsAnnouncement(withId: "oldOneTime"))
            XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "newDefault"))
            XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "newOneTime"))

            await refresher.tryRefreshingAsync()

            XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "oldDefault"))
            XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "oldOneTime"))
            XCTAssert(storage.fetch().containsAnnouncement(withId: "newDefault"))
            XCTAssert(storage.fetch().containsAnnouncement(withId: "newOneTime"))
        }
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

        let refresher = AnnouncementRefresherImplementation(refreshInterval: 0)

        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldDefault"))
        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldOneTime"))
        XCTAssertEqual(storage.fetch().count, 2)

        refresher.tryRefreshing()

        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldDefault"))
        XCTAssert(storage.fetch().containsAnnouncement(withId: "oldOneTime"))
        XCTAssertEqual(storage.fetch().count, 2)
    }
}
