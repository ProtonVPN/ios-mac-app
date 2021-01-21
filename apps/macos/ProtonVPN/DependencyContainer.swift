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
    
    private let openVpnExtensionBundleIdentifier = "ch.protonvpn.mac.OpenVPN-Extension"
    private let appGroup = "J6S6Q257EK.group.ch.protonvpn.mac"
    
    // Singletons
    private lazy var navigationService = NavigationService(self)
    private lazy var vpnManager: VpnManagerProtocol = VpnManager(ikeFactory: IkeProtocolFactory(),
                                                                 openVpnFactory: OpenVpnProtocolFactory(bundleId: openVpnExtensionBundleIdentifier,
                                                                                                        appGroup: appGroup,
                                                                                                        propertiesManager: makePropertiesManager()),
                                                                 appGroup: appGroup,
                                                                 alertService: macAlertService)
    
    private lazy var vpnKeychain: VpnKeychainProtocol = VpnKeychain()
    private lazy var windowService: WindowService = WindowServiceImplementation(factory: self)
    private lazy var alamofireWrapper: AlamofireWrapper = AlamofireWrapperImplementation(factory: self)
    private lazy var appStateManager: AppStateManager = AppStateManager(vpnApiService: makeVpnApiService(),
                                                                        vpnManager: vpnManager,
                                                                        alamofireWrapper: alamofireWrapper,
                                                                        alertService: macAlertService,
                                                                        timerFactory: TimerFactory(),
                                                                        propertiesManager: PropertiesManager(),
                                                                        vpnKeychain: vpnKeychain,
                                                                        configurationPreparer: makeVpnManagerConfigurationPreparer())
    private lazy var appSessionManager: AppSessionManagerImplementation = AppSessionManagerImplementation(factory: self)
    private lazy var macAlertService: MacAlertService = MacAlertService(factory: self)
    
    private lazy var humanVerificationAdapter: HumanVerificationAdapter = HumanVerificationAdapter()
    
    private lazy var maintenanceManager: MaintenanceManagerProtocol = MaintenanceManager( factory: self )
    private lazy var maintenanceManagerHelper: MaintenanceManagerHelper = MaintenanceManagerHelper(factory: self)
    
    // Hold it in memory so it's possible to refresh token any time
    private var authApiService: AuthApiService!
    
    // Refreshes app data at predefined time intervals
    private lazy var refreshTimer = AppSessionRefreshTimer(factory: self, fullRefresh: AppConstants.Time.fullServerRefresh, serverLoadsRefresh: AppConstants.Time.serverLoadsRefresh, canRefreshFull: { return true }, canRefreshLoads: { return NSApp.isActive })
    
    // Refreshes announements from API
    private lazy var announcementRefresher = AnnouncementRefresherImplementation(factory: self)
    
    #if TLS_PIN_DISABLE
    private lazy var trustKitHelper: TrustKitHelper? = nil
    #else
    private lazy var trustKitHelper: TrustKitHelper? = TrustKitHelper(factory: self)
    #endif
    
    // Manages app updates
    private lazy var updateManager = UpdateManager(self)
    
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

// MARK: VpnManagerConfigurationPreparer
extension DependencyContainer: VpnManagerConfigurationPreparerFactory {
    func makeVpnManagerConfigurationPreparer() -> VpnManagerConfigurationPreparer {
        return VpnManagerConfigurationPreparer(vpnKeychain: makeVpnKeychain(), alertService: makeCoreAlertService(), propertiesManager: makePropertiesManager())
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
        return VpnGateway(vpnApiService: makeVpnApiService(), appStateManager: makeAppStateManager(), alertService: makeCoreAlertService(), vpnKeychain: makeVpnKeychain(), siriHelper: SiriHelper(), netShieldPropertyProvider: makeNetShieldPropertyProvider())
    }
}

