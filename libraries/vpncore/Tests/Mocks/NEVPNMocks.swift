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
    var connectionWasCreated: ((NEVPNConnectionMock) -> Void)?

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
        let connection = NEVPNConnectionMock(vpnManager: self)
        connectionWasCreated?(connection)
        return connection
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
        defer { completionHandler(nil) }

        guard let prefs = Self.whatIsSavedToPreferences else { return }
        setSavedConfiguration(prefs)
    }

    func saveToPreferences(completionHandler: ((Error?) -> Void)?) {
        Self.whatIsSavedToPreferences = SavedPreferences(self)
        completionHandler?(nil)
    }

    func removeFromPreferences(completionHandler: ((Error?) -> Void)?) {
        Self.whatIsSavedToPreferences = nil
        completionHandler?(nil)
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
    var tunnelProvidersInPreferences: [UUID: NETunnelProviderManagerWrapper] = [:]
    var newManagerCreated: ((NETunnelProviderManagerMock) -> ())?

    func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        completionHandler(tunnelProvidersInPreferences.values.map { $0 }, nil)
    }

    func makeNewManager() -> NETunnelProviderManagerWrapper {
        let manager = NETunnelProviderManagerMock(factory: self)
        newManagerCreated?(manager)
        return manager
    }
}

class NETunnelProviderManagerMock: NEVPNManagerMock, NETunnelProviderManagerWrapper {
    let uuid: UUID

    weak var factory: NETunnelProviderManagerFactoryMock?

    init(factory: NETunnelProviderManagerFactoryMock?) {
        self.uuid = UUID()
        self.factory = factory
    }

    static var tunnelProviderPreferencesData: [UUID: NEVPNManagerMock.SavedPreferences] = [:]

    override func saveToPreferences(completionHandler: ((Error?) -> Void)?) {
        let prefs = NEVPNManagerMock.SavedPreferences(self)
        factory?.tunnelProvidersInPreferences[uuid] = self
        NETunnelProviderManagerMock.tunnelProviderPreferencesData[uuid] = prefs
        completionHandler?(nil)
    }

    override func loadFromPreferences(completionHandler: @escaping (Error?) -> Void) {
        guard let prefs = Self.tunnelProviderPreferencesData[uuid] else {
            completionHandler(nil)
            return
        }

        setSavedConfiguration(prefs)
        completionHandler(nil)
    }

    override func removeFromPreferences(completionHandler: ((Error?) -> Void)?) {
        factory?.tunnelProvidersInPreferences[uuid] = nil
        Self.tunnelProviderPreferencesData[uuid] = nil
        completionHandler?(nil)
    }
}

class NEVPNConnectionMock: NEVPNConnectionWrapper {
    var tunnelStateDidChange: ((NEVPNStatus) -> ())?
    var tunnelStartError: NEVPNError?

    let vpnManager: NEVPNManagerWrapper
    var status: NEVPNStatus
    var connectedDate: Date?

    init(vpnManager: NEVPNManagerWrapper) {
        self.vpnManager = vpnManager
        self.status = .invalid
        self.connectedDate = nil
    }

    func startVPNTunnel() throws {
        if let tunnelStartError = tunnelStartError {
            throw tunnelStartError
        }

        connectedDate = Date()

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }

            self.status = .connecting
            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: nil, userInfo: nil)
            self.tunnelStateDidChange?(self.status)
        }

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }

            self.status = .connected
            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: nil, userInfo: nil)
            self.tunnelStateDidChange?(self.status)
        }
    }

    func stopVPNTunnel() {
        connectedDate = nil

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }

            self.status = .disconnecting
            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: nil, userInfo: nil)
            self.tunnelStateDidChange?(self.status)
        }

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }

            self.status = .disconnected
            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: nil, userInfo: nil)
            self.tunnelStateDidChange?(self.status)
        }
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
