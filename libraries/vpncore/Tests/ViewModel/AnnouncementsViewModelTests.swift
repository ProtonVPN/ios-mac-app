//
//  AnnouncementsViewModelTests.swift
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

@testable import vpncore
import XCTest
import VPNShared

class AnnouncementsViewModelTests: XCTestCase {
    
    private var storage: AnnouncementStorage!
    private var manager: AnnouncementManager!
    private var viewModel: AnnouncementsViewModel!
    private var safariService: SafariServiceMock!
    
    override func setUp() {
        super.setUp()
        
        storage = AnnouncementStorageMock()
        manager = AnnouncementManagerImplementation(factory: AnnouncementManagerImplementationFactoryMock(announcementStorage: storage))
        safariService = SafariServiceMock()
        viewModel = AnnouncementsViewModel(factory: AnnouncementsViewModelFactoryMock(announcementManager: manager, safariService: safariService, coreAlertService: CoreAlertServiceMock(), appInfo: AppInfoImplementation(context: .mainApp)))
        
    }
    
    // public func open(announcement: Announcement)
    
    
    func testTakesDataFromTheStorage(){
        XCTAssert(viewModel.items.count == 0)
        
        storage.store([Announcement(notificationID: "1", startTime: Date(), endTime: Date(timeIntervalSinceNow: 888), type: .default, offer: .empty)])
        
        XCTAssert(viewModel.items.count == 1)
    }
    
    func testRefreshesView(){
        let expectationViewRefreshed = XCTestExpectation(description: "Views was asked to refresh itself")
        viewModel.refreshView = {
            expectationViewRefreshed.fulfill()
        }
        
        storage.store([Announcement(notificationID: "1", startTime: Date(), endTime: Date(timeIntervalSinceNow: 888), type: .default, offer: .empty)])
        
        wait(for: [expectationViewRefreshed], timeout:0.2)
    }
}

fileprivate class AnnouncementsViewModelFactoryMock: AnnouncementsViewModel.Factory {

    public let announcementManager: AnnouncementManager
    public let safariService: SafariServiceProtocol
    public let coreAlertService: CoreAlertService
    public let appInfo: AppInfo
    
    init(announcementManager: AnnouncementManager, safariService: SafariServiceProtocol, coreAlertService: CoreAlertService, appInfo: AppInfo) {
        self.announcementManager = announcementManager
        self.safariService = safariService
        self.coreAlertService = coreAlertService
        self.appInfo = appInfo
    }
    
    func makeAnnouncementManager() -> AnnouncementManager {
        return announcementManager
    }
    
    func makeSafariService() -> SafariServiceProtocol {
        return safariService
    }

    func makeCoreAlertService() -> CoreAlertService {
        return coreAlertService
    }

    func makeAppInfo(context: AppContext) -> AppInfo {
        if appInfo.context == context {
            return appInfo
        }
        return AppInfoImplementation(context: context)
    }
}

fileprivate class AnnouncementManagerImplementationFactoryMock: AnnouncementManagerImplementation.Factory {
    
    private var announcementStorage: AnnouncementStorage
    
    init(announcementStorage: AnnouncementStorage) {
        self.announcementStorage = announcementStorage
    }
    
    func makeAnnouncementStorage() -> AnnouncementStorage {
        return announcementStorage
    }
}
