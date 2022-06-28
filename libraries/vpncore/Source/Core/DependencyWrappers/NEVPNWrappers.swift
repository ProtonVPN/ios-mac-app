//
//  Created on 2022-06-14.
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

public protocol NEVPNManagerWrapper {
    var vpnConnection: NEVPNConnectionWrapper { get }
    var protocolConfiguration: NEVPNProtocol? { get set }
    var isEnabled: Bool { get set }
    var isOnDemandEnabled: Bool { get set }
    var onDemandRules: [NEOnDemandRule]? { get set }

    func loadFromPreferences(completionHandler: @escaping (Error?) -> Void)
    func saveToPreferences(completionHandler: ((Error?) -> Void)?)
    func removeFromPreferences(completionHandler: ((Error?) -> Void)?)
}

extension NEVPNManager: NEVPNManagerWrapper {
    public var vpnConnection: NEVPNConnectionWrapper {
        self.connection
    }
}

public protocol NEVPNManagerWrapperFactory {
    func makeNEVPNManagerWrapper() -> NEVPNManagerWrapper
}

public protocol NETunnelProviderManagerWrapper: NEVPNManagerWrapper {
}

extension NETunnelProviderManager: NETunnelProviderManagerWrapper {
}

public protocol NETunnelProviderManagerWrapperFactory {
    func makeNewManager() -> NETunnelProviderManagerWrapper
    func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void)
}

extension NETunnelProviderManagerWrapperFactory {
    func tunnelProviderManagerWrapper(forProviderBundleIdentifier bundleId: String, completionHandler: @escaping (NETunnelProviderManagerWrapper?, Error?) -> Void) {
        loadManagersFromPreferences { (managers, error) in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            guard let managers = managers else {
                completionHandler(nil, ProtonVpnError.vpnManagerUnavailable)
                return
            }

            let vpnManager = managers.first(where: { (manager) -> Bool in
                return (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleId
            }) ?? self.makeNewManager()

            completionHandler(vpnManager, nil)
        }
    }
}

extension NETunnelProviderManager: NETunnelProviderManagerWrapperFactory {
    public func makeNewManager() -> NETunnelProviderManagerWrapper {
        NETunnelProviderManager()
    }

    public func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        Self.loadAllFromPreferences { managers, error in
            completionHandler(managers, error)
        }
    }
}

public protocol NEVPNConnectionWrapper {
    var vpnManager: NEVPNManagerWrapper { get }
    var status: NEVPNStatus { get }
    var connectedDate: Date? { get }

    func startVPNTunnel() throws
    func stopVPNTunnel()
}

extension NEVPNConnection: NEVPNConnectionWrapper {
    public var vpnManager: NEVPNManagerWrapper {
        self.manager
    }
}

public protocol NETunnelProviderSessionWrapper: NEVPNConnectionWrapper & ProviderMessageSender {
    func sendProviderMessage(_ messageData: Data, responseHandler: ((Data?) -> Void)?) throws
}

extension NETunnelProviderSession: NETunnelProviderSessionWrapper {
}
