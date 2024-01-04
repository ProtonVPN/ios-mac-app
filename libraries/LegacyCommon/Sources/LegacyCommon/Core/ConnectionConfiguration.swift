//
//  ConnectionConfiguration.swift
//  ProtonVPN - Created on 26.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

import Domain
import VPNShared

/// Used to contain the details of a connection from the perspective of our service.
/// This can be matched with the limited details contained by the VPN services.
public struct ConnectionConfiguration: Codable, Identifiable {
    public let id: UUID
    public let server: ServerModel
    public let serverIp: ServerIp
    public let vpnProtocol: VpnProtocol
    public let netShieldType: NetShieldType
    public let natType: NATType
    public let safeMode: Bool?
    public let ports: [Int]
    public let intent: ConnectionRequestType?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.server = try container.decode(ServerModel.self, forKey: CodingKeys.server)
        self.serverIp = try container.decode(ServerIp.self, forKey: CodingKeys.serverIp)
        self.vpnProtocol = try container.decode(VpnProtocol.self, forKey: CodingKeys.vpnProtocol)
        self.netShieldType = try container.decode(NetShieldType.self, forKey: CodingKeys.netShieldType)
        self.ports = try container.decode([Int].self, forKey: CodingKeys.ports)
        self.safeMode = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.safeMode)
        // This can be missing from JSON if config was saved with older app version. Set it to default in that case.
        self.id = (try container.decodeIfPresent(UUID.self, forKey: CodingKeys.id)) ?? UUID()
        self.natType = try container.decodeIfPresent(NATType.self, forKey: .natType) ?? NATType.default
        self.intent = try container.decodeIfPresent(ConnectionRequestType.self, forKey: CodingKeys.intent)
    }

    public init(
        id: UUID,
        server: ServerModel,
        serverIp: ServerIp,
        vpnProtocol: VpnProtocol,
        netShieldType: NetShieldType,
        natType: NATType,
        safeMode: Bool?,
        ports: [Int],
        intent: ConnectionRequestType?
    ) {
        self.id = id
        self.server = server
        self.serverIp = serverIp
        self.vpnProtocol = vpnProtocol
        self.netShieldType = netShieldType
        self.ports = ports
        self.natType = natType
        self.safeMode = safeMode
        self.intent = intent
    }

    public func withChanged(netShieldType: NetShieldType) -> ConnectionConfiguration {
        ConnectionConfiguration(
            id: id,
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

    public func withChanged(natType: NATType) -> ConnectionConfiguration {
        ConnectionConfiguration(
            id: id,
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

    public func withChanged(safeMode: Bool) -> ConnectionConfiguration {
        ConnectionConfiguration(
            id: id,
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

    public func withChanged(exitIp: String) -> ConnectionConfiguration {
        ConnectionConfiguration(
            id: id,
            server: server,
            serverIp: ServerIp(
                id: serverIp.id,
                entryIp: serverIp.entryIp,
                exitIp: exitIp,
                domain: serverIp.domain,
                status: serverIp.status
            ),
            vpnProtocol: vpnProtocol,
            netShieldType: netShieldType,
            natType: natType,
            safeMode: safeMode,
            ports: ports,
            intent: intent
        )
    }

    public func withChanged(server: ServerModel, ip: ServerIp) -> ConnectionConfiguration {
        ConnectionConfiguration(
            id: id,
            server: server,
            serverIp: ip,
            vpnProtocol: vpnProtocol,
            netShieldType: netShieldType,
            natType: natType,
            safeMode: safeMode,
            ports: ports,
            intent: intent
        )
    }
}
