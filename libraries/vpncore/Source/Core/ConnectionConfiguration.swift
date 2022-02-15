//
//  ConnectionConfiguration.swift
//  ProtonVPN - Created on 26.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

/// Used to contain the details of a connection from the perspective of our service.
/// This can be matched with the limited details contained by the VPN services.
public struct ConnectionConfiguration: Codable {
    
    public let server: ServerModel
    public let serverIp: ServerIp
    public let vpnProtocol: VpnProtocol
    public let netShieldType: NetShieldType
    public let natType: NATType
    public let safeMode: Bool
    public let ports: [Int]
    
    public init(server: ServerModel, serverIp: ServerIp, vpnProtocol: VpnProtocol, netShieldType: NetShieldType, natType: NATType, safeMode: Bool, ports: [Int]) {
        self.server = server
        self.serverIp = serverIp
        self.vpnProtocol = vpnProtocol
        self.netShieldType = netShieldType
        self.ports = ports
        self.natType = natType
        self.safeMode = safeMode
    }

    public func withChanged(netShieldType: NetShieldType) -> ConnectionConfiguration {
        return ConnectionConfiguration(server: server, serverIp: serverIp, vpnProtocol: vpnProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, ports: ports)
    }

    public func withChanged(natType: NATType) -> ConnectionConfiguration {
        return ConnectionConfiguration(server: server, serverIp: serverIp, vpnProtocol: vpnProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, ports: ports)
    }

    public func withChanged(safeMode: Bool) -> ConnectionConfiguration {
        return ConnectionConfiguration(server: server, serverIp: serverIp, vpnProtocol: vpnProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, ports: ports)
    }
}
