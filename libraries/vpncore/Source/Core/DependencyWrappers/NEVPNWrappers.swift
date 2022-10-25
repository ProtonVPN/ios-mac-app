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
import VPNShared

public protocol NEVPNManagerWrapper: AnyObject {
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

public protocol NETunnelProviderSessionWrapper: NEVPNConnectionWrapper, ProviderMessageSender {
    func sendProviderMessage(_ messageData: Data, responseHandler: ((Data?) -> Void)?) throws
}

/// For `ProviderMessageSender`
extension NETunnelProviderSessionWrapper {
    public func send<R>(_ message: R, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?) where R: ProviderRequest {
        send(message, maxRetries: 5, completion: completion)
    }

    private func send<R>(_ message: R, maxRetries: Int, completion: ((Result<R.Response, ProviderMessageError>) -> Void)?) where R: ProviderRequest {
        do {
            try sendProviderMessage(message.asData) { [weak self] maybeData in
                guard let data = maybeData else {
                    // From documentation: "If this method can’t start sending the message it throws an error. If an
                    // error occurs while sending the message or returning the result, `nil` should be sent to the
                    // response handler as notification." If we encounter an xpc error, try sleeping for a second and
                    // then trying again - the extension could still be launching, or we could be coming out of sleep.
                    // If we retry enough times and still get nowhere, return an error.

                    guard maxRetries > 0 else {
                        completion?(.failure(.noDataReceived))
                        return
                    }

                    sleep(1)
                    self?.send(message, maxRetries: maxRetries - 1, completion: completion)
                    return
                }

                do {
                    let response = try R.Response.decode(data: data)
                    completion?(.success(response))
                } catch {
                    completion?(.failure(.decodingError))
                }
            }
        } catch {
            log.error("Received error while attempting to send provider message: \(error)", category: .connection)
            completion?(.failure(.sendingError))
        }
    }
}

extension NETunnelProviderSession: NETunnelProviderSessionWrapper {
}
