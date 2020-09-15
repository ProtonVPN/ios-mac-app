//
//  ConnectionConfiguration.swift
//  ProtonVPN - Created on 26.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

// Used to contain the details of a connection from the perspective of our service.
// This can be matched with the limited details contained by the VPN services.

public struct ConnectionConfiguration: Codable {
    
    public let server: ServerModel
    public let serverIp: ServerIp
    public let vpnProtocol: VpnProtocol
    public let netShieldType: NetShieldType
    
    public init(server: ServerModel, serverIp: ServerIp, vpnProtocol: VpnProtocol, netShieldType: NetShieldType) {
        self.server = server
        self.serverIp = serverIp
        self.vpnProtocol = vpnProtocol
        self.netShieldType = netShieldType
    }
}
