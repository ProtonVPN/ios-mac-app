//
//  Created on 2022-09-08.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import NetworkExtension
import Timer
import PMLogger
import VPNShared
import Dependencies

typealias PropertiesToOverride = DoHVPNFactory &
                                NetworkingDelegateFactory &
                                CoreAlertServiceFactory &
                                OpenVpnProtocolFactoryCreator &
                                WireguardProtocolFactoryCreator &
                                VpnCredentialsConfiguratorFactoryCreator &
                                VpnAuthenticationFactory &
                                LogContentProviderFactory &
                                UpdateCheckerFactory &
                                VpnConnectionInterceptDelegate

open class Container: PropertiesToOverride {
    public struct Config {
        public let os: String
        public let appIdentifierPrefix: String
        public let appGroup: String
        public let accessGroup: String
        public let openVpnExtensionBundleIdentifier: String
        public let wireguardVpnExtensionBundleIdentifier: String

        public var osVersion: String {
            ProcessInfo.processInfo.operatingSystemVersionString
        }

        public init(os: String,
                    appIdentifierPrefix: String,
                    appGroup: String,
                    accessGroup: String,
                    openVpnExtensionBundleIdentifier: String,
                    wireguardVpnExtensionBundleIdentifier: String) {
            self.os = os
            self.appIdentifierPrefix = appIdentifierPrefix
            self.appGroup = appGroup
            self.accessGroup = accessGroup
            self.openVpnExtensionBundleIdentifier = openVpnExtensionBundleIdentifier
            self.wireguardVpnExtensionBundleIdentifier = wireguardVpnExtensionBundleIdentifier
        }
    }

    @Dependency(\.date) var date

    public let config: Config

    // Lazy instances - get allocated once, and stay allocated
    private lazy var storage = Storage()
    private lazy var propertiesManager: PropertiesManagerProtocol = PropertiesManager(storage: storage)
    private lazy var vpnKeychain: VpnKeychainProtocol = VpnKeychain()
    private lazy var authKeychain: AuthKeychainHandle = AuthKeychain(context: .mainApp)
    private lazy var profileManager = ProfileManager(self)
    private lazy var networking = CoreNetworking(self)
    private lazy var ikeFactory = IkeProtocolFactory(factory: self)
    private lazy var vpnAuthenticationKeychain = VpnAuthenticationKeychain(self,
                                                                           accessGroup: config.accessGroup,
                                                                           vpnKeysGenerator: CoreVPNKeysGenerator())
    private lazy var vpnManager: VpnManagerProtocol = VpnManager(self, config: config)

    private lazy var timerFactory = TimerFactoryImplementation()

    private lazy var appStateManager: AppStateManager = AppStateManagerImplementation(self)

    private lazy var announcementsViewModel: AnnouncementsViewModel = AnnouncementsViewModel(factory: self)

    // Refreshes announcements from API
    private lazy var announcementRefresher = AnnouncementRefresherImplementation(factory: self)

    private lazy var maintenanceManager: MaintenanceManagerProtocol = MaintenanceManager(factory: self)
    private lazy var maintenanceManagerHelper: MaintenanceManagerHelper = MaintenanceManagerHelper(factory: self)

    // Instance of DynamicBugReportManager is persisted because it has a timer that refreshes config from time to time.
    private lazy var dynamicBugReportManager = DynamicBugReportManager(self)

    private lazy var _telemetryServiceTask = Task {
        let buffer = await withDependencies(from: self) {
            return await TelemetryBuffer(retrievingFromStorage: true)
        }
        return await TelemetryServiceImplementation(factory: self,
                                             timer: ConnectionTimer(),
                                             buffer: buffer)
    }

    // Transient instances - get allocated as many times as they're referenced
    private var serverStorage: ServerStorage {
        ServerStorageConcrete()
    }

    private var telemetryService: TelemetryService?

    public init(_ config: Config) {
        self.config = config
    }

    /// Call this method from `application(didFinishLaunchingWithOptions)` of the app.
    /// It does preparation work needed at the start of the app, but which can't be done in `init` because it's too early.
    public func applicationDidFinishedLoading() {
        Task {
            // We need to initialise the TelemetryService somewhere because no other part of the code uses it directly.
            // TelemetryService listens to notifications and sends telemetry events based on that.
            self.telemetryService = await makeTelemetryService()
        }
    }

    func shouldHaveOverridden(caller: StaticString = #function) -> Never {
        fatalError("Should have overridden \(caller)")
    }

    // MARK: - Configs to override
    #if os(macOS)
    open var modelId: String? {
        shouldHaveOverridden()
    }
    #endif

    open var vpnConnectionInterceptPolicies: [VpnConnectionInterceptPolicyItem] {
        []
    }

    // MARK: - Factories to override
    // MARK: DoHVPNFactory
    open func makeDoHVPN() -> DoHVPN {
        shouldHaveOverridden()
    }

    // MARK: NetworkingDelegate
    open func makeNetworkingDelegate() -> NetworkingDelegate {
        shouldHaveOverridden()
    }

    // MARK: CoreAlertService
    open func makeCoreAlertService() -> CoreAlertService {
        shouldHaveOverridden()
    }

