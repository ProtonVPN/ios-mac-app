//
//  VpnConnectionPreparer.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import Domain
import VPNShared
import VPNAppCore

class VpnConnectionPreparer {
    private let appStateManager: AppStateManager
    private let serverTierChecker: ServerTierChecker
    private let smartProtocolConfig: SmartProtocolConfig
    private let wireguardConfig: WireguardConfig
    private let availabilityCheckerResolver: AvailabilityCheckerResolver

    private var smartProtocol: SmartProtocol?
    private var smartPortSelector: SmartPortSelector?
    
    init(
        appStateManager: AppStateManager,
        serverTierChecker: ServerTierChecker,
        availabilityCheckerResolver: AvailabilityCheckerResolver,
        smartProtocolConfig: SmartProtocolConfig,
        wireguardConfig: WireguardConfig
    ) {
        self.appStateManager = appStateManager
        self.serverTierChecker = serverTierChecker
        self.availabilityCheckerResolver = availabilityCheckerResolver
        self.smartProtocolConfig = smartProtocolConfig
        self.wireguardConfig = wireguardConfig
    }
    
    func determineServerParametersAndConnect(
        requestId: UUID,
        with connectionProtocol: ConnectionProtocol,
        to server: ServerModel,
        netShieldType: NetShieldType,
        natType: NATType,
        safeMode: Bool?,
        intent: ConnectionRequestType?
    ) {
        guard let serverIp = selectServerIp(server: server, connectionProtocol: connectionProtocol) else {
            return
        }
        
        selectVpnProtocol(for: connectionProtocol, toIP: serverIp) { (vpnProtocol, ports) in
            let entryIp = serverIp.entryIp(using: vpnProtocol) ?? serverIp.entryIp
            log.info(
                "Connecting with \(vpnProtocol) to \(server.name) via \(String(describing: entryIp)):\(ports)",
                 category: .connectionConnect
            )
            self.formConfigurationWithParametersAndConnect(
                requestId: requestId,
                withProtocol: vpnProtocol,
                server: server,
                serverIp: serverIp,
                netShieldType: netShieldType,
                natType: natType,
                safeMode: safeMode,
                ports: ports,
                intent: intent
            )
        }
    }
    
    // MARK: - Private functions

    // swiftlint:disable:next function_parameter_count
    private func formConfigurationWithParametersAndConnect(
        requestId: UUID,
        withProtocol vpnProtocol: VpnProtocol,
        server: ServerModel,
        serverIp: ServerIp,
        netShieldType: NetShieldType,
        natType: NATType,
        safeMode: Bool?,
        ports: [Int],
        intent: ConnectionRequestType?
    ) {
        guard let configuration = formConfiguration(
            requestId: requestId,
            withProtocol: vpnProtocol,
            fromServer: server,
            serverIp: serverIp,
            netShieldType: netShieldType,
            natType: natType,
            safeMode: safeMode,
            ports: ports,
            intent: intent
        ) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.appStateManager.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: configuration)
        }
    }

    private func selectServerIp(server: ServerModel, connectionProtocol: ConnectionProtocol) -> ServerIp? {
        let availableServerIps = server.ips.filter {
            return $0.supports(connectionProtocol: connectionProtocol,
                               smartProtocolConfig: smartProtocolConfig)
                && !$0.underMaintenance
        }

        guard let serverIp = availableServerIps.randomElement() else {
            log.error("\(connectionProtocol) with config \(smartProtocolConfig) is not supported by \(server)", category: .connectionConnect)
            serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: false, type: server.serverType, reason: .protocolNotSupported)
            return nil
        }

        log.info("Selected \(serverIp) as server ip for \(server.domain)", category: .connectionConnect)
        return serverIp
    }
    
    private func selectVpnProtocol(for connectionProtocol: ConnectionProtocol, toIP serverIp: ServerIp, completion: @escaping (VpnProtocol, [Int]) -> Void) {
        switch connectionProtocol {
        case .smartProtocol:
            smartProtocol = SmartProtocolImplementation(
                availabilityCheckerResolver: availabilityCheckerResolver,
                smartProtocolConfig: smartProtocolConfig,
                wireguardConfig: wireguardConfig
            )
            smartProtocol?.determineBestProtocol(server: serverIp) { (vpnProtocol, ports) in
                completion(vpnProtocol, ports)
            }
            
        case let .vpnProtocol(vpnProtocol):
            smartPortSelector = SmartPortSelectorImplementation(
                wireguardUdpChecker: availabilityCheckerResolver.availabilityChecker(for: .wireGuard(.udp)),
                wireguardTcpChecker: availabilityCheckerResolver.availabilityChecker(for: .wireGuard(.tcp))
            )
            smartPortSelector?.determineBestPort(for: vpnProtocol, on: serverIp) { ports in
                completion(vpnProtocol, ports)
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func formConfiguration(
        requestId: UUID,
        withProtocol vpnProtocol: VpnProtocol,
        fromServer server: ServerModel,
        serverIp: ServerIp,
        netShieldType: NetShieldType,
        natType: NATType,
        safeMode: Bool?,
        ports: [Int],
        intent: ConnectionRequestType?
    ) -> ConnectionConfiguration? {
        if let requiresUpgrade = serverTierChecker.serverRequiresUpgrade(server), requiresUpgrade {
            return nil
        }
        
        return ConnectionConfiguration(
            id: requestId,
            server: server,
            serverIp: serverIp,
            vpnProtocol: vpnProtocol,
            netShieldType: netShieldType,
            natType: natType,
            safeMode: safeMode,
            ports: ports,
            intent: intent
        )
    }
}
