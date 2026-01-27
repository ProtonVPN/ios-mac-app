//
//  VpnStateConfiguration.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Dependencies
import DependenciesMacros
import Domain
import Foundation
import NetworkExtension
import VPNShared

public struct VpnStateConfigurationInfo {
    public let state: VpnState
    public let hasConnected: Bool
    public let connection: ConnectionConfiguration?
}

extension VpnStateConfigurationInfo {
    static let missing: Self = .init(state: .disconnected, hasConnected: false, connection: nil)
}

@DependencyClient
public struct VpnStateConfiguration {
    public var determineActiveVpnProtocolSync: @Sendable (_ defaultToIke: Bool, _ completion: @escaping ((VpnProtocol?) -> Void)) -> Void
    public var determineActiveVpnProtocol: @Sendable (_ defaultToIke: Bool) async -> VpnProtocol?
    public var determineActiveVpnStateSync: @Sendable (_ vpnProtocol: VpnProtocol, _ completion: @escaping ((Result<(NEVPNManagerWrapper, VpnState), Error>) -> Void)) -> Void
    public var determineActiveVpnState: @Sendable (_ vpnProtocol: VpnProtocol) async throws -> (NEVPNManagerWrapper, VpnState)
    public var determineNewState: @Sendable (_ vpnManager: NEVPNManagerWrapper) -> VpnState = { _ in .disconnected }
    public var getInfoSync: @Sendable (_ completion: @escaping ((VpnStateConfigurationInfo) -> Void)) -> Void
    public var getInfo: @Sendable () async -> VpnStateConfigurationInfo = { .missing }
}

