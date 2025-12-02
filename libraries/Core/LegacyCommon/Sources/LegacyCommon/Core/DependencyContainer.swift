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

import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import Foundation
import Localization
import NetworkExtension
import PMLogger
import Timer
import VPNAppCore
import VPNShared

import ProtonCoreFeatureFlags
import ProtonCorePushNotifications

typealias PropertiesToOverride =
    CoreAlertServiceFactory &
    NetworkingDelegateFactory &
    UpdateCheckerFactory &
    VpnAuthenticationFactory &
    VpnConnectionInterceptDelegate &
    VpnCredentialsConfiguratorFactoryCreator

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

        public init(
            os: String,
            appIdentifierPrefix: String,
            appGroup: String,
            accessGroup: String,
            openVpnExtensionBundleIdentifier: String,
            wireguardVpnExtensionBundleIdentifier: String
        ) {
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
    @Dependency(\.storage) var storage
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.networking) var networking
    private lazy var profileManager = ProfileManager(self)
    private lazy var wireguardProtocolFactory = WireguardProtocolFactory(
        bundleId: config.wireguardVpnExtensionBundleIdentifier,
        appGroup: config.appGroup,
        vpnManagerFactory: self
    )
    private lazy var ikeFactory = IkeProtocolFactory(factory: self)
    private lazy var vpnManager: VpnManagerProtocol = VpnManager(self, config: config)
    private lazy var vpnGateway: VpnGatewayProtocol = VpnGateway(self)

    private lazy var appStateManager: AppStateManager = AppStateManagerImplementation(self)

    private lazy var pushNotificationService: PushNotificationServiceProtocol = PushNotificationService(apiService: networking.apiService)

    private lazy var maintenanceManager: MaintenanceManagerProtocol = MaintenanceManager(factory: self)
    private lazy var maintenanceManagerHelper: MaintenanceManagerHelper = .init(factory: self)

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

            @Dependency(\.vpnKeychain) var vpnKeychain

            if !propertiesManager.firstLaunchReported {
                // The app launched for the first time since the last install.
                // Since the telemetry is on by default, there is no way of disabling this event.
                // If we remove the app, we'll still be logged in, but the telemetry settings will be reset to it's default, "On" state.
                try? await telemetryService?.onboardingEvent(.firstLaunch)
                propertiesManager.firstLaunchReported = true
            } else if vpnKeychain.userIsLoggedIn { // we flip this bool only on the second launch and only when the user is logged in
                propertiesManager.isSubsequentLaunch = true
            }

            // Start settingsHeartbeat scheduled telemetry report
            self.telemetryService?.startSettingsHeartbeat()
        }
    }

    func shouldHaveOverridden(caller: StaticString = #function) -> Never {
        fatalError("Should have overridden \(caller)")
    }

    // MARK: - Configs to override

    #if os(macOS)
        open var vpnConnectionInterceptPolicies: [VpnConnectionInterceptPolicyItem] {
            [
                MisconfiguredLocalNetworkIntercept(factory: self),
                PlutoniumIKEv2ConflictIntercept(factory: self),
            ]
        }
    #else
        open var vpnConnectionInterceptPolicies: [VpnConnectionInterceptPolicyItem] {
            [
                MisconfiguredLocalNetworkIntercept(factory: self),
            ]
        }
    #endif

    // MARK: - Factories to override

    // MARK: NetworkingDelegate

    open func makeNetworkingDelegate() -> NetworkingDelegate {
        shouldHaveOverridden()
    }

    // MARK: CoreAlertService

    open func makeCoreAlertService() -> CoreAlertService {
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

    open func makeUpdateChecker() -> UpdateChecker {
        shouldHaveOverridden()
    }
}

// MARK: ProfileManagerFactory

extension Container: ProfileManagerFactory {
    public func makeProfileManager() -> ProfileManager {
        profileManager
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

// MARK: VpnStateConfigurationFactory

extension Container: VpnStateConfigurationFactory {
    public func makeVpnStateConfiguration() -> VpnStateConfiguration {
        VpnStateConfigurationManager(self, config: config)
    }
}

extension Container: VpnManagerFactory {
    private var shouldUseNoOpManager: Bool {
        FeatureFlagsRepository.isConnectionFeatureEnabled
    }

    public func makeVpnManager() -> VpnManagerProtocol {
        if shouldUseNoOpManager {
            log.info("Legacy connection: returning NoOpVPNManager", category: .connection)
            return NoOpVpnManager()
        } else {
            return vpnManager
        }
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
    public func makeAvailabilityCheckerResolver(wireguardConfig: WireguardConfig) -> AvailabilityCheckerResolver {
        AvailabilityCheckerResolverImplementation(wireguardConfig: wireguardConfig)
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
        ServerTierChecker(alertService: makeCoreAlertService())
    }
}

// MARK: PushNotificationsServiceFactory

extension Container: PushNotificationServiceFactory {
    public func makePushNotificationService() -> ProtonCorePushNotifications.PushNotificationServiceProtocol {
        pushNotificationService
    }
}

// MARK: TroubleshootViewModelFactory

extension Container: TroubleshootViewModelFactory {
    public func makeTroubleshootViewModel() -> TroubleshootViewModel {
        TroubleshootViewModel()
    }
}

// MARK: MaintenanceManagerFactory

extension Container: MaintenanceManagerFactory {
    public func makeMaintenanceManager() -> MaintenanceManagerProtocol {
        maintenanceManager
    }
}

// MARK: MaintenanceManagerHelperFactory

extension Container: MaintenanceManagerHelperFactory {
    public func makeMaintenanceManagerHelper() -> MaintenanceManagerHelper {
        maintenanceManagerHelper
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

// MARK: WireguardProtocolFactoryCreator

extension Container: WireguardProtocolFactoryCreator {
    public func makeWireguardProtocolFactory() -> WireguardProtocolFactory {
        wireguardProtocolFactory
    }
}

// MARK: ProfileStorageFactory

extension Container: ProfileStorageFactory {
    public func makeProfileStorage() -> ProfileStorage {
        ProfileStorage()
    }
}

// MARK: TelemetryServiceFactory

extension Container: TelemetryServiceFactory {
    public func makeTelemetryService() async -> TelemetryService {
        await _telemetryServiceTask.value
    }
}

// MARK: TelemetrySettingsFactory

extension Container: TelemetrySettingsFactory {
    public func makeTelemetrySettings() -> TelemetrySettings {
        TelemetrySettings()
    }
}

// MARK: TelemetryAPIFactory

extension Container: TelemetryAPIFactory {
    public func makeTelemetryAPI() -> TelemetryAPI {
        TelemetryAPIImplementation()
    }
}

extension Container: NetworkInterfacePropertiesProviderFactory {
    public func makeInterfacePropertiesProvider() -> NetworkInterfacePropertiesProvider {
        NetworkInterfacePropertiesProviderImplementation()
    }
}
