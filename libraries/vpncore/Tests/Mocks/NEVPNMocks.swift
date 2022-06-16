//
//  Created on 2022-06-16.
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

enum NEMockError: Error {
    case invalidProviderConfiguration
}

class NEVPNManagerMock: NEVPNManagerWrapper {
    struct SavedPreferences {
        let protocolConfiguration: NEVPNProtocol?
        let isEnabled: Bool
        let isOnDemandEnabled: Bool
        let onDemandRules: [NEOnDemandRule]?
    }

    static var whatIsSavedToPreferences: SavedPreferences?

    var protocolConfiguration: NEVPNProtocol?
    var isEnabled: Bool
    var isOnDemandEnabled: Bool
    var onDemandRules: [NEOnDemandRule]?

    lazy var vpnConnection: NEVPNConnectionWrapper = {
        NEVPNConnectionMock(vpnManager: self)
    }()

    init() {
        isEnabled = false
        isOnDemandEnabled = false
    }

    func setSavedConfiguration(_ prefs: SavedPreferences) {
        self.protocolConfiguration = prefs.protocolConfiguration
        self.onDemandRules = prefs.onDemandRules
        self.isOnDemandEnabled = prefs.isOnDemandEnabled
        self.isEnabled = prefs.isEnabled
    }

    func loadFromPreferences(completionHandler: @escaping (Error?) -> Void) {
        guard let prefs = Self.whatIsSavedToPreferences else { return }
        setSavedConfiguration(prefs)
    }

    func saveToPreferences(completionHandler: ((Error?) -> Void)?) {
        Self.whatIsSavedToPreferences = SavedPreferences(self)
    }

    func removeFromPreferences(completionHandler: ((Error?) -> Void)?) {
        Self.whatIsSavedToPreferences = nil
    }
}

extension NEVPNManagerMock.SavedPreferences {
    init(_ manager: NEVPNManagerWrapper) {
        self.isOnDemandEnabled = manager.isOnDemandEnabled
        self.isEnabled = manager.isEnabled
        self.onDemandRules = manager.onDemandRules
        self.protocolConfiguration = manager.protocolConfiguration
    }
}

class NETunnelProviderManagerFactoryMock: NETunnelProviderManagerWrapperFactory {
    var tunnelProvidersInPreferences: [String: NETunnelProviderManagerWrapper] = [:]

    func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        completionHandler(tunnelProvidersInPreferences.values.map { $0 }, nil)
    }

    func makeNewManager() -> NETunnelProviderManagerWrapper {
        NETunnelProviderManagerMock(factory: self)
    }
}

class NETunnelProviderManagerMock: NEVPNManagerMock, NETunnelProviderManagerWrapper {
    weak var factory: NETunnelProviderManagerFactoryMock?

    init(factory: NETunnelProviderManagerFactoryMock?) {
        self.factory = factory
    }

    static var tunnelProviderPreferencesData: [String: NEVPNManagerMock.SavedPreferences] = [:]

    override func saveToPreferences(completionHandler: ((Error?) -> Void)?) {
        guard let config = self.protocolConfiguration as? NETunnelProviderProtocol,
            let bundleId = config.providerBundleIdentifier else {
            completionHandler?(NEMockError.invalidProviderConfiguration)
            return
        }

        let prefs = NEVPNManagerMock.SavedPreferences(self)
        factory?.tunnelProvidersInPreferences[bundleId] = self
        NETunnelProviderManagerMock.tunnelProviderPreferencesData[bundleId] = prefs
    }

    override func loadFromPreferences(completionHandler: @escaping (Error?) -> Void) {
        guard let config = self.protocolConfiguration as? NETunnelProviderProtocol,
            let bundleId = config.providerBundleIdentifier else {
            completionHandler(NEMockError.invalidProviderConfiguration)
            return
        }

        guard let prefs = Self.tunnelProviderPreferencesData[bundleId] else {
            completionHandler(nil)
            return
        }

        setSavedConfiguration(prefs)
        completionHandler(nil)
    }

    override func removeFromPreferences(completionHandler: ((Error?) -> Void)?) {
        guard let config = self.protocolConfiguration as? NETunnelProviderProtocol,
            let bundleId = config.providerBundleIdentifier else {
            completionHandler?(NEMockError.invalidProviderConfiguration)
            return
        }

        factory?.tunnelProvidersInPreferences[bundleId] = nil
        Self.tunnelProviderPreferencesData[bundleId] = nil
    }
}

class NEVPNConnectionMock: NEVPNConnectionWrapper {
    let vpnManager: NEVPNManagerWrapper
    var status: NEVPNStatus
    var connectedDate: Date?

    init(vpnManager: NEVPNManagerWrapper) {
        self.vpnManager = vpnManager
        self.status = .invalid
        self.connectedDate = nil
    }

    func startVPNTunnel() throws {
        connectedDate = Date()
    }

    func stopVPNTunnel() {
        connectedDate = nil
    }
}

class NETunnelProviderSessionMock: NEVPNConnectionMock, NETunnelProviderSessionWrapper {
    var providerMessageSent: ((Data) -> Data?)? = nil

    func sendProviderMessage(_ messageData: Data, responseHandler: ((Data?) -> Void)?) throws {
        let response = providerMessageSent?(messageData)

        if let responseHandler = responseHandler {
            responseHandler(response)
        }
    }
}
