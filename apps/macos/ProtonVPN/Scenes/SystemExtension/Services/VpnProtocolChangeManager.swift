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

import Foundation

import Domain
import LegacyCommon
import VPNShared
import VPNAppCore

protocol VpnProtocolChangeManagerFactory {
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager
}

extension DependencyContainer: VpnProtocolChangeManagerFactory {
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager {
        return VpnProtocolChangeManagerImplementation(factory: self)
    }
}

/// Class to request VPN protocol change.
/// Takes care of checking if user is currently connected, if sysex is installed, etc.
protocol VpnProtocolChangeManager {
    func change(toProtocol: VpnProtocol, completion: @escaping (Result<(), Error>) -> Void)
}

final class VpnProtocolChangeManagerImplementation: VpnProtocolChangeManager {
    
    typealias Factory = PropertiesManagerFactory
        & AppStateManagerFactory
        & CoreAlertServiceFactory
        & VpnGatewayFactory
        & SystemExtensionManagerFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()

    /// What to do after switching protocols
    internal enum ProtocolSwitchAction {
        /// Reconnect to the current server with the new protocol.
        case reconnect
        /// Disconnect from the current server (can be due to unsupported protocol on server)
        case disconnect
        /// Just switch the protocol, don't do anything else.
        case doNothing
    }

    init(factory: Factory) {
        self.factory = factory
    }
    
    func change(toProtocol vpnProtocol: VpnProtocol, completion: @escaping (Result<(), Error>) -> Void) {
        guard vpnGateway.connection == .connected || vpnGateway.connection == .connecting else {
            set(vpnProtocol: vpnProtocol, and: .doNothing, completion: completion)
            return
        }

        guard appStateManager.activeConnection()?.server.supports(vpnProtocol: vpnProtocol) != false else {
            let alert = ProtocolNotAvailableForServerAlert(confirmHandler: { [weak self] in
                self?.set(vpnProtocol: vpnProtocol, and: .disconnect, completion: completion)
            }, cancelHandler: {
                completion(.failure(ReconnectOnSmartProtocolChangeAlert.userCancelled))
            })
            alertService.push(alert: alert)
            return
        }

        alertService.push(alert: ReconnectOnSettingsChangeAlert(confirmHandler: { [weak self] in
            self?.set(vpnProtocol: vpnProtocol, and: .reconnect, completion: completion)
        }, cancelHandler: {
            completion(.failure(ReconnectOnSettingsChangeAlert.userCancelled))
        }))
    }
    
    private func set(vpnProtocol: VpnProtocol,
                     and then: ProtocolSwitchAction,
                     completion: @escaping (Result<(), Error>) -> Void) {
        let performSwitchAction = { [weak self] in
            switch then {
            case .reconnect:
                log.info("New protocol set to \(vpnProtocol). VPN will reconnect.",
                         category: .connectionConnect, event: .trigger)
                self?.vpnGateway.reconnect(with: ConnectionProtocol.vpnProtocol(vpnProtocol))
            case .disconnect:
                self?.vpnGateway.disconnect()
            case .doNothing:
                return
            }
        }

        guard vpnProtocol.requiresSystemExtension else {
            propertiesManager.vpnProtocol = vpnProtocol
            performSwitchAction()
            completion(.success)
            return
        }

        sysexManager.installOrUpdateExtensionsIfNeeded(shouldStartTour: true) { result in
            switch result {
            case .success:
                self.propertiesManager.vpnProtocol = vpnProtocol
                performSwitchAction()
                completion(.success)
            case .failure(let error):
                log.error("Protocol (\(vpnProtocol)) was not set because sysex check/installation failed: \(error)", category: .connectionConnect)
                completion(.failure(error))
            }
        }
    }
}
