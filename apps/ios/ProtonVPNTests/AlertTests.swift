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

import SwiftUI
import XCTest

import GSMessages

import PMLogger
import ProtonCoreAccountRecovery
import ProtonCoreNetworking
import ProtonCorePasswordChange

import LegacyCommon
import Modals
import VPNAppCore

@testable import ProtonVPN

private let windowService = WindowServiceMock()
private let uiAlertService = IosUiAlertService(windowService: windowService)

class AlertTests: XCTestCase {
    let alertService = IosAlertService(IosAlertServiceFactoryMock())

    override func setUp() {
        super.setUp()
        windowService.displayCount = 0
    }

    func testSingleInstanceOfAlerts() {
        XCTAssertEqual(windowService.displayCount, 0)

        alertService.push(alert: MITMAlert())
        XCTAssertEqual(windowService.displayCount, 1)

        alertService.push(alert: MITMAlert())
        XCTAssertEqual(windowService.displayCount, 1)

        alertService.push(alert: AppUpdateRequiredAlert(ResponseError.unknownError))
        XCTAssertEqual(windowService.displayCount, 2)

        alertService.push(alert: AppUpdateRequiredAlert(ResponseError.unknownError))
        XCTAssertEqual(windowService.displayCount, 2)
    }

    func testUpdatingAlertCompletionHandlers() {
        XCTAssertEqual(windowService.displayCount, 0)

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
        XCTAssertEqual(windowService.displayCount, 1)

        alertService.push(alert: alert2)
        XCTAssertEqual(windowService.displayCount, 1)

        alert1.actions[0].handler?()
        alert1.actions[1].handler?()

        XCTAssert(confirmRan && cancelRan)
    }
}

private class WindowServiceMock: WindowService {
    var displayCount = 0

    func show(viewController _: UIViewController) {}
    func addToStack(_: UIViewController, checkForDuplicates _: Bool) {}
    func dismissModal(_: (() -> Void)?) {}

    func present(modal _: UIViewController) {
        displayCount += 1
    }

    func present(message _: String, type _: PresentedMessageType, accessibilityIdentifier _: String?) {}

    func popStackToRoot() {}

    var topmostPresentedViewController: UIViewController?
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

    func makeWindowService() -> WindowService {
        windowService
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

    func makeSettingsViewController() -> SettingsViewController? {
        nil
    }

    func makeSettingsAccountViewController() -> SettingsAccountViewController? {
        nil
    }

    func makeHermesSettingsViewController(viewModel _: HermesSettingsViewModel) -> HermesSettingsViewController {
        fatalError("Not implemented")
    }

    func makeTelemetrySettingsViewController() -> TelemetrySettingsViewController {
        TelemetrySettingsViewController(
            preferenceChangeUsageData: { _ in },
            preferenceChangeCrashReports: { _ in },
            usageStatisticsOn: { true },
            crashReportsOn: { true }
        )
    }

    func makeExtensionsSettingsViewController() -> UIViewController {
        let viewModel = WidgetSettingsViewModel()
        return WidgetSettingsViewController(viewModel: viewModel)
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
