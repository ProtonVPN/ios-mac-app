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
import KeychainAccess
import BugReport
import Search
import Review

// FUTURETODO: clean up objects that are possible to re-create if memory warning is received

final class DependencyContainer {
    
    private let appGroup = AppConstants.AppGroups.main
    
    // Singletons
    private lazy var navigationService = NavigationService(self)
     
    private lazy var vpnManager: VpnManagerProtocol = VpnManager(ikeFactory: ikeFactory,
                                                                     openVpnFactory: openVpnFactory,
                                                                     wireguardProtocolFactory: wireguardFactory,
                                                                     appGroup: appGroup,
                                                                     vpnAuthentication: makeVpnAuthentication(),
                                                                     vpnKeychain: vpnKeychain,
                                                                     propertiesManager: makePropertiesManager(),
                                                                     vpnStateConfiguration: makeVpnStateConfiguration(),
                                                                     alertService: iosAlertService,
                                                                     vpnCredentialsConfiguratorFactory: IOSVpnCredentialsConfiguratorFactory(propertiesManager: makePropertiesManager()),
                                                                     natTypePropertyProvider: makeNATTypePropertyProvider(),
                                                                     netShieldPropertyProvider: makeNetShieldPropertyProvider(),
                                                                     safeModePropertyProvider: makeSafeModePropertyProvider())
    private lazy var wireguardFactory = WireguardProtocolFactory(bundleId: AppConstants.NetworkExtensions.wireguard, appGroup: appGroup, propertiesManager: makePropertiesManager())
    private lazy var ikeFactory = IkeProtocolFactory()
    private lazy var openVpnFactory = OpenVpnProtocolFactory(bundleId: AppConstants.NetworkExtensions.openVpn, appGroup: appGroup, propertiesManager: makePropertiesManager())
    private lazy var vpnKeychain: VpnKeychainProtocol = VpnKeychain()
    private lazy var windowService: WindowService = WindowServiceImplementation(window: UIWindow(frame: UIScreen.main.bounds))
    private lazy var appStateManager: AppStateManager = AppStateManagerImplementation(
                                                                        vpnApiService: makeVpnApiService(),
                                                                        vpnManager: makeVpnManager(),
                                                                        networking: makeNetworking(),
                                                                        alertService: makeCoreAlertService(),
                                                                        timerFactory: TimerFactory(),
                                                                        propertiesManager: makePropertiesManager(),
                                                                        vpnKeychain: makeVpnKeychain(),
                                                                        configurationPreparer: makeVpnManagerConfigurationPreparer(),
                                                                        vpnAuthentication: makeVpnAuthentication(),
                                                                        doh: makeDoHVPN(),
                                                                        natTypePropertyProvider: makeNATTypePropertyProvider(),
                                                                        netShieldPropertyProvider: makeNetShieldPropertyProvider(),
                                                                        safeModePropertyProvider: makeSafeModePropertyProvider())
    private lazy var appSessionManager: AppSessionManagerImplementation = AppSessionManagerImplementation(factory: self)
    private lazy var uiAlertService: UIAlertService = IosUiAlertService(windowService: makeWindowService(), planService: makePlanService())
    private lazy var iosAlertService: CoreAlertService = IosAlertService(self)
    
    private lazy var maintenanceManager: MaintenanceManagerProtocol = MaintenanceManager(factory: self)
    private lazy var maintenanceManagerHelper: MaintenanceManagerHelper = MaintenanceManagerHelper(factory: self)
    
    // Refreshes app data at predefined time intervals
    private lazy var refreshTimer = AppSessionRefreshTimer(factory: self, fullRefresh: AppConstants.Time.fullServerRefresh, serverLoadsRefresh: AppConstants.Time.serverLoadsRefresh, accountRefresh: AppConstants.Time.userAccountRefresh)
    // Refreshes announements from API
    private lazy var announcementRefresher = AnnouncementRefresherImplementation(factory: self)
    
    // Instance of DynamicBugReportManager is persisted because it has a timer that refreshes config from time to time.
    private lazy var dynamicBugReportManager = DynamicBugReportManager(api: makeReportsApiService(), storage: DynamicBugReportStorageUserDefaults(userDefaults: Storage()), alertService: makeCoreAlertService(), propertiesManager: makePropertiesManager(), logFilesProvider: makeLogFilesIncludingRotatedProvider(), updateChecker: makeUpdateChecker())

