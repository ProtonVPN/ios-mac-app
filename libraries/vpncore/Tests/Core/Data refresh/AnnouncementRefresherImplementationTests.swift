//
//  AnnouncementRefresherImplementationTests.swift
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

import XCTest

class AnnouncementRefresherImplementationTests: XCTestCase {
    
    private var storage: AnnouncementStorageMock = AnnouncementStorageMock()
    
    override func setUp() {
        super.setUp()
        
    }
    
    func testCallsAPIOnRefresh() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")
        
        let coreApiService = CoreApiServiceMock()
        coreApiService.callbackGetApiNotificationsCallback = { success, failure in
            expectationApiWasCalled.fulfill()
        }
        let factory = AnnouncementRefresherImplementationFactory(coreApiService: coreApiService, announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory)
        refresher.refresh()
        
        wait(for: [expectationApiWasCalled], timeout:0.2)
    }
    
    func testDoesntRefreshTooOfter() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")
        expectationApiWasCalled.expectedFulfillmentCount = 1
        expectationApiWasCalled.assertForOverFulfill = true
        
        let coreApiService = CoreApiServiceMock()
        coreApiService.callbackGetApiNotificationsCallback = { success, failure in
            expectationApiWasCalled.fulfill()
        }
        let factory = AnnouncementRefresherImplementationFactory(coreApiService: coreApiService, announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory, minRefreshTime: 888)
        refresher.refresh()
        refresher.refresh()
        
        wait(for: [expectationApiWasCalled], timeout:0.2)
    }
    
    func testRefreshesAfterMinTimePassed() {
        let expectationApiWasCalled = XCTestExpectation(description: "API was called")
        expectationApiWasCalled.expectedFulfillmentCount = 2
        expectationApiWasCalled.assertForOverFulfill = true
        
        let coreApiService = CoreApiServiceMock()
        coreApiService.callbackGetApiNotificationsCallback = { success, failure in
            expectationApiWasCalled.fulfill()
        }
        let factory = AnnouncementRefresherImplementationFactory(coreApiService: coreApiService, announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory, minRefreshTime: 0)
        refresher.refresh()
        refresher.refresh()
        
        wait(for: [expectationApiWasCalled], timeout:0.2)
    }
    
    func testSavesNewAnnouncementsToStorage() {
        let storage: AnnouncementStorageMock = AnnouncementStorageMock()
        storage.store([Announcement(notificationID: "old", startTime: Date(), endTime: Date(), type: 0, offer: nil)])
        
        let coreApiService = CoreApiServiceMock()
        coreApiService.callbackGetApiNotificationsCallback = { success, failure in
            success(GetApiNotificationsResponse(notifications: [Announcement(notificationID: "new", startTime: Date(), endTime: Date(), type: 0, offer: nil)]))
        }
        let factory = AnnouncementRefresherImplementationFactory(coreApiService: coreApiService, announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory, minRefreshTime: 0)
        
        XCTAssert(storage.fetch().containsAnnouncement(withId: "old"))
        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "new"))
        
        refresher.refresh()
        
        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "old"))
        XCTAssert(storage.fetch().containsAnnouncement(withId: "new"))
    }
    
    func testDoesntNewAnnouncementsToStorageOnError() {
        let storage: AnnouncementStorageMock = AnnouncementStorageMock()
        storage.store([Announcement(notificationID: "old", startTime: Date(), endTime: Date(), type: 0, offer: nil)])
        
        let coreApiService = CoreApiServiceMock()
        coreApiService.callbackGetApiNotificationsCallback = { success, failure in
            failure(ApiError.unknownError)
        }
        let factory = AnnouncementRefresherImplementationFactory(coreApiService: coreApiService, announcementStorage: storage)
        let refresher = AnnouncementRefresherImplementation(factory: factory, minRefreshTime: 0)
        
        XCTAssert(storage.fetch().containsAnnouncement(withId: "old"))
        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "new"))
        
        refresher.refresh()
        
        XCTAssert(storage.fetch().containsAnnouncement(withId: "old"))
        XCTAssertFalse(storage.fetch().containsAnnouncement(withId: "new"))
    }
    
}


fileprivate class AnnouncementRefresherImplementationFactory: AnnouncementRefresherImplementation.Factory {
    
    public var coreApiService: CoreApiService
    public var announcementStorage: AnnouncementStorage
    
    public init(coreApiService: CoreApiService, announcementStorage: AnnouncementStorage) {
        self.coreApiService = coreApiService
        self.announcementStorage = announcementStorage
    }
    
    func makeCoreApiService() -> CoreApiService {
        return coreApiService
    }
    
    func makeAnnouncementStorage() -> AnnouncementStorage {
        return announcementStorage
    }
    
    
}
