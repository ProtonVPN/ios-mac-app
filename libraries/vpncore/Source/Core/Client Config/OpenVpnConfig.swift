//
//  OpenVpnConfig.swift
//  ProtonVPN - Created on 02.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

public struct OpenVpnConfig: Codable, Equatable {
    let defaultTcpPorts: [Int]
    let defaultUdpPorts: [Int]

    var staticKey: String {
        return ("6acef03f62675b4b1bbd03e53b187727423cea742242106cb2916a8a4c829756" +
                "3d22c7e5cef430b1103c6f66eb1fc5b375a672f158e2e2e936c3faa48b035a6d" +
                "e17beaac23b5f03b10b868d53d03521d8ba115059da777a60cbfd7b2c9c57472" +
                "78a15b8f6e68a3ef7fd583ec9f398c8bd4735dab40cbd1e3c62a822e97489186" +
                "c30a0b48c7c38ea32ceb056d3fa5a710e10ccc7a0ddb363b08c3d2777a3395e1" +
                "0c0b6080f56309192ab5aacd4b45f55da61fc77af39bd81a19218a79762c3386" +
                "2df55785075f37d8c71dc8a42097ee43344739a0dd48d03025b0450cf1fb5e8c" +
                "aeb893d9a96d1f15519bb3c4dcb40ee316672ea16c012664f8a9f11255518deb")
    }
    
    public static let defaultConfig = OpenVpnConfig(defaultTcpPorts: [443, 5995, 8443], defaultUdpPorts: [80, 443, 4569, 1194, 5060])
    
    public init(defaultTcpPorts: [Int]? = nil, defaultUdpPorts: [Int]? = nil) {
        self.defaultTcpPorts = defaultTcpPorts ?? [443, 5995, 8443]
        self.defaultUdpPorts = defaultUdpPorts ?? [80, 443, 4569, 1194, 5060]
    }
}
