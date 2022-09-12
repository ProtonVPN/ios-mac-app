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

open class Container: DoHVPNFactory, NetworkingDelegateFactory {
    public struct Config {
        public let appIdentifierPrefix: String
        public let appGroup: String

        public init(appIdentifierPrefix: String,
                    appGroup: String) {
            self.appIdentifierPrefix = appIdentifierPrefix
            self.appGroup = appGroup
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

// MARK: - Factories and methods to override
    #if os(macOS)
    open var modelId: String? {
        nil
    }
    #endif

    // MARK: DoHVPNFactory
    open func makeDoHVPN() -> DoHVPN {
        shouldHaveOverridden()
    }

    open func makeNetworkingDelegate() -> NetworkingDelegate {
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
        AppInfoImplementation(context: context, modelName: modelId)
    }
}

// MARK: NetworkingFactory
extension Container: NetworkingFactory {
    public func makeNetworking() -> Networking {
        networking
    }
}
