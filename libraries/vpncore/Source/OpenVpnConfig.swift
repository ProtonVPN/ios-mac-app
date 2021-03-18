//
//  OpenVpnConfig.swift
//  ProtonVPN - Created on 02.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

public struct OpenVpnConfig: Codable {
    enum PortType {
        static let UDP = "UDP"
        static let TCP = "TCP"
    }
    
    let defaultPorts: [String: [Int]]
    
    var defaultTcpPorts: [Int] {
        return defaultPorts[PortType.TCP] ?? OpenVpnConfig.defaultConfig.defaultTcpPorts
    }
    var defaultUdpPorts: [Int] {
        return defaultPorts[PortType.UDP] ?? OpenVpnConfig.defaultConfig.defaultUdpPorts
    }
    
    public static let defaultConfig = OpenVpnConfig(defaultTcpPorts: [443, 5995, 8443], defaultUdpPorts: [80, 443, 4569, 1194, 5060])
    
    public init(defaultTcpPorts: [Int], defaultUdpPorts: [Int]) {
        defaultPorts = [
            PortType.TCP: defaultTcpPorts,
            PortType.UDP: defaultUdpPorts
        ]
    }
}
