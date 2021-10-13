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
import vpncore

@testable import ProtonVPN

fileprivate let windowService = WindowServiceMock()
fileprivate let uiAlertService = IosUiAlertService(windowService: windowService, navigationService: nil)

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
        
        alertService.push(alert: CannotAccessVpnCredentialsAlert(confirmHandler: nil))
        XCTAssert(windowService.displayCount == 2)
        
        alertService.push(alert: CannotAccessVpnCredentialsAlert(confirmHandler: nil))
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
    func replace(with modal: UIViewController) {}
    func dismissModal() {}
    
    func present(alert: UIAlertController) {
        displayCount += 1
    }
    
    func present(message: String, type: PresentedMessageType, accessibilityIdentifier: String?) {
    }
    
    func popStackToRoot() {
    
    }
    
    var navigationStackAvailable: Bool = true
}

fileprivate class IosAlertServiceFactoryMock: IosAlertService.Factory {
    
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
}

fileprivate class CustomServersViewModelFactoryMock: CustomServersViewModel.Factory {
    func makePropertiesManager() -> PropertiesManagerProtocol {
        return PropertiesManagerMock()
    }
}

fileprivate class SettingsServiceMock: SettingsService {
    func makeLogSelectionViewController() -> LogSelectionViewController {
        let viewModel = LogSelectionViewModel(logFileProvider: MockLogFilesProvider())
        return LogSelectionViewController(viewModel: viewModel, settingsService: self)
    }
    
    func makeLogsViewController(viewModel: LogsViewModel) -> LogsViewController {
        let viewModel = LogsViewModel(title: "", logFile: URL(fileURLWithPath: ""))
        return LogsViewController(viewModel: viewModel)
    }
    
    func makeCustomServerViewController() -> CustomServersViewController {
        let viewModel = CustomServersViewModel(factory: CustomServersViewModelFactoryMock(), vpnGateway: nil)
        return CustomServersViewController(viewModel: viewModel)
    }
    
    func makeSettingsViewController() -> SettingsViewController? {
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
