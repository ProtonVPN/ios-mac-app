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

import XCTest
import GSMessages
@testable import vpncore

@testable import ProtonVPN

fileprivate let sessionService = SessionServiceMock()
fileprivate let windowService = WindowServiceMock()
fileprivate let uiAlertService = IosUiAlertService(windowService: windowService, planService: nil)

class AlertTests: XCTestCase {

    let alertService = IosAlertService(IosAlertServiceFactoryMock())
    
    override func setUp() {
        windowService.displayCount = 0
    }

    func testSingleInstanceOfAlerts() {
        XCTAssert(windowService.displayCount == 0)
        
        alertService.push(alert: MITMAlert())
        XCTAssert(windowService.displayCount == 1)
        
        alertService.push(alert: MITMAlert())
        XCTAssert(windowService.displayCount == 1)
        
        alertService.push(alert: AppUpdateRequiredAlert(ApiError.unknownError))
        XCTAssert(windowService.displayCount == 2)
        
        alertService.push(alert: AppUpdateRequiredAlert(ApiError.unknownError))
        XCTAssert(windowService.displayCount == 2)
    }
    
    func testUpdatingAlertCompletionHandlers() {
        XCTAssert(windowService.displayCount == 0)
        
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
        XCTAssert(windowService.displayCount == 1)
        
        alertService.push(alert: alert2)
        XCTAssert(windowService.displayCount == 1)
        
        alert1.actions[0].handler?()
        alert1.actions[1].handler?()
        
        XCTAssert(confirmRan && cancelRan)
    }
    
}

fileprivate class WindowServiceMock: WindowService {
    var displayCount = 0
    
    func show(viewController: UIViewController) {}
    func addToStack(_ controller: UIViewController, checkForDuplicates: Bool) {}
    func present(modal: UIViewController) {}
    func dismissModal(_ completion: (() -> Void)?) {}
    
    func present(alert: UIAlertController) {
        displayCount += 1
    }
    
    func present(message: String, type: PresentedMessageType, accessibilityIdentifier: String?) {
    }
    
    func popStackToRoot() {
    
    }
    
    var navigationStackAvailable: Bool = true
    var topmostPresentedViewController: UIViewController?
}

fileprivate class IosAlertServiceFactoryMock: IosAlertService.Factory {
    func makeSessionService() -> SessionService {
        return sessionService
    }
    
    func makeUIAlertService() -> UIAlertService {
        return uiAlertService
    }
    
    func makeAppSessionManager() -> AppSessionManager {
        return AppSessionManagerMock(sessionStatus: .established, loggedIn: true, sessionChanged: Notification.Name(rawValue: ""))
    }
    
    func makeWindowService() -> WindowService {
        return windowService
    }
    
    func makeSettingsService() -> SettingsService {
        return SettingsServiceMock()
    }
    
    func makeTroubleshootCoordinator() -> TroubleshootCoordinator {
        return TroubleshootCoordinatorMock();
    }

    func makeSafariService() -> SafariServiceProtocol {
        return SafariService()
    }

    func makePlanService() -> PlanService {
        return PlanServiceMock()
    }
}

fileprivate class SettingsServiceMock: SettingsService {
    func makeLogSelectionViewController() -> LogSelectionViewController {
        let viewModel = LogSelectionViewModel()
        return LogSelectionViewController(viewModel: viewModel, settingsService: self)
    }
    
    func makeLogsViewController(logSource: LogSource) -> LogsViewController {
        return LogsViewController(viewModel: LogsViewModel(title: "Test title", logContent: LogContentMock(isEmpty: false)))
    }
    
    func makeSettingsViewController() -> SettingsViewController? {
        return nil
    }
    
    func makeSettingsAccountViewController() -> SettingsAccountViewController? {
        return nil
    }
    
    func makeExtensionsSettingsViewController() -> WidgetSettingsViewController {
        let viewModel = WidgetSettingsViewModel()
        return WidgetSettingsViewController(viewModel: viewModel)
    }
    
    func presentLogs() {}
    func presentReportBug() {}
    
    func makeBatteryUsageViewController() -> BatteryUsageViewController {
        return BatteryUsageViewController()
    }
}

fileprivate class LogContentMock: LogContent {
    var isEmpty: Bool

    init(isEmpty: Bool) {
        self.isEmpty = isEmpty
    }

    func loadContent(callback: @escaping (String) -> Void) {
        callback("")
    }
}
