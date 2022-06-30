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
        let connection: NEVPNConnectionMock

        // this is a bit of a hack, since we can't override the stored property in NETunnelProviderManagerMock
        if self is NETunnelProviderManagerMock {
            connection = NETunnelProviderSessionMock(vpnManager: self)
        } else {
            connection = NEVPNConnectionMock(vpnManager: self)
        }

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
    static let queue = DispatchQueue(label: "mock tunnel provider factory queue")
    var tunnelProvidersInPreferences: [UUID: NETunnelProviderManagerWrapper] = [:]
    var tunnelProviderPreferencesData: [UUID: NEVPNManagerMock.SavedPreferences] = [:]

    var newManagerCreated: ((NETunnelProviderManagerMock) -> ())?

    func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        Self.queue.async { [unowned self] in
            completionHandler(self.tunnelProvidersInPreferences.values.map { $0 }, nil)
        }
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

    override func saveToPreferences(completionHandler: ((Error?) -> Void)?) {
        NETunnelProviderManagerFactoryMock.queue.async { [unowned self] in
            let prefs = NEVPNManagerMock.SavedPreferences(self)
            self.factory?.tunnelProvidersInPreferences[uuid] = self
            self.factory?.tunnelProviderPreferencesData[self.uuid] = prefs
            completionHandler?(nil)
        }
    }

    override func loadFromPreferences(completionHandler: @escaping (Error?) -> Void) {
        NETunnelProviderManagerFactoryMock.queue.async { [unowned self] in
            guard let prefs = self.factory?.tunnelProviderPreferencesData[self.uuid] else {
                completionHandler(nil)
                return
            }

            self.setSavedConfiguration(prefs)
            completionHandler(nil)
        }
    }

    override func removeFromPreferences(completionHandler: ((Error?) -> Void)?) {
        NETunnelProviderManagerFactoryMock.queue.async { [unowned self] in
            self.factory?.tunnelProvidersInPreferences[self.uuid] = nil
            self.factory?.tunnelProviderPreferencesData[self.uuid] = nil
            completionHandler?(nil)
        }
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

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }

            self.status = .connecting
            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: nil, userInfo: nil)
            self.tunnelStateDidChange?(self.status)
        }

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }

            self.status = .connected
            self.connectedDate = Date()

            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: nil, userInfo: nil)
            self.tunnelStateDidChange?(self.status)
        }
    }

    func stopVPNTunnel() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }

            self.connectedDate = nil
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
