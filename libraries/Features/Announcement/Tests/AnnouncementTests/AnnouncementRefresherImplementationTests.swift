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

@testable import Announcement
import Dependencies
import ProtonCoreNetworking
import Sharing
import VPNShared
import XCTest

final class AnnouncementRefresherImplementationTests: XCTestCase {
    override func invokeTest() {
        let suiteName = "AnnouncementRefresherImplementationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = MockAuthKeychain()
        keychain.setMockUsername("test-user")
        withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            super.invokeTest()
        }
    }

    override class func tearDown() {
        AnnouncementClient.testValue = AnnouncementClient {
            .init(notifications: [])
        }
    }

    private func seed(_ announcements: [Announcement]) {
        @Shared(.announcements) var stored: [Announcement]?
        $stored.withLock { $0 = announcements }
    }

    private func stored() -> [Announcement] {
        @Shared(.announcements) var stored: [Announcement]?
        return stored ?? []
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
        seed([
            Announcement(notificationID: "oldDefault", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.default.rawValue, offer: nil, reference: nil),
            Announcement(notificationID: "oldOneTime", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.oneTime.rawValue, offer: nil, reference: nil),
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
                    ),
                ])
            }
        } operation: {
            let refresher = AnnouncementRefresherImplementation(refreshInterval: 0)

            XCTAssert(stored().containsAnnouncement(withId: "oldDefault"))
            XCTAssert(stored().containsAnnouncement(withId: "oldOneTime"))
            XCTAssertFalse(stored().containsAnnouncement(withId: "newDefault"))
            XCTAssertFalse(stored().containsAnnouncement(withId: "newOneTime"))

            await refresher.tryRefreshingAsync()

            XCTAssertFalse(stored().containsAnnouncement(withId: "oldDefault"))
            XCTAssertFalse(stored().containsAnnouncement(withId: "oldOneTime"))
            XCTAssert(stored().containsAnnouncement(withId: "newDefault"))
            XCTAssert(stored().containsAnnouncement(withId: "newOneTime"))
        }
    }

    func testDoesntSaveNewAnnouncementsToStorageOnError() {
        seed([
            Announcement(notificationID: "oldDefault", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.default.rawValue, offer: nil, reference: nil),
            Announcement(notificationID: "oldOneTime", startTime: Date(), endTime: Date(), type: Announcement.NotificationType.oneTime.rawValue, offer: nil, reference: nil),
        ])

        AnnouncementClient.testValue = AnnouncementClient {
            throw CancellationError()
        }

        let refresher = AnnouncementRefresherImplementation(refreshInterval: 0)

        XCTAssert(stored().containsAnnouncement(withId: "oldDefault"))
        XCTAssert(stored().containsAnnouncement(withId: "oldOneTime"))
        XCTAssertEqual(stored().count, 2)

        refresher.tryRefreshing()

        XCTAssert(stored().containsAnnouncement(withId: "oldDefault"))
        XCTAssert(stored().containsAnnouncement(withId: "oldOneTime"))
        XCTAssertEqual(stored().count, 2)
    }
}
