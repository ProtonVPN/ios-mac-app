//
//  AlertTests.swift
//  ProtonVPN - Created on 07.11.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Dependencies
import GSMessages
import SwiftUI
import XCTest

import ProtonCoreAccountRecovery
import ProtonCoreNetworking
import ProtonCorePasswordChange

import LegacyCommon
import Modals
import PMLogger
import VPNAppCore

import Home
@testable import ios_app

private let uiAlertService = IosUiAlertService()

class AlertTests: XCTestCase {
    let alertService = IosAlertService(IosAlertServiceFactoryMock())
    var displayCount = 0

    override func invokeTest() {
        displayCount = 0
        withDependencies {
            $0.windowService.present = { _ in
                self.displayCount += 1
            }
        } operation: {
            super.invokeTest()
        }
    }

    override func setUp() {
        super.setUp()
        displayCount = 0
    }

    func testSingleInstanceOfAlerts() {
        XCTAssertEqual(displayCount, 0)

        alertService.push(alert: MITMAlert())
        XCTAssertEqual(displayCount, 1)

        alertService.push(alert: MITMAlert())
        XCTAssertEqual(displayCount, 1)

        alertService.push(alert: AppUpdateRequiredAlert(ResponseError.unknownError))
        XCTAssertEqual(displayCount, 2)

        alertService.push(alert: AppUpdateRequiredAlert(ResponseError.unknownError))
        XCTAssertEqual(displayCount, 2)
    }

    func testUpdatingAlertCompletionHandlers() {
        XCTAssertEqual(displayCount, 0)

        let confirmationHandler1 = {
            XCTFail("Shouldn't reach here")
        }
        let cancellationHandler1 = {
            XCTFail("Shouldn't reach here")
        }

        var confirmRan = false
        var cancelRan = false
        let confirmationHandler2 = {
            confirmRan = true
        }
        let cancellationHandler2 = {
            cancelRan = true
        }

        let alert1 = SecureCoreToggleDisconnectAlert(confirmHandler: confirmationHandler1, cancelHandler: cancellationHandler1)
        let alert2 = SecureCoreToggleDisconnectAlert(confirmHandler: confirmationHandler2, cancelHandler: cancellationHandler2)

        alertService.push(alert: alert1)
        XCTAssertEqual(displayCount, 1)

        alertService.push(alert: alert2)
        XCTAssertEqual(displayCount, 1)

        alert1.actions[0].handler?()
        alert1.actions[1].handler?()

        XCTAssert(confirmRan && cancelRan)
    }
}

private class IosAlertServiceFactoryMock: IosAlertService.Factory {
    func makeNavigationService() -> NavigationService {
        NavigationService(DependencyContainer())
    }

    func makeUIAlertService() -> UIAlertService {
        uiAlertService
    }

    func makeAppSessionManager() -> AppSessionManager {
        AppSessionManagerMock(
            sessionStatus: .established,
            loggedIn: true,
            sessionChanged: Notification.Name(rawValue: ""),
            vpnGateway: VpnGatewayMock()
        )
    }

    func makeSettingsService() -> SettingsService {
        SettingsServiceMock()
    }

    func makeTroubleshootCoordinator() -> TroubleshootCoordinator {
        TroubleshootCoordinatorMock()
    }

    func makePlanService() -> PlanService {
        PlanServiceMock()
    }
}

private class SettingsServiceMock: SettingsService {
    func makeLogSelectionViewController() -> LogSelectionViewController {
        let viewModel = LogSelectionViewModel()
        return LogSelectionViewController(viewModel: viewModel, settingsService: self)
    }

    func makeLogsViewController(logSource _: LogSource) -> LogsViewController {
        LogsViewController(viewModel: LogsViewModel(title: "Test title", logContent: LogContentMock(isEmpty: false)))
    }

    func makeSettingsViewController() -> SettingsViewController {
        fatalError("Not implemented")
    }

    func makeSettingsAccountViewController() -> SettingsAccountViewController? {
        nil
    }

    func makeHermesSettingsViewController(viewModel _: HermesSettingsViewModel) -> HermesSettingsViewController {
        fatalError("Not implemented")
    }

    func makeExtensionsSettingsViewController() -> UIViewController {
        UIHostingController(rootView: WidgetSettingsView())
    }

    func presentLogs() {}
    func presentReportBug() {}

    func makeAccountRecoveryViewController() -> AccountRecoveryViewController {
        let viewModel = AccountRecoveryView.ViewModel()
        return UIHostingController(rootView: AccountRecoveryView(viewModel: viewModel))
    }

    func makePasswordChangeViewController(mode _: PasswordChangeModule.PasswordChangeMode) -> PasswordChangeViewController? {
        nil
    }
}

private class LogContentMock: LogContent {
    var isEmpty: Bool

    init(isEmpty: Bool) {
        self.isEmpty = isEmpty
    }

    func loadContent(callback: @escaping (String) -> Void) {
        callback("")
    }
}
