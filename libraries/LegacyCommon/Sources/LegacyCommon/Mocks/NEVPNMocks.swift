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

#if DEBUG
import Foundation
import NetworkExtension

import XCTestDynamicOverlay

import ExtensionIPC
import VPNShared

public enum NEMockError: Error {
    case invalidProviderConfiguration
}

public class NEVPNManagerMock: NEVPNManagerWrapper {
    public static let managerCreatedNotification = NSNotification.Name("MockManagerWasCreated")

    public struct SavedPreferences {
        public let protocolConfiguration: NEVPNProtocol?
        public let isEnabled: Bool
        public let isOnDemandEnabled: Bool
        public let onDemandRules: [NEOnDemandRule]?
    }

    public static var whatIsSavedToPreferences: SavedPreferences?

    public var protocolConfiguration: NEVPNProtocol?
    public var isEnabled: Bool
    public var isOnDemandEnabled: Bool
    public var onDemandRules: [NEOnDemandRule]?

    public lazy var vpnConnection: NEVPNConnectionWrapper = {
        let connection: NEVPNConnectionMock

        // this is a bit of a hack, since we can't override the stored property in NETunnelProviderManagerMock
        if self is NETunnelProviderManagerMock {
            connection = NETunnelProviderSessionMock(vpnManager: self)
        } else {
            connection = NEVPNConnectionMock(vpnManager: self)
        }

        NotificationCenter.default.post(name: NEVPNConnectionMock.connectionCreatedNotification, object: connection)
        return connection
    }()

    public init() {
        isEnabled = false
        isOnDemandEnabled = false
    }

    public func setSavedConfiguration(_ prefs: SavedPreferences) {
        self.protocolConfiguration = prefs.protocolConfiguration
        self.onDemandRules = prefs.onDemandRules
        self.isOnDemandEnabled = prefs.isOnDemandEnabled
        self.isEnabled = prefs.isEnabled
    }

    public func loadFromPreferences(completionHandler: @escaping (Error?) -> Void) {
        defer { completionHandler(nil) }

        guard let prefs = Self.whatIsSavedToPreferences else { return }
        setSavedConfiguration(prefs)
    }

    public func saveToPreferences(completionHandler: ((Error?) -> Void)?) {
        Self.whatIsSavedToPreferences = SavedPreferences(self)
        completionHandler?(nil)
    }

    public func removeFromPreferences(completionHandler: ((Error?) -> Void)?) {
        Self.whatIsSavedToPreferences = nil
        completionHandler?(nil)
    }
}

extension NEVPNManagerMock.SavedPreferences {
    public init(_ manager: NEVPNManagerWrapper) {
        self.isOnDemandEnabled = manager.isOnDemandEnabled
        self.isEnabled = manager.isEnabled
        self.onDemandRules = manager.onDemandRules
        self.protocolConfiguration = manager.protocolConfiguration
    }
}

public class NETunnelProviderManagerFactoryMock: NETunnelProviderManagerWrapperFactory {
    public static let queue = DispatchQueue(label: "mock tunnel provider factory queue")
    public var tunnelProvidersInPreferences: [UUID: NETunnelProviderManagerWrapper] = [:]
    public var tunnelProviderPreferencesData: [UUID: NEVPNManagerMock.SavedPreferences] = [:]

    public func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        Self.queue.async { [unowned self] in
            completionHandler(self.tunnelProvidersInPreferences.values.map { $0 }, nil)
        }
    }

    public func makeNewManager() -> NETunnelProviderManagerWrapper {
        let manager = NETunnelProviderManagerMock(factory: self)
        NotificationCenter.default.post(name: NEVPNManagerMock.managerCreatedNotification, object: manager)
        return manager
    }
}

public class NETunnelProviderManagerMock: NEVPNManagerMock, NETunnelProviderManagerWrapper {
    public let uuid: UUID

    public weak var factory: NETunnelProviderManagerFactoryMock?

    public init(factory: NETunnelProviderManagerFactoryMock?) {
        self.uuid = UUID()
        self.factory = factory
    }