    // MARK: OpenVPNProtocolFactoryCreator
    open func makeOpenVpnProtocolFactory() -> OpenVpnProtocolFactory {
        shouldHaveOverridden()
    }

    // MARK: WireguardProtocolFactoryCreator
    open func makeWireguardProtocolFactory() -> WireguardProtocolFactory {
        shouldHaveOverridden()
    }

    // MARK: VpnCredentialsConfigurator
    open func makeVpnCredentialsConfiguratorFactory() -> VpnCredentialsConfiguratorFactory {
        shouldHaveOverridden()
    }

    // MARK: VpnAuthentication
    open func makeVpnAuthentication() -> VpnAuthentication {
        shouldHaveOverridden()
    }

    open func makeLogContentProvider() -> LogContentProvider {
        shouldHaveOverridden()
    }

    open func makeUpdateChecker() -> UpdateChecker {
        shouldHaveOverridden()
    }
}

// MARK: StorageFactory
extension Container: StorageFactory {
    public func makeStorage() -> Storage {
        storage
    }
}

// MARK: PropertiesManagerFactory
extension Container: PropertiesManagerFactory {
    public func makePropertiesManager() -> PropertiesManagerProtocol {
        propertiesManager
    }
}

// MARK: VpnKeychainFactory
extension Container: VpnKeychainFactory {
    public func makeVpnKeychain() -> VpnKeychainProtocol {
        vpnKeychain
    }
}

// MARK: AuthKeychainHandleFactory
extension Container: AuthKeychainHandleFactory {
    public func makeAuthKeychainHandle() -> AuthKeychainHandle {
        authKeychain
    }
}

extension Container: ServerStorageFactory {
    public func makeServerStorage() -> ServerStorage {
        serverStorage
    }
}

// MARK: ProfileManagerFactory
extension Container: ProfileManagerFactory {
    public func makeProfileManager() -> ProfileManager {
        profileManager
    }
}

// MARK: AppInfoFactory
extension Container: AppInfoFactory {
    public func makeAppInfo(context: AppContext) -> AppInfo {
        #if os(macOS)
        return AppInfoImplementation(context: context, modelName: modelId)
        #else
        return AppInfoImplementation(context: context)
        #endif
    }
}

// MARK: NetworkingFactory
extension Container: NetworkingFactory {
    public func makeNetworking() -> Networking {
        networking
    }
}

// MARK: NEVPNManagerWrapperFactory
extension Container: NEVPNManagerWrapperFactory {
    public func makeNEVPNManagerWrapper() -> NEVPNManagerWrapper {
        NEVPNManager.shared()
    }
}

// MARK: NETunnelProviderManagerWrapperFactory
extension Container: NETunnelProviderManagerWrapperFactory {
    public func makeNewManager() -> NETunnelProviderManagerWrapper {
        NETunnelProviderManager()
    }

    public func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            completionHandler(managers, error)
        }
    }
}

extension Container: UserTierProviderFactory {
    public func makeUserTierProvider() -> UserTierProvider {
        UserTierProviderImplementation(self)
    }
}

// MARK: NATTypePropertyProviderFactory
extension Container: NATTypePropertyProviderFactory {
    public func makeNATTypePropertyProvider() -> NATTypePropertyProvider {
        NATTypePropertyProviderImplementation(self)
    }
}

// MARK: SafeModePropertyProviderFactory
extension Container: SafeModePropertyProviderFactory {
    public func makeSafeModePropertyProvider() -> SafeModePropertyProvider {
        SafeModePropertyProviderImplementation(self)
    }
}

// MARK: NetShieldPropertyProviderFactory
extension Container: NetShieldPropertyProviderFactory {
    public func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider {
        NetShieldPropertyProviderImplementation(self)
    }
}

// MARK: VpnStateConfigurationFactory
extension Container: VpnStateConfigurationFactory {
    public func makeVpnStateConfiguration() -> VpnStateConfiguration {
        VpnStateConfigurationManager(self, config: config)
    }
}

extension Container: VpnManagerFactory {
    public func makeVpnManager() -> VpnManagerProtocol {
        vpnManager
    }
}

extension Container: VpnAuthenticationStorageFactory {
    public func makeVpnAuthenticationStorage() -> VpnAuthenticationStorage {
        vpnAuthenticationKeychain
    }
}

// MARK: VpnManagerConfigurationPreparer
extension Container: VpnManagerConfigurationPreparerFactory {
    public func makeVpnManagerConfigurationPreparer() -> VpnManagerConfigurationPreparer {
        VpnManagerConfigurationPreparer(self)
    }
}

// MARK: AppStateManagerFactory
extension Container: AppStateManagerFactory {
    public func makeAppStateManager() -> AppStateManager {
        appStateManager
    }
}

// MARK: AvailabilityCheckerResolverFactory
extension Container: AvailabilityCheckerResolverFactory {
    public func makeAvailabilityCheckerResolver(openVpnConfig: OpenVpnConfig, wireguardConfig: WireguardConfig) -> AvailabilityCheckerResolver {
        AvailabilityCheckerResolverImplementation(openVpnConfig: openVpnConfig, wireguardConfig: wireguardConfig)
    }
}

