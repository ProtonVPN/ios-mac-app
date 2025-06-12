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
import LegacyCommon
import VPNShared
@testable import ProtonVPN

private let navigationService = NavigationService(DependencyContainer())
private let windowService = WindowServiceMock()
private let uiAlertService = OsxUiAlertService(factory: OsxUiAlertServiceFactoryMock())
private let sessionService = SessionServiceMock()
private let telemetrySettings = TelemetrySettingsMock()

class AlertTests: XCTestCase {
    let alertService = MacAlertService(factory: MacAlertServiceFactoryMock())

    override func setUp() {
        super.setUp()
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

public class TelemetrySettingsFactoryMock: TelemetrySettings.Factory {
    public func makeAuthKeychainHandle() -> VPNShared.AuthKeychainHandle {
        AuthKeychainHandleMock()
    }

    public func makePropertiesManager() -> LegacyCommon.PropertiesManagerProtocol {
        PropertiesManagerMock()
    }
}

public class TelemetrySettingsMock: TelemetrySettings {
    public init() {
        super.init(TelemetrySettingsFactoryMock())
    }
}

private class WindowServiceMock: WindowService {
    var displayCount = 0

    func setStatusMenuWindowController(_ controller: StatusMenuWindowController) {}

    func showIfPresent(windowController: (some NSWindowController).Type) -> Bool {
        false
    }

    func closeIfPresent(windowController: (some NSWindowController).Type) {}
    func showLogin(viewModel: LoginViewModel) {}
    func showSidebar(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol) {}
    func showTour() {}
    func openAbout(factory: AboutViewController.Factory) {}
    func openAcknowledgements() {}
    func openSettingsWindow(viewModel: SettingsContainerViewModel, tabBarViewModel: SettingsTabBarViewModel, accountViewModel: AccountViewModel, couponViewModel: CouponViewModel) {}
    func openProfilesWindow(viewModel: ProfilesContainerViewModel) {}
    func openReportBugWindow(viewModel: ReportBugViewModel, alertService: CoreAlertService) {}

    func bringWindowsToForeground() -> Bool {
        false
    }

    func presentKeyModal(viewController: NSViewController) {
        displayCount += 1
    }

    func isKeyModalPresent(viewController: NSViewController) -> Bool {
        false
    }

    func closeActiveWindows(except: [NSWindowController.Type]) {}

    func openSystemExtensionGuideWindow(cancelledHandler: @escaping () -> Void) {}

    func openSubuserAlertWindow(alert: SubuserWithoutConnectionsAlert) {}

    func windowCloseRequested(_ sender: WindowController) {}

    func windowWillClose(_ sender: WindowController) {}
}

private class OsxUiAlertServiceFactoryMock: OsxUiAlertService.Factory {
    func makeNavigationService() -> NavigationService {
        navigationService
    }

    func makeWindowService() -> WindowService {
        windowService
    }

    func makeSessionService() -> SessionService {
        sessionService
    }
}

private class MacAlertServiceFactoryMock: MacAlertService.Factory {
    func makeVpnKeychain() -> LegacyCommon.VpnKeychainProtocol {
        VpnKeychainMock()
    }

    func makeTelemetrySettings() -> LegacyCommon.TelemetrySettings {
        telemetrySettings
    }

    func makeNavigationService() -> ProtonVPN.NavigationService {
        navigationService
    }

    func makeSessionService() -> SessionService {
        sessionService
    }

    func makePlanService() -> PlanService {
        PlanServiceMock()
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        PropertiesManagerMock()
    }

    func makeTroubleshootViewModel() -> TroubleshootViewModel {
        TroubleshootViewModel(propertiesManager: makePropertiesManager())
    }

    func makeAppSessionManager() -> AppSessionManager {
        AppSessionManagerMock()
    }

    func makeUIAlertService() -> UIAlertService {
        uiAlertService
    }

    func makeWindowService() -> WindowService {
        windowService
    }

    func makeNotificationManager() -> NotificationManagerProtocol {
        NotificationManagerMock()
    }

    func makeUpdateManager() -> UpdateManager {
        UpdateManager(UpdateFileSelectorFactoryMock())
    }
}

private class UpdateFileSelectorFactoryMock: UpdateFileSelectorFactory, PropertiesManagerFactory {
    func makeUpdateFileSelector() -> UpdateFileSelector {
        UpdateFileSelectorMock()
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        PropertiesManagerMock()
    }
}

private class AppSessionManagerMock: AppSessionManager {
    var sessionStatus: SessionStatus = .established
    var loggedIn: Bool = true
    var sessionChanged: Notification.Name = .init("AppSessionManagerSessionChanged")

    func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void) {}
    func finishLogin(authCredentials: AuthCredentials, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {}
    func refreshVpnAuthCertificate(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {}
    func logOut(force: Bool, reason: String?) {}
    func logOut() {}
    func replyToApplicationShouldTerminate() {}
}

private class NotificationManagerMock: NotificationManagerProtocol {
    func displayServerGoingOnMaintenance() {}
}

class PlanServiceMock: PlanService {
    var countriesCount: Int = 59

    func updateCountriesCount() {}
}
