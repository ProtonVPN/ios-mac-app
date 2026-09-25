//
//  VpnProtocolChangeManager.swift
//  ProtonVPN - Created on 2021-04-09.
//
//  Copyright (c) 2019 Proton Technologies AG
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

import Connection
import Dependencies
import Domain
import Foundation
import Sharing
import VPNAppCore

protocol VpnProtocolChangeManagerFactory {
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager
}

extension DependencyContainer: VpnProtocolChangeManagerFactory {
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager {
        VpnProtocolChangeManagerImplementation()
    }
}

/// Class to request VPN protocol change.
/// Takes care of checking if user is currently connected, if sysex is installed, etc.
protocol VpnProtocolChangeManager {
    func change(toProtocol: VpnProtocol, userInitiated: Bool, completion: @escaping (Result<Void, Error>) -> Void)
}

final class VpnProtocolChangeManagerImplementation: VpnProtocolChangeManager {
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.coreAlertService) private var alertService
    @Dependency(\.systemExtensionsCoordinator) private var systemExtensionsCoordinator
    @SharedReader(.connectionState) private var connectionState: ConnectionState

    /// What to do after switching protocols
    enum ProtocolSwitchAction {
        /// Reconnect to the current server with the new protocol.
        case reconnect
        /// Disconnect from the current server (can be due to unsupported protocol on server)
        case disconnect
        /// Just switch the protocol, don't do anything else.
        case doNothing
    }

    func change(
        toProtocol vpnProtocol: VpnProtocol,
        userInitiated: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard connectionState.isConnectedOrConnecting else {
            set(
                vpnProtocol: vpnProtocol,
                userInitiated: userInitiated,
                and: .doNothing,
                completion: completion
            )
            return
        }

        // If the currently active tunnel already uses this protocol, avoid a redundant reconnect.
        if connectionState.resolvedVpnProtocol == vpnProtocol {
            set(
                vpnProtocol: vpnProtocol,
                userInitiated: userInitiated,
                and: .doNothing,
                completion: completion
            )
            return
        }

        guard connectionState.resolvedServer?.endpoint.supports(vpnProtocol: vpnProtocol) != false else {
            let alert = ProtocolNotAvailableForServerAlert(confirmHandler: { [weak self] in
                self?.set(
                    vpnProtocol: vpnProtocol,
                    userInitiated: true,
                    and: .disconnect,
                    completion: completion
                )
            }, cancelHandler: {
                completion(.failure(ReconnectOnSmartProtocolChangeAlert.userCancelled))
            })
            Task { @MainActor in
                self.alertService.push(alert: alert)
            }
            return
        }

        let reconnectAlert = ReconnectOnSettingsChangeAlert(confirmHandler: { [weak self] in
            self?.set(
                vpnProtocol: vpnProtocol,
                userInitiated: userInitiated,
                and: .reconnect,
                completion: completion
            )
        }, cancelHandler: {
            completion(.failure(ReconnectOnSettingsChangeAlert.userCancelled))
        })

        Task { @MainActor in
            self.alertService.push(alert: reconnectAlert)
        }
    }

    private func set(
        vpnProtocol: VpnProtocol,
        userInitiated _: Bool,
        and then: ProtocolSwitchAction,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        @Shared(.vpnProtocol) var sharedVpnProtocol
        let performSwitchAction = { [weak self] in
            switch then {
            case .reconnect:
                log.info(
                    "New protocol set to \(vpnProtocol). VPN will reconnect.",
                    category: .connectionConnect,
                    event: .trigger
                )
                self?.connectionCommandClient.send(.reconnect(.vpnProtocol(vpnProtocol)))
            case .disconnect:
                self?.connectionCommandClient.send(.disconnect(.auto))
            case .doNothing:
                return
            }
        }

        guard vpnProtocol.requiresSystemExtension else {
            $sharedVpnProtocol.withLock { $0 = vpnProtocol }
            performSwitchAction()
            completion(.success)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let outcome = await systemExtensionsCoordinator.installOrUpdate(
                origin: .protocolSwitch,
                shouldStartTour: true,
                includedTypes: [.proTUN]
            )
            let result = outcome.accumulated
            switch result {
            case .success:
                $sharedVpnProtocol.withLock { $0 = vpnProtocol }
                performSwitchAction()
                completion(.success)
            case let .failure(error):
                log.error(
                    "Protocol (\(vpnProtocol)) was not set because sysex check/installation failed: \(error)",
                    category: .connectionConnect
                )

                if case let .installationError(installError) = error,
                   let alert = SysexInstallingErrorAlert(error: installError) {
                    alertService.push(alert: alert)
                }
                completion(.failure(error))
            }
        }
    }
}
