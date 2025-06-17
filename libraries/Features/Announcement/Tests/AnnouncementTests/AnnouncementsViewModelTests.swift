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

import VPNAppCore
import VPNShared
import XCTest

import Dependencies
import Domain

@testable import Announcement
@testable import LegacyCommon
@testable import VPNSharedTesting

class AnnouncementsViewModelTests: XCTestCase {
//    private var manager: AnnouncementManager!
    private var viewModel: AnnouncementsViewModel!
    private var propertiesManager: PropertiesManagerMock!

    @Dependency(\.announcementStorage) var storage

    override func setUp() {
        super.setUp()
        propertiesManager = PropertiesManagerMock()
        viewModel = AnnouncementsViewModel(factory: AnnouncementsViewModelFactoryMock(propertiesManager: propertiesManager, coreAlertService: CoreAlertServiceDummy(), appInfo: AppInfoImplementation()))
        storage.store([])
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

        @Dependency(\.announcementStorage) var storage
        storage.store([.mock])

        wait(for: [expectationViewRefreshed], timeout: 0.2)
    }
}

private class AnnouncementsViewModelFactoryMock: AnnouncementsViewModel.Factory {
    public let propertiesManager: PropertiesManagerProtocol
    public let coreAlertService: CoreAlertService
    public let appInfo: AppInfo

    @Dependency(\.announcementManager) var announcementManager: AnnouncementManager

    init(propertiesManager: PropertiesManagerProtocol, coreAlertService: CoreAlertService, appInfo: AppInfo) {
        self.propertiesManager = propertiesManager
        self.coreAlertService = coreAlertService
        self.appInfo = appInfo
    }

    func makeAnnouncementManager() -> AnnouncementManager {
        announcementManager
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        propertiesManager
    }

    func makeCoreAlertService() -> CoreAlertService {
        coreAlertService
    }

    func makeAppInfo(context: AppContext) -> AppInfo {
        AppInfoImplementation(context: context)
    }
}

private extension Announcement {
    static let mock: Self = .init(
        notificationID: "1",
        startTime: Date(),
        endTime: Date(timeIntervalSinceNow: 888),
        type: Announcement.NotificationType.default.rawValue,
        offer: .empty,
        reference: nil
    )
}
