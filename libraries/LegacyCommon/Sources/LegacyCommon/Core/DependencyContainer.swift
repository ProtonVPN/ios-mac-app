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
import Localization
import PMLogger
import VPNShared
import Dependencies

import ProtonCorePushNotifications

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
        public let pinApiEndpoints: Bool

        public var osVersion: String {
            ProcessInfo.processInfo.operatingSystemVersionString
        }

        public init(
            os: String,
            appIdentifierPrefix: String,
            appGroup: String,
            accessGroup: String,
            openVpnExtensionBundleIdentifier: String,
            wireguardVpnExtensionBundleIdentifier: String,
            pinApiEndpoints: Bool
        ) {
            self.os = os
            self.appIdentifierPrefix = appIdentifierPrefix
            self.appGroup = appGroup
            self.accessGroup = accessGroup
            self.openVpnExtensionBundleIdentifier = openVpnExtensionBundleIdentifier
            self.wireguardVpnExtensionBundleIdentifier = wireguardVpnExtensionBundleIdentifier
            self.pinApiEndpoints = pinApiEndpoints
        }
    }

    @Dependency(\.date) var date

    public let config: Config

    // Lazy instances - get allocated once, and stay allocated
    @Dependency(\.storage) var storage
    private lazy var propertiesManager: PropertiesManagerProtocol = PropertiesManager.default
    private lazy var vpnKeychain: VpnKeychainProtocol = VpnKeychain.instance
    private lazy var authKeychain: AuthKeychainHandle = AuthKeychain.default
    private lazy var unauthKeychain: UnauthKeychainHandle = UnauthKeychain()
    private lazy var profileManager = ProfileManager(self)
    private lazy var networking = CoreNetworking(self, pinApiEndpoints: config.pinApiEndpoints)
    private lazy var ikeFactory = IkeProtocolFactory(factory: self)
    private lazy var vpnAuthenticationKeychain = VpnAuthenticationKeychain(accessGroup: config.accessGroup,
                                                                           vpnKeysGenerator: CoreVPNKeysGenerator())
    private lazy var vpnManager: VpnManagerProtocol = VpnManager(self, config: config)
    private lazy var vpnGateway: VpnGatewayProtocol = VpnGateway(self)

    private lazy var timerFactory = TimerFactoryImplementation()

    private lazy var appStateManager: AppStateManager = AppStateManagerImplementation(self)

    private lazy var announcementsViewModel: AnnouncementsViewModel = AnnouncementsViewModel(factory: self)

    private lazy var pushNotificationService: PushNotificationServiceProtocol = PushNotificationService(apiService: networking.apiService)
    // Refreshes announcements from API
    private lazy var announcementRefresher = AnnouncementRefresherImplementation(factory: self)

    private lazy var maintenanceManager: MaintenanceManagerProtocol = MaintenanceManager(factory: self)
    private lazy var maintenanceManagerHelper: MaintenanceManagerHelper = MaintenanceManagerHelper(factory: self)

    // Instance of DynamicBugReportManager is persisted because it has a timer that refreshes config from time to time.
    private lazy var dynamicBugReportManager = DynamicBugReportManager(self)

    private lazy var telemetrySettings: TelemetrySettings = makeTelemetrySettings()
    private lazy var _telemetryServiceTask = Task {
        await TelemetryServiceImplementation(factory: self)
    }

    private var telemetryService: TelemetryService?

    // Should be set in apps to the Container object
    public static var sharedContainer: Container!

    public init(_ config: Config) {
        self.config = config
    }

    /// Call this method from `application(didFinishLaunchingWithOptions)` of the app.
    /// It does preparation work needed at the start of the app, but which can't be done in `init` because it's too early.
    public func applicationDidFinishLaunching() {
        Task {
            // We need to initialise the TelemetryService somewhere because no other part of the code uses it directly.
            // TelemetryService listens to notifications and sends telemetry events based on that.
            self.telemetryService = await makeTelemetryService()

            if !propertiesManager.isSubsequentLaunch {
                // The app launched for the first time since the last install.
                // Since the telemetry is on by default, there is no way of disabling this event.
                // If we remove the app, we'll still be logged in, but the telemetry settings will be reset to it's default, "On" state.
                try? await telemetryService?.onboardingEvent(.firstLaunch)
                propertiesManager.isSubsequentLaunch = true
            }
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
        [
            MisconfiguredLocalNetworkIntercept(factory: self)
        ]
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

extension Container: UnauthKeychainHandleFactory {
    public func makeUnauthKeychainHandle() -> UnauthKeychainHandle {
        unauthKeychain
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

    public func loadManagersFromPreferences() async throws -> [NETunnelProviderManagerWrapper] {
        try await NETunnelProviderManager.loadAllFromPreferences()
    }
}

// MARK: NATTypePropertyProviderFactory
extension Container: NATTypePropertyProviderFactory {
    public func makeNATTypePropertyProvider() -> NATTypePropertyProvider {
        NATTypePropertyProviderImplementation()
    }
}

// MARK: SafeModePropertyProviderFactory
extension Container: SafeModePropertyProviderFactory {
    public func makeSafeModePropertyProvider() -> SafeModePropertyProvider {
        SafeModePropertyProviderImplementation()
    }
}

// MARK: NetShieldPropertyProviderFactory
extension Container: NetShieldPropertyProviderFactory {
    public func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider {
        NetShieldPropertyProviderImplementation()
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
    public func makeVpnAuthenticationStorage() -> VpnAuthenticationStorageSync {
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
        vpnGateway
    }
}

// MARK: VpnGateway2Factory
extension Container: VpnGateway2Factory {
    public func makeVpnGateway2() -> VpnGatewayProtocol2 {
        VpnGateway2(self)
    }
}

// MARK: ServerTierCheckerFactory
extension Container: ServerTierCheckerFactory {
    func makeServerTierChecker() -> ServerTierChecker {
        ServerTierChecker(alertService: makeCoreAlertService(), vpnKeychain: makeVpnKeychain())
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

// MARK: PushNotificationsServiceFactory
extension Container: PushNotificationServiceFactory {
    public func makePushNotificationService() -> ProtonCorePushNotifications.PushNotificationServiceProtocol {
        pushNotificationService
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
        @Dependency(\.defaultsProvider) var provider
        return AnnouncementStorageUserDefaults(userDefaults: provider.getDefaults(), keyNameProvider: nil)
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

// MARK: DynamicBugReportStorageFactory
extension Container: DynamicBugReportStorageFactory {
    public func makeDynamicBugReportStorage() -> DynamicBugReportStorage {
        DynamicBugReportStorageUserDefaults()
    }
}

// MARK: SiriHelperFactory
extension Container: SiriHelperFactory {
    public func makeSiriHelper() -> SiriHelperProtocol {
        SiriHelper()
    }
}

// MARK: TelemetryServiceFactory
extension Container: TelemetryServiceFactory {
    public func makeTelemetryService() async -> TelemetryService {
        return await _telemetryServiceTask.value
    }
}

// MARK: TelemetrySettingsFactory
extension Container: TelemetrySettingsFactory {
    public func makeTelemetrySettings() -> TelemetrySettings {
        return TelemetrySettings(self)
    }
}

// MARK: TelemetryAPIFactory
extension Container: TelemetryAPIFactory {
    public func makeTelemetryAPI(networking: Networking) -> TelemetryAPI {
        TelemetryAPIImplementation(networking: networking)
    }
}

extension Container: NetworkInterfacePropertiesProviderFactory {
    public func makeInterfacePropertiesProvider() -> NetworkInterfacePropertiesProvider {
        NetworkInterfacePropertiesProviderImplementation()
    }
}

extension Container: CountryCodeProviderFactory {
    public func makeCountryCodeProvider() -> CountryCodeProvider {
        CountryCodeProviderImplementation()
    }
}
