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
    
    let defaultTcpPorts: [Int]
    let defaultUdpPorts: [Int]
    
    public static let defaultConfig = OpenVpnConfig(defaultTcpPorts: [443, 5995, 8443], defaultUdpPorts: [80, 443, 4569, 1194, 5060])
    
    public init(defaultTcpPorts: [Int], defaultUdpPorts: [Int]) {
        self.defaultTcpPorts = defaultTcpPorts
        self.defaultUdpPorts = defaultUdpPorts
    }
    
    public init(dic: JSONDictionary) throws {
        guard let defaultPorts = dic.jsonDictionary(key: "DefaultPorts") else {
            PMLog.D("'DefaultPorts' field not present in clientconfig response", level: .error)
            throw ParseError.clientConfigParse
        }
        defaultTcpPorts = try defaultPorts.intArrayOrThrow(key: "TCP")
        defaultUdpPorts = try defaultPorts.intArrayOrThrow(key: "UDP")
    }
}