    private lazy var vpnAuthentication: VpnAuthentication = {
        let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
        let vpnAuthKeychain = VpnAuthenticationKeychain(accessGroup: "\(appIdentifierPrefix)prt.ProtonVPN", storage: storage)
        return VpnAuthenticationManager(networking: makeNetworking(), storage: vpnAuthKeychain, safeModePropertyProvider: makeSafeModePropertyProvider())
    }()
    
    #if TLS_PIN_DISABLE
    private lazy var trustKitHelper: TrustKitHelper? = nil
    #else
    private lazy var trustKitHelper: TrustKitHelper? = TrustKitHelper()
    #endif

    private lazy var storage = Storage()
    private lazy var propertiesManager = PropertiesManager(storage: storage)
    private lazy var networkingDelegate: NetworkingDelegate = iOSNetworkingDelegate(alertingService: makeCoreAlertService()) // swiftlint:disable:this weak_delegate
    private lazy var networking = CoreNetworking(delegate: networkingDelegate, appInfo: makeAppInfo(), doh: makeDoHVPN())
    private lazy var planService = CorePlanService(networking: networking, alertService: makeCoreAlertService(), storage: storage)
    private lazy var appInfo = AppInfoImplementation()
    private lazy var doh: DoHVPN = {
        #if !RELEASE
        let atlasSecret: String? = ObfuscatedConstants.atlasSecret
        #else
        let atlasSecret: String? = nil
        #endif
        let doh = DoHVPN(apiHost: ObfuscatedConstants.apiHost, verifyHost: ObfuscatedConstants.humanVerificationV3Host, alternativeRouting: propertiesManager.alternativeRouting, customHost: propertiesManager.apiEndpoint, atlasSecret: atlasSecret)
        propertiesManager.onAlternativeRoutingChange = { alternativeRouting in
            doh.alternativeRouting = alternativeRouting
        }
        return doh
    }()
    lazy var profileManager = ProfileManager(serverStorage: ServerStorageConcrete(), propertiesManager: makePropertiesManager())
    private lazy var searchStorage = SearchModuleStorage(storage: storage)
    private lazy var review = Review(configuration: Configuration(settings: propertiesManager.ratingSettings), plan: (try? vpnKeychain.fetchCached().accountPlan.description) ?? "")
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
        return VpnManagerConfigurationPreparer(vpnKeychain: makeVpnKeychain(),
                                               alertService: makeCoreAlertService(),
                                               propertiesManager: makePropertiesManager()
        )
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
        return propertiesManager
    }
}

// MARK: WindowServiceFactory
extension DependencyContainer: WindowServiceFactory {
    func makeWindowService() -> WindowService {
        return windowService
    }
}

// MARK: VpnApiServiceFactory
extension DependencyContainer: VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService {
        return VpnApiService(networking: makeNetworking())
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

// MARK: VpnGatewayFactory
extension DependencyContainer: VpnGatewayFactory {
    func makeVpnGateway() -> VpnGatewayProtocol {
        return VpnGateway(vpnApiService: makeVpnApiService(),
                          appStateManager: makeAppStateManager(),
                          alertService: makeCoreAlertService(),
                          vpnKeychain: makeVpnKeychain(),
                          siriHelper: SiriHelper(),
                          netShieldPropertyProvider: makeNetShieldPropertyProvider(),
                          natTypePropertyProvider: makeNATTypePropertyProvider(),
                          safeModePropertyProvider: makeSafeModePropertyProvider(),
                          propertiesManager: makePropertiesManager(),
                          profileManager: makeProfileManager())
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
        return ReportsApiService(networking: makeNetworking())
    }
}

// MARK: UIAlertServiceFactory
extension DependencyContainer: UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService {
        return uiAlertService
    }
}

// MARK: TrustKitHelperFactory
extension DependencyContainer: TrustKitHelperFactory {
    func makeTrustKitHelper() -> TrustKitHelper? {
        return trustKitHelper
    }
}

// MARK: AppSessionRefreshTimerFactory
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
        
// MARK: - MaintenanceManagerFactory
extension DependencyContainer: MaintenanceManagerFactory {
    func makeMaintenanceManager() -> MaintenanceManagerProtocol {
        return maintenanceManager
    }
}

// MARK: - MaintenanceManagerHelperFactory
extension DependencyContainer: MaintenanceManagerHelperFactory {
    func makeMaintenanceManagerHelper() -> MaintenanceManagerHelper {
        return maintenanceManagerHelper
    }
}

// MARK: - ProfileManagerFactory
extension DependencyContainer: ProfileManagerFactory {
    func makeProfileManager() -> ProfileManager {
        return profileManager
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
        return CoreApiServiceImplementation(networking: makeNetworking())
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
        return NetShieldPropertyProviderImplementation(self, storage: storage, userInfoProvider: AuthKeychain())
    }
}

