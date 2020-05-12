//
//  DependencyContainer.swift
//  ProtonVPN - Created on 09/09/2019.
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
    
    private let openVpnExtensionBundleIdentifier = "ch.protonmail.vpn.OpenVPN-Extension"
    private let appGroup = "group.ch.protonmail.vpn"
    
    // Singletons
    private lazy var navigationService = NavigationService(self)
     
    private lazy var vpnManager: VpnManagerProtocol = VpnManager(ikeFactory: IkeProtocolFactory(), openVpnFactory: OpenVpnProtocolFactory(bundleId: openVpnExtensionBundleIdentifier, appGroup: appGroup, propertiesManager: makePropertiesManager()), appGroup: appGroup, alertService: iosAlertService)
    private lazy var vpnKeychain: VpnKeychainProtocol = VpnKeychain()
    private lazy var windowService: WindowService = WindowServiceImplementation(window: UIWindow(frame: UIScreen.main.bounds))
    private var alamofireWrapper: AlamofireWrapper?
    private lazy var appStateManager: AppStateManager = AppStateManager(vpnApiService: makeVpnApiService(),
                                                                        vpnManager: makeVpnManager(),
                                                                        alamofireWrapper: makeAlamofireWrapper(),
                                                                        alertService: makeCoreAlertService(),
                                                                        timerFactory: TimerFactory(),
                                                                        propertiesManager: makePropertiesManager(),
                                                                        vpnKeychain: makeVpnKeychain(),
                                                                        configurationPreparer: makeVpnManagerConfigurationPreparer())
    private lazy var appSessionManager: AppSessionManager = AppSessionManagerImplementation(factory: self)
    private lazy var uiAlertService: UIAlertService = IosUiAlertService(windowService: makeWindowService())
    private lazy var iosAlertService: CoreAlertService = IosAlertService(self)
    
    private lazy var humanVerificationAdapter: HumanVerificationAdapter = HumanVerificationAdapter()
    private lazy var signinInfoContainer = SigninInfoContainer()
    
    // Hold it in memory so it's possible to refresh token any time
    private var authApiService: AuthApiService!
    
    // Holds products available to buy via IAP
    private lazy var storeKitManager = StoreKitManagerImplementation(factory: self)
    
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

// MARK: SettingsServiceFactory
extension DependencyContainer: SettingsServiceFactory {
    func makeSettingsService() -> SettingsService {
        return navigationService
    }
}

// MARK: VpnManagerFactory
extension DependencyContainer: VpnManagerFactory {
    func makeVpnManager() -> VpnManagerProtocol {
        return vpnManager
    }
}

// MARK: VpnManagerConfigurationPreparer
extension DependencyContainer: VpnManagerConfigurationPreparerFactory {
    func makeVpnManagerConfigurationPreparer() -> VpnManagerConfigurationPreparer {
        return VpnManagerConfigurationPreparer(vpnKeychain: makeVpnKeychain(), alertService: makeCoreAlertService())
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

// MARK: ServicePlanDataStorageFactory
extension DependencyContainer: ServicePlanDataStorageFactory {
    func makeServicePlanDataStorage() -> ServicePlanDataStorage {
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
        if alamofireWrapper == nil {
            alamofireWrapper = AlamofireWrapperImplementation(factory: self)
        }
        return alamofireWrapper!
    }
}

// MARK: VpnApiServiceFactory
extension DependencyContainer: VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService {
        return VpnApiService(alamofireWrapper: makeAlamofireWrapper())
    }
}

// MARK: AuthApiServiceFactory
extension DependencyContainer: AuthApiServiceFactory {
    func makeAuthApiService() -> AuthApiService {
        if authApiService == nil {
            authApiService = AuthApiServiceImplementation(alamofireWrapper: makeAlamofireWrapper())
        }
        return authApiService
    }
}

// MARK: CoreAlertServiceFactory
extension DependencyContainer: CoreAlertServiceFactory {
    func makeCoreAlertService() -> CoreAlertService {
        return iosAlertService
    }
}

// MARK: AppStateManagerFactory
extension DependencyContainer: AppStateManagerFactory {
    func makeAppStateManager() -> AppStateManager {
        return appStateManager
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
        return navigationService
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
        return VpnGateway(vpnApiService: makeVpnApiService(),
                          appStateManager: makeAppStateManager(),
                          alertService: makeCoreAlertService(),
                          vpnKeychain: makeVpnKeychain(),
                          siriHelper: SiriHelper())
    }
}

// MARK: ReportBugViewModelFactory
extension DependencyContainer: ReportBugViewModelFactory {
    func makeReportBugViewModel() -> ReportBugViewModel {
        return ReportBugViewModel(os: "iOS",
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

// MARK: UserApiServiceFactory
extension DependencyContainer: UserApiServiceFactory {
    func makeUserApiService() -> UserApiService {
        return UserApiServiceImplementation(alamofireWrapper: makeAlamofireWrapper())
    }
}

// MARK: PaymentsApiServiceFactory
extension DependencyContainer: PaymentsApiServiceFactory {
    func makePaymentsApiService() -> PaymentsApiService {
        return PaymentsApiServiceImplementation(alamofireWrapper: makeAlamofireWrapper())
    }
}

// MARK: UIAlertServiceFactory
extension DependencyContainer: UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService {
        return uiAlertService
    }
}

// MARK: ServicePlanDataServiceFactory
extension DependencyContainer: ServicePlanDataServiceFactory {
    func makeServicePlanDataService() -> ServicePlanDataService {
        return ServicePlanDataServiceImplementation.shared
    }
}

// MARK: StoreKitManagerFactory
extension DependencyContainer: StoreKitManagerFactory {
    func makeStoreKitManager() -> StoreKitManager {
        return storeKitManager
    }
}

// MARK: HumanVerificationHandlerFactory
extension DependencyContainer: HumanVerificationAdapterFactory {
    func makeHumanVerificationAdapter() -> HumanVerificationAdapter {
        return humanVerificationAdapter
    }
}

// MARK: GenericRequestRetrierFactory
extension DependencyContainer: GenericRequestRetrierFactory {
    func makeGenericRequestRetrier() -> GenericRequestRetrier {
        return GenericRequestRetrier()
    }
}

// MARK: TrustKitHelperFactory
extension DependencyContainer: TrustKitHelperFactory {
    func makeTrustKitHelper() -> TrustKitHelper? {
        return trustKitHelper
    }
}

// MARK: SigninInfoContainerFactory
extension DependencyContainer: SigninInfoContainerFactory {
    func makeSigninInfoContainer() -> SigninInfoContainer {
        return signinInfoContainer
    }    
}