// MARK: NotificationManagerFactory
extension DependencyContainer: NotificationManagerFactory {
    func makeNotificationManager() -> NotificationManagerProtocol {
        return NotificationManager(appStateManager: makeAppStateManager(),
                                   appSessionManager: makeAppSessionManager())
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

// MARK: ProtonAPIAuthenticatorFactory
extension DependencyContainer: ProtonAPIAuthenticatorFactory {
    func makeProtonAPIAuthenticator() -> ProtonAPIAuthenticator {
        return ProtonAPIAuthenticator(self)
    }
}

// MARK: MigrationManagerFactory
extension DependencyContainer: MigrationManagerFactory {
    func makeMigrationManager() -> MigrationManagerProtocol {
        let propertiesManager = makePropertiesManager()
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return MigrationManager(propertiesManager, currentAppVersion: currentVersion)
    }
}

// MARK: - MaintenanceManagerFactory
extension DependencyContainer: MaintenanceManagerFactory {
    func makeMaintenanceManager() -> MaintenanceManagerProtocol {
        return maintenanceManager
    }
}

// MARK: RefreshTimerFactory
extension DependencyContainer: AppSessionRefreshTimerFactory {
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer {
        return refreshTimer
    }
}

// MARK: - AppSessionRefresherFactory
extension DependencyContainer: AppSessionRefresherFactory {
    func makeAppSessionRefresher() -> AppSessionRefresher {
        return appSessionManager
    }
}

// MARK: - MaintenanceManagerHelperFactory
extension DependencyContainer: MaintenanceManagerHelperFactory {
    func makeMaintenanceManagerHelper() -> MaintenanceManagerHelper {
        return maintenanceManagerHelper
    }
}

// MARK: - AnnouncementRefresherFactory
extension DependencyContainer: AnnouncementRefresherFactory {
    func makeAnnouncementRefresher() -> AnnouncementRefresher {
        return announcementRefresher
    }
}

// MARK: - AnnouncementStorageFactory
extension DependencyContainer: AnnouncementStorageFactory {
    func makeAnnouncementStorage() -> AnnouncementStorage {
        return AnnouncementStorageUserDefaults(userDefaults: Storage.userDefaults(), keyNameProvider: nil)
    }
}

// MARK: - AnnouncementManagerFactory
extension DependencyContainer: AnnouncementManagerFactory {
    func makeAnnouncementManager() -> AnnouncementManager {
        return AnnouncementManagerImplementation(factory: self)
    }
}

// MARK: - CoreApiServiceFactory
extension DependencyContainer: CoreApiServiceFactory {
    func makeCoreApiService() -> CoreApiService {
        return CoreApiServiceImplementation(alamofireWrapper: self.makeAlamofireWrapper())
    }
}

// MARK: - ProfileManagerFactory
extension DependencyContainer: ProfileManagerFactory {
    func makeProfileManager() -> ProfileManager {
        return ProfileManager.shared
    }
}

// MARK: - HeaderViewModelFactory
extension DependencyContainer: HeaderViewModelFactory {
    func makeHeaderViewModel() -> HeaderViewModel {
        return HeaderViewModel(factory: self, appStateManager: appStateManager, navService: navigationService)
    }
}

// MARK: - AnnouncementsViewModelFactory
extension DependencyContainer: AnnouncementsViewModelFactory {
    func makeAnnouncementsViewModel() -> AnnouncementsViewModel {
        return AnnouncementsViewModel(factory: self)
    }
}

// MARK: - SafariServiceFactory
extension DependencyContainer: SafariServiceFactory {
    func makeSafariService() -> SafariServiceProtocol {
        return SafariService()
    }
}

// MARK: - UserTierProviderFactory
extension DependencyContainer: UserTierProviderFactory {
    func makeUserTierProvider() -> UserTierProvider {
        return UserTierProviderImplementation(self)
    }
}

// MARK: - NetShieldPropertyProviderFactory
extension DependencyContainer: NetShieldPropertyProviderFactory {
    func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider {
        return NetShieldPropertyProviderImplementation(self)
    }
}

// MARK: - UpdateFileSelectorFactory
extension DependencyContainer: UpdateFileSelectorFactory {
    func makeUpdateFileSelector() -> UpdateFileSelector {
        return UpdateFileSelectorImplementation(self)
    }
}

// MARK: - UpdateManagerFactory
extension DependencyContainer: UpdateManagerFactory {
    func makeUpdateManager() -> UpdateManager {
        return updateManager
    }
}

// MARK: - SystemExtensionManagerFactory
extension DependencyContainer: SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager {
        return SystemExtensionManager(factory: self)
    }
}