// MARK: VpnGatewayFactory
extension Container: VpnGatewayFactory {
    public func makeVpnGateway() -> VpnGatewayProtocol {
        VpnGateway(self)
    }
}

// MARK: SessionServiceFactory
extension Container: SessionServiceFactory {
    public func makeSessionService() -> SessionService {
        SessionServiceImplementation(factory: self)
    }
}

// MARK: LogFileManagerFactory
extension Container: LogFileManagerFactory {
    public func makeLogFileManager() -> LogFileManager {
        LogFileManagerImplementation()
    }
}

// MARK: CoreApiServiceFactory
extension Container: CoreApiServiceFactory {
    public func makeCoreApiService() -> CoreApiService {
        CoreApiServiceImplementation(networking: makeNetworking())
    }
}

// MARK: PaymentsApiServiceFactory
extension Container: PaymentsApiServiceFactory {
    public func makePaymentsApiService() -> PaymentsApiService {
        PaymentsApiServiceImplementation(self)
    }
}

// MARK: ReportsApiServiceFactory
extension Container: ReportsApiServiceFactory {
    public func makeReportsApiService() -> ReportsApiService {
        ReportsApiService(self)
    }
}

// MARK: SafariServiceFactory
extension Container: SafariServiceFactory {
    public func makeSafariService() -> SafariServiceProtocol {
        SafariService()
    }
}

// MARK: AnnouncementStorageFactory
extension Container: AnnouncementStorageFactory {
    public func makeAnnouncementStorage() -> AnnouncementStorage {
        AnnouncementStorageUserDefaults(userDefaults: Storage.userDefaults(),
                                        keyNameProvider: nil)
    }
}

// MARK: AnnouncementRefresherFactory
extension Container: AnnouncementRefresherFactory {
    public func makeAnnouncementRefresher() -> AnnouncementRefresher {
        announcementRefresher
    }
}

// MARK: - AnnouncementManagerFactory
extension Container: AnnouncementManagerFactory {
    public func makeAnnouncementManager() -> AnnouncementManager {
        AnnouncementManagerImplementation(factory: self)
    }
}

// MARK: AnnouncementsViewModelFactory
extension Container: AnnouncementsViewModelFactory {
    public func makeAnnouncementsViewModel() -> AnnouncementsViewModel {
        announcementsViewModel
    }
}

// MARK: ReportBugViewModelFactory
extension Container: ReportBugViewModelFactory {
    public func makeReportBugViewModel() -> ReportBugViewModel {
        ReportBugViewModel(self, config: config)
    }
}

// MARK: TroubleshootViewModelFactory
extension Container: TroubleshootViewModelFactory {
    public func makeTroubleshootViewModel() -> TroubleshootViewModel {
        return TroubleshootViewModel(propertiesManager: makePropertiesManager())
    }
}

// MARK: MaintenanceManagerFactory
extension Container: MaintenanceManagerFactory {
    public func makeMaintenanceManager() -> MaintenanceManagerProtocol {
        return maintenanceManager
    }
}

// MARK: MaintenanceManagerHelperFactory
extension Container: MaintenanceManagerHelperFactory {
    public func makeMaintenanceManagerHelper() -> MaintenanceManagerHelper {
        return maintenanceManagerHelper
    }
}

// MARK: DynamicBugReportManagerFactory
extension Container: DynamicBugReportManagerFactory {
    public func makeDynamicBugReportManager() -> DynamicBugReportManager {
        return dynamicBugReportManager
    }
}

// MARK: TimerFactoryCreator
extension Container: TimerFactoryCreator {
    public func makeTimerFactory() -> TimerFactory {
        return timerFactory
    }
}

// MARK: LocalAgentConnectionFactoryCreator
extension Container: LocalAgentConnectionFactoryCreator {
    public func makeLocalAgentConnectionFactory() -> LocalAgentConnectionFactory {
        LocalAgentConnectionFactoryImplementation()
    }
}

// MARK: IkeProtocolFactoryCreator
extension Container: IkeProtocolFactoryCreator {
    public func makeIkeProtocolFactory() -> IkeProtocolFactory {
        ikeFactory
    }
}

// MARK: ProfileStorageFactory
extension Container: ProfileStorageFactory {
    public func makeProfileStorage() -> ProfileStorage {
        ProfileStorage(self)
    }
}

extension Container: DynamicBugReportStorageFactory {
    public func makeDynamicBugReportStorage() -> DynamicBugReportStorage {
        DynamicBugReportStorageUserDefaults(self)
    }
}

extension Container: SiriHelperFactory {
    public func makeSiriHelper() -> SiriHelperProtocol {
        SiriHelper()
    }
}

extension Container: TelemetryServiceFactory {
    public func makeTelemetryService() async -> TelemetryService {
        return await _telemetryServiceTask.value
    }
}

extension Container: TelemetryAPIFactory {
    public func makeTelemetryAPI(networking: Networking) -> TelemetryAPI {
        TelemetryAPIImplementation(networking: networking)
    }
}
