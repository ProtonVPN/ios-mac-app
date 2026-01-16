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

import Dependencies
import DependenciesMacros

import Domain
import ExtensionIPC
import VPNShared

public protocol NEVPNManagerWrapper: AnyObject {
    var vpnConnection: NEVPNConnectionWrapper { get }
    var protocolConfiguration: NEVPNProtocol? { get set }
    var isEnabled: Bool { get set }
    var isOnDemandEnabled: Bool { get set }
    var onDemandRules: [NEOnDemandRule]? { get set }

    func loadFromPreferences(completionHandler: @escaping (Error?) -> Void)
    func loadFromPreferences() async throws
    func saveToPreferences(completionHandler: ((Error?) -> Void)?)
    func removeFromPreferences(completionHandler: ((Error?) -> Void)?)
}

extension NEVPNManager: NEVPNManagerWrapper {
    public var vpnConnection: NEVPNConnectionWrapper {
        connection
    }
}

public protocol NETunnelProviderManagerWrapper: NEVPNManagerWrapper {}

extension NETunnelProviderManager: NETunnelProviderManagerWrapper {}

@DependencyClient
public struct NEVPNManagerClient: Sendable {
    public var makeManager: @Sendable () -> NEVPNManagerWrapper = {
        NEVPNManager.shared()
    }
}

extension NEVPNManagerClient: DependencyKey {
    public static let liveValue = NEVPNManagerClient(
        makeManager: {
            NEVPNManager.shared()
        }
    )

    #if DEBUG
        public static let testValue: NEVPNManagerClient = .init(
            makeManager: {
                NEVPNManagerMock()
            }
        )
    #endif
}

public extension DependencyValues {
    var neVpnManagerClient: NEVPNManagerClient {
        get { self[NEVPNManagerClient.self] }
        set { self[NEVPNManagerClient.self] = newValue }
    }
}

@DependencyClient
public struct NETunnelProviderManagerClient: Sendable {
    public var loadManagers: @Sendable () async throws -> [NETunnelProviderManagerWrapper]
    public var getManagerForBundleSync: @Sendable (_ bundleIdentifier: String, _ completionHandler: @escaping (NETunnelProviderManagerWrapper?, Error?) -> Void) -> Void
    public var getManagerForBundle: @Sendable (_ bundleIdentifier: String) async throws -> NETunnelProviderManagerWrapper
}

extension NETunnelProviderManagerClient: DependencyKey {
    public static let liveValue = NETunnelProviderManagerClient(
        loadManagers: {
            try await NETunnelProviderManager.loadAllFromPreferences()
        },
        getManagerForBundleSync: { bundleId, completionHandler in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error {
                    completionHandler(nil, error)
                    return
                }
                guard let managers else {
                    completionHandler(nil, CommonVpnError.vpnManagerUnavailable)
                    return
                }

                let vpnManager = managers.first(where: { manager -> Bool in
                    return (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleId
                }) ?? NETunnelProviderManager()

                completionHandler(vpnManager, nil)
            }
        },
        getManagerForBundle: { bundleId in
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            return managers.first(where: { manager -> Bool in
                return (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleId
            }) ?? NETunnelProviderManager()
        }
    )

    #if DEBUG
        public static let testValue = NETunnelProviderManagerClient(
            loadManagers: {
                []
            },
            getManagerForBundleSync: { _, completionHandler in
                completionHandler(NETunnelProviderManagerMock(factory: nil), nil)
            },
            getManagerForBundle: { _ in
                NETunnelProviderManagerMock(factory: nil)
            }
        )
    #endif
}

public extension DependencyValues {
    var neTunnelProviderManager: NETunnelProviderManagerClient {
        get { self[NETunnelProviderManagerClient.self] }
        set { self[NETunnelProviderManagerClient.self] = newValue }
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
        manager
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
            log.debug(
                "NETunnelProviderSessionWrapper sending provider message",
                category: .ipc,
                metadata: [
                    "message": "\(message)",
                    "request": "\(String(describing: message as? WireguardProviderRequest))",
                ]
            )
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

                    log.debug(
                        "NETunnelProviderSessionWrapper encountered xpc error, retrying in 1 second",
                        category: .ipc,
                        metadata: ["retries": "\(maxRetries)"]
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.send(message, maxRetries: maxRetries - 1, completion: completion)
                    }
                    return
                }

                do {
                    let response = try R.Response.decode(data: data)
                    log.debug(
                        "NETunnelProviderSessionWrapper received provider message response",
                        category: .ipc,
                        metadata: ["reponse": "\(String(describing: response))"]
                    )
                    completion?(.success(response))
                } catch {
                    completion?(.failure(.decodingError))
                }
            }
        } catch {
            log.error("Received error while attempting to send provider message: \(error)", category: .ipc)
            completion?(.failure(.sendingError(.internalSendFailed(error))))
        }
    }
}

extension NETunnelProviderSession: NETunnelProviderSessionWrapper {}