public enum VpnStateConfigurationKey: DependencyKey {
    public static var liveValue: VpnStateConfiguration = {
        @Sendable
        func getFactory(for vpnProtocol: VpnProtocol) -> VpnProtocolFactory {
            switch vpnProtocol {
            case .ike:
                @Dependency(\.ikeProtocolManager) var ikeProtocolManager
                return ikeProtocolManager
            case .openVpn:
                fatalError("OpenVPN has been deprecated")
            case .wireGuard:
                @Dependency(\.wireguardProtocolManager) var wireguardProtocolManager
                return wireguardProtocolManager
            }
        }

        @Sendable
        func determineNewState(vpnManager: NEVPNManagerWrapper) -> VpnState {
            let status = vpnManager.vpnConnection.status
            let username = vpnManager.protocolConfiguration?.username ?? ""
            let serverAddress = vpnManager.protocolConfiguration?.serverAddress ?? ""

            switch status {
            case .invalid:
                return .invalid
            case .disconnected:
                return .disconnected
            case .connecting:
                return .connecting(ServerDescriptor(username: username, address: serverAddress))
            case .connected:
                return .connected(ServerDescriptor(username: username, address: serverAddress))
            case .reasserting:
                return .reasserting(ServerDescriptor(username: username, address: serverAddress))
            case .disconnecting:
                return .disconnecting(ServerDescriptor(username: username, address: serverAddress))
            @unknown default:
                return .invalid
            }
        }

        @Sendable
        func determineActiveVpnStateSync(vpnProtocol: VpnProtocol, completion: @escaping ((Result<(NEVPNManagerWrapper, VpnState), Error>) -> Void)) {
            getFactory(for: vpnProtocol).vpnProviderManager(for: .status) { vpnManager, error in
                if let error {
                    completion(.failure(VpnStateConfigurationError.managerRetrievalFailed))
                    return
                }
                guard let vpnManager else {
                    completion(.failure(VpnStateConfigurationError.managerUnavailable))
                    return
                }

                let newState = determineNewState(vpnManager: vpnManager)
                completion(.success((vpnManager, newState)))
            }
        }

        @Sendable
        func determineActiveVpnState(vpnProtocol: VpnProtocol) async throws -> (
            NEVPNManagerWrapper,
            VpnState
        ) {
            let vpnManager = try await getFactory(for: vpnProtocol).vpnProviderManager(for: .status)
            return (vpnManager, determineNewState(vpnManager: vpnManager))
        }

        @Sendable
        func determineActiveVpnProtocolSync(defaultToIke: Bool, completion: @escaping (@MainActor (VpnProtocol?) -> Void)) {
            let protocols: [VpnProtocol] = [.ike, .wireGuard(.udp)]
            var activeProtocols: [VpnProtocol] = []

            let dispatchGroup = DispatchGroup()
            for vpnProtocol in protocols {
                dispatchGroup.enter()
                getFactory(for: vpnProtocol).vpnProviderManager(for: .status) { manager, error in
                    defer { dispatchGroup.leave() }
                    guard let manager else {
                        guard let error else { return }

                        log.error("Couldn't determine if protocol \"\(vpnProtocol.localizedDescription)\" is active: \"\(String(describing: error))\"", category: .connection)
                        return
                    }

                    let state = determineNewState(vpnManager: manager)
                    if state.stableConnection || state.volatileConnection {
                        activeProtocols.append(vpnProtocol)
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                // WireGuard takes precedence but if neither are active, then it should remain unchanged
                if activeProtocols.contains(.wireGuard(.udp)) {
                    return MainActor.assumeIsolated {
                        completion(.wireGuard(.udp))
                    }
                }
                if activeProtocols.contains(.ike) {
                    return MainActor.assumeIsolated {
                        completion(.ike)
                    }
                }
                if defaultToIke {
                    log.info("No active protocols detected. Defaulting to `.ike`", category: .connection)
                    return MainActor.assumeIsolated {
                        completion(.ike)
                    }
                }
                return MainActor.assumeIsolated {
                    completion(nil)
                }
            }
        }

        @Sendable
        func determineActiveVpnProtocol(defaultToIke: Bool) async -> VpnProtocol? {
            let protocols: [VpnProtocol] = [.ike, .wireGuard(.udp)]

            var activeProtocols: [VpnProtocol] = []

            for vpnProtocol in protocols {
                do {
                    let manager = try await getFactory(for: vpnProtocol).vpnProviderManager(for: .status)

                    let state = determineNewState(vpnManager: manager)
                    if state.stableConnection || state.volatileConnection {
                        activeProtocols.append(vpnProtocol)
                    }
                } catch {
                    log.error("Couldn't determine if protocol \"\(vpnProtocol.localizedDescription)\" is active: \"\(String(describing: error))\"", category: .connection)
                    continue
                }
            }
            let activeDeprecatedProtocols = Set(VpnProtocol.deprecatedProtocols).intersection(activeProtocols)
            if !activeDeprecatedProtocols.isEmpty {
                log.assertionFailure("activeProtocols contain a deprecated protocols: \(activeDeprecatedProtocols)")
            }
            return await MainActor.run { [activeProtocols] in
                // OpenVPN takes precedence but if neither are active, then it should remain unchanged
                if activeProtocols.contains(.openVpn(.tcp)) {
                    return .openVpn(.tcp)
                }
                if activeProtocols.contains(.wireGuard(.udp)) {
                    return .wireGuard(.udp)
                }
                if activeProtocols.contains(.ike) {
                    return .ike
                }
                if defaultToIke {
                    log.info("No active protocols detected. Defaulting to `.ike`", category: .connection)
                    return .ike
                }
                return nil
            }
        }

        @Sendable
        func getInfoSync(completion: @escaping ((VpnStateConfigurationInfo) -> Void)) {
            @Dependency(\.propertiesManager) var propertiesManager
            determineActiveVpnProtocolSync(defaultToIke: true) { vpnProtocol in
                guard let vpnProtocol else {
                    completion(VpnStateConfigurationInfo(
                        state: .disconnected,
                        hasConnected: propertiesManager.hasConnected,
                        connection: nil
                    ))
                    return
                }

                let connection: ConnectionConfiguration? = switch vpnProtocol {
                case .ike:
                    propertiesManager.lastIkeConnection
                case .openVpn:
                    propertiesManager.lastOpenVpnConnection
                case .wireGuard:
                    propertiesManager.lastWireguardConnection
                }

                determineActiveVpnStateSync(vpnProtocol: vpnProtocol) { result in
                    switch result {
                    case let .failure(error):
                        completion(VpnStateConfigurationInfo(
                            state: VpnState.error(error),
                            hasConnected: propertiesManager.hasConnected,
                            connection: connection
                        ))
                    case let .success((_, state)):
                        completion(VpnStateConfigurationInfo(
                            state: state,
                            hasConnected: propertiesManager.hasConnected,
                            connection: connection
                        ))
                    }
                }
            }
        }

        return VpnStateConfiguration(
            determineActiveVpnProtocolSync: { defaultToIke, completion in
                determineActiveVpnProtocolSync(defaultToIke: defaultToIke, completion: completion)
            },
            determineActiveVpnProtocol: { defaultToIke in
                await determineActiveVpnProtocol(defaultToIke: defaultToIke)
            },
            determineActiveVpnStateSync: { vpnProtocol, completion in
                determineActiveVpnStateSync(vpnProtocol: vpnProtocol, completion: completion)
            },
            determineActiveVpnState: { vpnProtocol in
                try await determineActiveVpnState(vpnProtocol: vpnProtocol)
            },
            determineNewState: { vpnManager in
                determineNewState(vpnManager: vpnManager)
            },
            getInfoSync: { completion in
                getInfoSync(completion: completion)
            },
            getInfo: {
                @Dependency(\.propertiesManager) var propertiesManager
                guard let vpnProtocol = await determineActiveVpnProtocol(defaultToIke: true) else {
                    return VpnStateConfigurationInfo(
                        state: .disconnected,
                        hasConnected: propertiesManager.hasConnected,
                        connection: nil
                    )
                }

                let connection: ConnectionConfiguration? = switch vpnProtocol {
                case .ike:
                    propertiesManager.lastIkeConnection
                case .openVpn:
                    propertiesManager.lastOpenVpnConnection
                case .wireGuard:
                    propertiesManager.lastWireguardConnection
                }
                do {
                    let (_, state) = try await determineActiveVpnState(vpnProtocol: vpnProtocol)
                    return VpnStateConfigurationInfo(
                        state: state,
                        hasConnected: propertiesManager.hasConnected,
                        connection: connection
                    )
                } catch {
                    return VpnStateConfigurationInfo(
                        state: VpnState.error(error),
                        hasConnected: propertiesManager.hasConnected,
                        connection: connection
                    )
                }
            }
        )
    }()
}

public extension DependencyValues {
    var vpnStateConfiguration: VpnStateConfiguration {
        get { self[VpnStateConfigurationKey.self] }
        set { self[VpnStateConfigurationKey.self] = newValue }
    }
}

public enum VpnStateConfigurationError: FourCharCode, ProtonVPNError {
    /// Failed to retrieve VPN manager for the specified protocol
    case managerRetrievalFailed = "VSRF"

    /// VPN manager was nil when it should have been available
    case managerUnavailable = "VSMU"

    public var errorDescription: String? {
        switch self {
        case .managerRetrievalFailed:
            "Failed to retrieve VPN manager"
        case .managerUnavailable:
            "VPN manager is unavailable"
        }
    }
}
