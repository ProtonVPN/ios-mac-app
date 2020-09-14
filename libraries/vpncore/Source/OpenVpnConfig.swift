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
    
    let defaultPorts: [String: [Int]]
    
    var defaultTcpPorts: [Int] {
        return defaultPorts["UDP"] ?? OpenVpnConfig.defaultConfig.defaultTcpPorts
    }
    var defaultUdpPorts: [Int] {
        return defaultPorts["TCP"] ?? OpenVpnConfig.defaultConfig.defaultTcpPorts
    }
    
    public static let defaultConfig = OpenVpnConfig(defaultTcpPorts: [443, 5995, 8443], defaultUdpPorts: [80, 443, 4569, 1194, 5060])
    
    public init(defaultTcpPorts: [Int], defaultUdpPorts: [Int]) {
        defaultPorts = [
            "UDP": defaultTcpPorts,
            "TCP": defaultUdpPorts
        ]
    }
}
