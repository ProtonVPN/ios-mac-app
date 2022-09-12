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

open class Container: DoHVPNFactory, NetworkingDelegateFactory, CoreAlertServiceFactory, OpenVpnProtocolFactoryCreator, WireguardProtocolFactoryCreator, VpnCredentialsConfiguratorFactoryCreator, VpnAuthenticationFactory {
    public struct Config {
        public let appIdentifierPrefix: String
        public let appGroup: String
        public let accessGroup: String
        public let openVpnExtensionBundleIdentifier: String
        public let wireguardVpnExtensionBundleIdentifier: String

        public init(appIdentifierPrefix: String,
                    appGroup: String,
                    accessGroup: String,
                    openVpnExtensionBundleIdentifier: String,
                    wireguardVpnExtensionBundleIdentifier: String) {
            self.appIdentifierPrefix = appIdentifierPrefix
            self.appGroup = appGroup
            self.accessGroup = accessGroup
            self.openVpnExtensionBundleIdentifier = openVpnExtensionBundleIdentifier
            self.wireguardVpnExtensionBundleIdentifier = wireguardVpnExtensionBundleIdentifier
        }
    }

    public let config: Config

    // Lazy instances - get allocated once, and stay allocated
    private lazy var storage = Storage()
    private lazy var propertiesManager: PropertiesManagerProtocol = PropertiesManager(storage: storage)
    private lazy var vpnKeychain: VpnKeychainProtocol = VpnKeychain()
    private lazy var authKeychain: AuthKeychainHandle = AuthKeychain(context: .mainApp)
    private lazy var profileManager = ProfileManager(serverStorage: makeServerStorage(), propertiesManager: makePropertiesManager(), profileStorage: ProfileStorage(authKeychain: makeAuthKeychainHandle()))
    private lazy var networking = CoreNetworking(delegate: makeNetworkingDelegate(),
                                                 appInfo: makeAppInfo(),
                                                 doh: makeDoHVPN(),
                                                 authKeychain: makeAuthKeychainHandle())
    private lazy var ikeFactory = IkeProtocolFactory(factory: self)
    private lazy var vpnAuthenticationKeychain = VpnAuthenticationKeychain(accessGroup: config.accessGroup,
                                                                           storage: makeStorage())
    private lazy var vpnManager: VpnManagerProtocol = VpnManager(ikeFactory: ikeFactory,
                                                                 openVpnFactory: makeOpenVpnProtocolFactory(),
                                                                 wireguardProtocolFactory: makeWireguardProtocolFactory(),
                                                                 appGroup: config.appGroup,
                                                                 vpnAuthentication: makeVpnAuthentication(),
                                                                 vpnKeychain: makeVpnKeychain(),
                                                                 propertiesManager: makePropertiesManager(),
                                                                 vpnStateConfiguration: makeVpnStateConfiguration(),
                                                                 alertService: makeCoreAlertService(),
                                                                 vpnCredentialsConfiguratorFactory: makeVpnCredentialsConfiguratorFactory(),
                                                                 localAgentConnectionFactory: LocalAgentConnectionFactoryImplementation(),
                                                                 natTypePropertyProvider: makeNATTypePropertyProvider(),
                                                                 netShieldPropertyProvider: makeNetShieldPropertyProvider(),
                                                                 safeModePropertyProvider: makeSafeModePropertyProvider())

    // Transient instances - get allocated as many times as they're referenced
    private var serverStorage: ServerStorage {
        ServerStorageConcrete()
    }

    public init(_ config: Config) {
        self.config = config
    }

    func shouldHaveOverridden(caller: StaticString = #function) -> Never {
        fatalError("Should have overridden \(caller)")
    }

    // MARK: - Configs to override
    open var openVpnExtensionBundleIdentifier: String {
        shouldHaveOverridden()
    }

    open var wireguardVpnExtensionBundleIdentifier: String {
        shouldHaveOverridden()
    }

    #if os(macOS)
    open var modelId: String? {
        shouldHaveOverridden()
    }
    #endif

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
        NATTypePropertyProviderImplementation(self, storage: storage)
    }
}

// MARK: SafeModePropertyProviderFactory
extension Container: SafeModePropertyProviderFactory {
    public func makeSafeModePropertyProvider() -> SafeModePropertyProvider {
        SafeModePropertyProviderImplementation(self, storage: storage)
    }
}

// MARK: NetShieldPropertyProviderFactory
extension Container: NetShieldPropertyProviderFactory {
    public func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider {
        NetShieldPropertyProviderImplementation(self, storage: storage)
    }
}

// MARK: VpnStateConfigurationFactory
extension Container: VpnStateConfigurationFactory {
    public func makeVpnStateConfiguration() -> VpnStateConfiguration {
        VpnStateConfigurationManager(ikeProtocolFactory: ikeFactory,
                                     openVpnProtocolFactory: makeOpenVpnProtocolFactory(),
                                     wireguardProtocolFactory: makeWireguardProtocolFactory(),
                                     propertiesManager: makePropertiesManager(),
                                     appGroup: config.appGroup)
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
