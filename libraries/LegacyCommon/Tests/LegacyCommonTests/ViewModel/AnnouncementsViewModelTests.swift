//
//  AnnouncementsViewModelTests.swift
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

@testable import LegacyCommon
import XCTest
import VPNShared
import Domain

class AnnouncementsViewModelTests: XCTestCase {
    
    private var storage: AnnouncementStorage!
    private var manager: AnnouncementManager!
    private var viewModel: AnnouncementsViewModel!
    private var safariService: SafariServiceMock!
    private var propertiesManager: PropertiesManagerMock!
    
    override func setUp() {
        super.setUp()
        
        storage = AnnouncementStorageMock()
        manager = AnnouncementManagerImplementation(factory: AnnouncementManagerImplementationFactoryMock(announcementStorage: storage))
        safariService = SafariServiceMock()
        propertiesManager = PropertiesManagerMock()
        viewModel = AnnouncementsViewModel(factory: AnnouncementsViewModelFactoryMock(announcementManager: manager, propertiesManager: propertiesManager, safariService: safariService, coreAlertService: CoreAlertServiceDummy(), appInfo: AppInfoImplementation()))
        
    }
    
    // public func open(announcement: Announcement)
    
    func testTakesDataFromTheStorage() {
        XCTAssert(viewModel.items.isEmpty)
        
        storage.store([.mock])
        
        XCTAssert(viewModel.items.count == 1)
    }
    
    func testRefreshesView() {
        let expectationViewRefreshed = XCTestExpectation(description: "Views was asked to refresh itself")
        viewModel.refreshView = {
            expectationViewRefreshed.fulfill()
        }
        
        storage.store([.mock])
        
        wait(for: [expectationViewRefreshed], timeout: 0.2)
    }
}

fileprivate class AnnouncementsViewModelFactoryMock: AnnouncementsViewModel.Factory {
    public let announcementManager: AnnouncementManager
    public let propertiesManager: PropertiesManagerProtocol
    public let safariService: SafariServiceProtocol
    public let coreAlertService: CoreAlertService
    public let appInfo: AppInfo
    
    init(announcementManager: AnnouncementManager, propertiesManager: PropertiesManagerProtocol, safariService: SafariServiceProtocol, coreAlertService: CoreAlertService, appInfo: AppInfo) {
        self.announcementManager = announcementManager
        self.propertiesManager = propertiesManager
        self.safariService = safariService
        self.coreAlertService = coreAlertService
        self.appInfo = appInfo
    }

    func makeAnnouncementManager() -> AnnouncementManager {
        return announcementManager
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }
    
    func makeSafariService() -> SafariServiceProtocol {
        return safariService
    }

    func makeCoreAlertService() -> CoreAlertService {
        return coreAlertService
    }

    func makeAppInfo(context: AppContext) -> AppInfo {
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

fileprivate extension Announcement {
    static let mock: Self = .init(
        notificationID: "1",
        startTime: Date(),
        endTime: Date(timeIntervalSinceNow: 888),
        type: Announcement.NotificationType.default.rawValue,
        offer: .empty,
        reference: nil
    )
}
