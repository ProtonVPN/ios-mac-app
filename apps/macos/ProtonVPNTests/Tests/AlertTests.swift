//
//  AlertTests.swift
//  ProtonVPN - Created on 06.11.19.
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
import vpncore

@testable import ProtonVPN

fileprivate let navigationService = NavigationService(DependencyContainer())
fileprivate let windowService = WindowServiceMock()
fileprivate let uiAlertService = OsxUiAlertService(factory: OsxUiAlertServiceFactoryMock())

class AlertTests: XCTestCase {

    let alertService = MacAlertService(factory: MacAlertServiceFactoryMock())
    
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
        
        let alert1 = ConfirmVpnDisconnectAlert(confirmHandler: confirmationHandler1, cancelHandler: cancellationHandler1)
        let alert2 = ConfirmVpnDisconnectAlert(confirmHandler: confirmationHandler2, cancelHandler: cancellationHandler2)
        
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
    
    func setStatusMenuWindowController(_ controller: StatusMenuWindowController) {}
    
    func showIfPresent<T: NSWindowController>(windowController: T.Type) -> Bool {
        return false
    }
    
    func closeIfPresent<T: NSWindowController>(windowController: T.Type) {}
    func showLogin(viewModel: LoginViewModel) {}
    func showSidebar(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol) {}
    func showTour() {}
    func openAbout(factory: AboutViewController.Factory) {}
    func openAcknowledgements() {}
    func openSettingsWindow(viewModel: SettingsContainerViewModel, tabBarViewModel: SettingsTabBarViewModel) {}
    func openProfilesWindow(viewModel: ProfilesContainerViewModel) {}
    func openReportBugWindow(viewModel: ReportBugViewModel, alertService: CoreAlertService) {}
    
    func bringWindowsToForground() -> Bool {
        return false
    }

    func closeActiveWindows() {}
    
    func presentKeyModal(viewController: NSViewController) {
        displayCount += 1
    }
}

fileprivate class OsxUiAlertServiceFactoryMock: OsxUiAlertService.Factory {
    func makeNavigationService() -> NavigationService {
        return navigationService
    }
    
    func makeWindowService() -> WindowService {
        return windowService
    }
}

fileprivate class MacAlertServiceFactoryMock: MacAlertService.Factory {
    func makeAppSessionManager() -> AppSessionManager {
        return AppSessionManagerMock()
    }
    
    func makeUIAlertService() -> UIAlertService {
        return uiAlertService
    }
    
    func makeWindowService() -> WindowService {
        return windowService
    }
}

fileprivate class AppSessionManagerMock: AppSessionManager {
    var sessionStatus: SessionStatus = .established
    var loggedIn: Bool = true
    var sessionChanged: Notification.Name = Notification.Name("AppSessionManagerSessionChanged")
    
    func attemptRememberLogIn(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {}
    func logIn(username: String, password: String, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {}
    func logOut(force: Bool) {}
    func logOut() {}
    func scheduleRefreshes(now: Bool) {}
    func stopRefreshingIfInactive() {}
    func replyToApplicationShouldTerminate() {}
}