// MARK: TroubleshootViewModelFactory
extension DependencyContainer: TroubleshootViewModelFactory {
    func makeTroubleshootViewModel() -> TroubleshootViewModel {
        return TroubleshootViewModel(propertiesManager: makePropertiesManager())
    }
}

// MARK: VpnAuthenticationManagerFactory
extension DependencyContainer: VpnAuthenticationFactory {
    func makeVpnAuthentication() -> VpnAuthentication {
        return vpnAuthentication
    }
}

// MARK: VpnStateConfigurationFactory
extension DependencyContainer: VpnStateConfigurationFactory {
    func makeVpnStateConfiguration() -> VpnStateConfiguration {
        return VpnStateConfigurationManager(ikeProtocolFactory: ikeFactory, openVpnProtocolFactory: openVpnFactory, wireguardProtocolFactory: wireguardFactory, propertiesManager: makePropertiesManager(), appGroup: appGroup)
    }
}

// MARK: LoginServiceFactory
extension DependencyContainer: LoginServiceFactory {
    func makeLoginService() -> LoginService {
        return CoreLoginService(factory: self)
    }
}

// MARK: NetworkingFactory
extension DependencyContainer: NetworkingFactory {
    func makeNetworking() -> Networking {
        return networking
    }
}

// MARK: NetworkingDelegateFactory
extension DependencyContainer: NetworkingDelegateFactory {
    func makeNetworkingDelegate() -> NetworkingDelegate {
        return networkingDelegate
    }
}

// MARK: PlanServiceFactory
extension DependencyContainer: PlanServiceFactory {
    func makePlanService() -> PlanService {
        return planService
    }
}

// MARK: LogFileManagerFactory
extension DependencyContainer: LogFileManagerFactory {
    func makeLogFileManager() -> LogFileManager {
        return LogFileManagerImplementation()
    }
}

// MARK: LogFilesProviderFactory
extension DependencyContainer: LogFilesProviderFactory {
    func makeLogFilesProvider() -> LogFilesProvider {
        return DefaultLogFilesProvider(vpnManager: makeVpnManager(), logFileManager: makeLogFileManager(), appLogFilename: AppConstants.Filenames.appLogFilename)
    }

    // This provider includes rotated logfiles
    func makeLogFilesIncludingRotatedProvider() -> LogFilesProvider {
        return MergeLogFilesProvider(providers: makeLogFilesProvider(), FolderLogFilesProvider(appLogFilename: makeLogFileManager().getFileUrl(named: AppConstants.Filenames.appLogFilename).path))
    }
}

// MARK: AppInfoFactory
extension DependencyContainer: AppInfoFactory {
    func makeAppInfo() -> AppInfo {
        return appInfo
    }
}

// MARK: DoHVPNFactory
extension DependencyContainer: DoHVPNFactory {
    func makeDoHVPN() -> DoHVPN {
        return doh
    }
}

// MARK: OnboardingServiceFactory
extension DependencyContainer: OnboardingServiceFactory {
    func makeOnboardingService() -> OnboardingService {
        return OnboardingModuleService(factory: self)
    }
}

// MARK: BugReportCreatorFactory
extension DependencyContainer: BugReportCreatorFactory {
    func makeBugReportCreator() -> BugReportCreator {
        return iOSBugReportCreator()
    }
}

// MARK: DynamicBugReportManagerFactory
extension DependencyContainer: DynamicBugReportManagerFactory {
    func makeDynamicBugReportManager() -> DynamicBugReportManager {
        return dynamicBugReportManager
    }
}

// MARK: NATTypePropertyProviderFactory
extension DependencyContainer: NATTypePropertyProviderFactory {
    func makeNATTypePropertyProvider() -> NATTypePropertyProvider {
        return NATTypePropertyProviderImplementation(self, storage: storage, userInfoProvider: AuthKeychain())
    }
}

// MARK: SafeModePropertyProviderFactory
extension DependencyContainer: SafeModePropertyProviderFactory {
    func makeSafeModePropertyProvider() -> SafeModePropertyProvider {
        return SafeModePropertyProviderImplementation(self, storage: storage, userInfoProvider: AuthKeychain())
    }
}

// MARK: SearchStorageFactory
extension DependencyContainer: SearchStorageFactory {
    func makeSearchStorage() -> SearchStorage {
        return searchStorage
    }
}

// MARK: ReviewFactory
extension DependencyContainer: ReviewFactory {
    func makeReview() -> Review {
        return review
    }
}