    public override func saveToPreferences(completionHandler: ((Error?) -> Void)?) {
        NETunnelProviderManagerFactoryMock.queue.async { [unowned self] in
            let prefs = NEVPNManagerMock.SavedPreferences(self)
            self.factory?.tunnelProvidersInPreferences[uuid] = self
            self.factory?.tunnelProviderPreferencesData[self.uuid] = prefs
            completionHandler?(nil)
        }
    }

    public override func loadFromPreferences(completionHandler: @escaping (Error?) -> Void) {
        NETunnelProviderManagerFactoryMock.queue.async { [unowned self] in
            guard let prefs = self.factory?.tunnelProviderPreferencesData[self.uuid] else {
                completionHandler(nil)
                return
            }

            self.setSavedConfiguration(prefs)
            completionHandler(nil)
        }
    }

    public override func removeFromPreferences(completionHandler: ((Error?) -> Void)?) {
        NETunnelProviderManagerFactoryMock.queue.async { [unowned self] in
            self.factory?.tunnelProvidersInPreferences[self.uuid] = nil
            self.factory?.tunnelProviderPreferencesData[self.uuid] = nil
            completionHandler?(nil)
        }
    }
}

public class NEVPNConnectionMock: NEVPNConnectionWrapper {
    public static let connectionCreatedNotification = NSNotification.Name("MockConnectionWasCreated")
    public static let tunnelStateChangeNotification = NSNotification.Name("MockTunnelStateChanged")

    public var tunnelStartError: NEVPNError?

    public unowned let vpnManager: NEVPNManagerWrapper
    public var status: NEVPNStatus
    public var connectedDate: Date?

    let queue = DispatchQueue(label: "vpn connection")

    public init(vpnManager: NEVPNManagerWrapper) {
        self.vpnManager = vpnManager
        self.status = .invalid
        self.connectedDate = nil
    }

    public func startVPNTunnel() throws {
        if let tunnelStartError = tunnelStartError {
            throw tunnelStartError
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            self.queue.sync { self.status = .connecting }
            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: self, userInfo: nil)
            NotificationCenter.default.post(name: Self.tunnelStateChangeNotification, object: NEVPNStatus.connecting)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            self.queue.sync { self.status = .connected }
            self.connectedDate = Date()

            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: self, userInfo: nil)
            NotificationCenter.default.post(name: Self.tunnelStateChangeNotification, object: NEVPNStatus.connected)
        }
    }

    public func stopVPNTunnel() {
        let debounce = self.queue.sync { () -> Bool in
            guard self.status != .disconnecting && self.status != .disconnected else {
                return true
            }
            return false
        }
        guard !debounce else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            self.connectedDate = nil
            self.queue.sync { self.status = .disconnecting }
            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: self, userInfo: nil)
            NotificationCenter.default.post(name: Self.tunnelStateChangeNotification, object: NEVPNStatus.disconnecting)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            self.queue.sync { self.status = .disconnected }
            NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: self, userInfo: nil)
            NotificationCenter.default.post(name: Self.tunnelStateChangeNotification, object: NEVPNStatus.disconnected)
        }
    }
}

public class NETunnelProviderSessionMock: NEVPNConnectionMock, NETunnelProviderSessionWrapper {
    public var providerMessageSent: ((Data) -> Data?)?

    public func sendProviderMessage(_ messageData: Data, responseHandler: ((Data?) -> Void)?) throws {
        let response = providerMessageSent?(messageData)

        if let responseHandler = responseHandler {
            responseHandler(response)
        }
    }
}

public class WireguardProviderMessageSenderMock: ProviderMessageSender {
    public typealias Response = Result<WireguardProviderRequest.Response, ProviderMessageError>

    public var wireguardRequestSent: ((WireguardProviderRequest) -> Response)?

    public func send<R>(_ message: R, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?) where R : ProviderRequest {
        guard let request = message as? WireguardProviderRequest else {
            XCTFail("\(self): received incorrect message type: \(message)")
            return
        }

        guard let response = wireguardRequestSent?(request) else {
            XCTFail("\(self): request not handled: \(request)")
            return
        }

        switch response {
        case .success(let wireguardResponse):
            guard let genericResponse = wireguardResponse as? R.Response else {
                log.assertionFailure("This shouldn't be possible because `message` is a `WireguardProviderRequest`")
                return
            }
            completion?(.success(genericResponse))
        case .failure(let providerError):
            completion?(.failure(providerError))
        }
    }
}
#endif
