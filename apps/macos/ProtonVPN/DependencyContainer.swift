//
//  DependencyContainer.swift
//  ProtonVPN - Created on 21/08/2019.
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

import Foundation
import vpncore

// FUTURETODO: clean up objects that are possible to re-create if memory warning is received

class DependencyContainer {
    
    // Singletons
    private lazy var navigationService = NavigationService(self)
    private lazy var vpnManager: VpnManagerProtocol = VpnManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = VpnKeychain()
    private lazy var windowService: WindowService = WindowServiceImplementation(factory: self)
    private lazy var alamofireWrapper: AlamofireWrapper = AlamofireWrapperImplementation(factory: self)
    private lazy var appStateManager: AppStateManager = AppStateManager(vpnApiService: makeVpnApiService(),
                                                                        vpnManager: vpnManager,
                                                                        alamofireWrapper: alamofireWrapper,
                                                                        alertService: macAlertService,
                                                                        timerFactory: TimerFactory(),
                                                                        propertiesManager: PropertiesManager(),
                                                                        vpnKeychain: vpnKeychain)
    private lazy var firewallManager: FirewallManager = FirewallManager(factory: self)
    private lazy var appSessionManager: AppSessionManager = AppSessionManagerImplementation(factory: self)
    private lazy var macAlertService: MacAlertService = MacAlertService(factory: self)
    
    private lazy var humanVerificationAdapter: HumanVerificationAdapter = HumanVerificationAdapter()
    
    // Hold it in memory so it's possible to refresh token any time
    private var authApiService: AuthApiService!
    
    #if TLS_PIN_DISABLE
    private lazy var trustKitHelper: TrustKitHelper? = nil
    #else
    private lazy var trustKitHelper: TrustKitHelper? = TrustKitHelper(factory: self)
    #endif
}

// MARK: NavigationServiceFactory
extension DependencyContainer: NavigationServiceFactory {
    func makeNavigationService() -> NavigationService {
        return navigationService
    }
}

// MARK: VpnManagerFactory
extension DependencyContainer: VpnManagerFactory {
    func makeVpnManager() -> VpnManagerProtocol {
        return vpnManager
    }
}

// MARK: VpnKeychainFactory
extension DependencyContainer: VpnKeychainFactory {
    func makeVpnKeychain() -> VpnKeychainProtocol {
        return vpnKeychain
    }
}

// MARK: PropertiesManagerFactory
extension DependencyContainer: PropertiesManagerFactory {
    func makePropertiesManager() -> PropertiesManagerProtocol {
        return PropertiesManager()
    }
}

// MARK: WindowServiceFactory
extension DependencyContainer: WindowServiceFactory {
    func makeWindowService() -> WindowService {
        return windowService
    }
}

// MARK: AlamofireWrapperFactory
extension DependencyContainer: AlamofireWrapperFactory {
    func makeAlamofireWrapper() -> AlamofireWrapper {
        return alamofireWrapper
    }
}

// MARK: VpnApiServiceFactory
extension DependencyContainer: VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService {
        return VpnApiService(alamofireWrapper: alamofireWrapper)
    }
}

// MARK: AuthApiServiceFactory
extension DependencyContainer: AuthApiServiceFactory {
    func makeAuthApiService() -> AuthApiService {
        if authApiService == nil {
            authApiService = AuthApiServiceImplementation(alamofireWrapper: alamofireWrapper)
        }
        return authApiService
    }
}

// MARK: OsxUiAlertServiceFactory
extension DependencyContainer: UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService {
        return OsxUiAlertService(factory: self)
    }
}

// MARK: CoreAlertServiceFactory
extension DependencyContainer: CoreAlertServiceFactory {
    func makeCoreAlertService() -> CoreAlertService {
        return macAlertService
    }
}

// MARK: AppStateManagerFactory
extension DependencyContainer: AppStateManagerFactory {
    func makeAppStateManager() -> AppStateManager {
        return appStateManager
    }
}

// MARK: FirewallManagerFactory
extension DependencyContainer: FirewallManagerFactory {
    func makeFirewallManager() -> FirewallManager {
        return firewallManager
    }
}

// MARK: AppSessionManagerFactory
extension DependencyContainer: AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager {
        return appSessionManager
    }
}

// MARK: ServerStorageFactory
extension DependencyContainer: ServerStorageFactory {
    func makeServerStorage() -> ServerStorage {
        return ServerStorageConcrete()
    }
}

// MARK: TrialServiceFactory
extension DependencyContainer: TrialServiceFactory {
    func makeTrialService() -> TrialService {
        return TrialServiceMock() // MacOS app doesnt show any trial screens
    }
}

// MARK: TrialCheckerFactory
extension DependencyContainer: TrialCheckerFactory {
    func makeTrialChecker() -> TrialChecker {
        return TrialChecker(factory: self)
    }
}

// MARK: VpnGatewayFactory
extension DependencyContainer: VpnGatewayFactory {
    func makeVpnGateway() -> VpnGatewayProtocol {
        return VpnGateway(vpnApiService: makeVpnApiService(), appStateManager: makeAppStateManager(), alertService: makeCoreAlertService(), vpnKeychain: makeVpnKeychain(), siriHelper: SiriHelper())
    }
}

// MARK: NotificationManagerFactory
extension DependencyContainer: NotificationManagerFactory {
    func makeNotificationManager() -> NotificationManager {
        return NotificationManager(appStateManager: makeAppStateManager(),
                                   appSessionManager: makeAppSessionManager(),
                                   firewallManager: makeFirewallManager())
    }
}

// MARK: ReportBugViewModelFactory
extension DependencyContainer: ReportBugViewModelFactory {
    func makeReportBugViewModel() -> ReportBugViewModel {
        return ReportBugViewModel(os: "MacOS",
                                  osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                                  propertiesManager: makePropertiesManager(),
                                  reportsApiService: makeReportsApiService(),
                                  alertService: makeCoreAlertService(),
                                  vpnKeychain: makeVpnKeychain())
    }
}

// MARK: ReportsApiServiceFactory
extension DependencyContainer: ReportsApiServiceFactory {
    func makeReportsApiService() -> ReportsApiService {
        return ReportsApiService(alamofireWrapper: makeAlamofireWrapper())
    }
}

// MARK: HumanVerificationAdapterFactory
extension DependencyContainer: HumanVerificationAdapterFactory {
    func makeHumanVerificationAdapter() -> HumanVerificationAdapter {
        return humanVerificationAdapter
    }
}

// MARK: TrustKitHelperFactory
extension DependencyContainer: TrustKitHelperFactory {
    func makeTrustKitHelper() -> TrustKitHelper? {
        return trustKitHelper
    }
}

// MARK: WiFiSecurityMonitorFactory
extension DependencyContainer: WiFiSecurityMonitorFactory {
    func makeWiFiSecurityMonitor() -> WiFiSecurityMonitor {
        return WiFiSecurityMonitor()
    }
}
