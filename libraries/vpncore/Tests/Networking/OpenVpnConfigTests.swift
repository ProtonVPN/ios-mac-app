//
//  OpenVpnConfigTests.swift
//  vpncore - Created on 11.03.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import vpncore
import XCTest

final class OpenVpnConfigTests: XCTestCase {
    func testOpenVpnConfigDefaults() {
        let config = OpenVpnConfig.defaultConfig
        XCTAssertEqual(config.defaultTcpPorts, [443, 5995, 8443])
        XCTAssertEqual(config.defaultUdpPorts, [80, 443, 4569, 1194, 5060])
    }

    func testOpenVpnConfigExplicitInit() {
        let config = OpenVpnConfig(defaultTcpPorts: [1, 2, 3], defaultUdpPorts: [4, 5, 6])
        XCTAssertEqual(config.defaultTcpPorts, [1, 2, 3])
        XCTAssertEqual(config.defaultUdpPorts, [4, 5, 6])

        let configEmptyTcp = OpenVpnConfig(defaultTcpPorts: [], defaultUdpPorts: [4, 5, 6])
        XCTAssertEqual(configEmptyTcp.defaultTcpPorts, [])
        XCTAssertEqual(configEmptyTcp.defaultUdpPorts, [4, 5, 6])

        let configEmptyUdp = OpenVpnConfig(defaultTcpPorts: [1, 2, 3], defaultUdpPorts: [])
        XCTAssertEqual(configEmptyUdp.defaultTcpPorts, [1, 2, 3])
        XCTAssertEqual(configEmptyUdp.defaultUdpPorts, [])
    }

    func testJSONDeserialization() {
        let json = """
            {"DefaultPorts":{"UDP":[1, 2, 3, 4],"TCP":[5, 6, 7]}}
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
        let config = try! decoder.decode(OpenVpnConfig.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(config.defaultUdpPorts, [1, 2, 3, 4])
        XCTAssertEqual(config.defaultTcpPorts, [5, 6, 7])
    }

    func testEmptyJSONDeserialization() {
        let json = """
            {"DefaultPorts":{}}
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
        let config = try! decoder.decode(OpenVpnConfig.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(config.defaultTcpPorts, OpenVpnConfig.defaultConfig.defaultTcpPorts)
        XCTAssertEqual(config.defaultUdpPorts, OpenVpnConfig.defaultConfig.defaultUdpPorts)
    }

    func testMissingJSONDeserialization() {
        let json1 = """
            {"DefaultPorts":{"UDP":[1, 2, 3, 4]}}
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
        let config1 = try! decoder.decode(OpenVpnConfig.self, from: json1.data(using: .utf8)!)
        XCTAssertEqual(config1.defaultTcpPorts, OpenVpnConfig.defaultConfig.defaultTcpPorts)
        XCTAssertEqual(config1.defaultUdpPorts, [1, 2, 3, 4])

        let json2 = """
            {"DefaultPorts":{"TCP":[4, 5, 6]}}
        """

        let config2 = try! decoder.decode(OpenVpnConfig.self, from: json2.data(using: .utf8)!)
        XCTAssertEqual(config2.defaultTcpPorts, [4, 5, 6])
        XCTAssertEqual(config2.defaultUdpPorts, OpenVpnConfig.defaultConfig.defaultUdpPorts)
    }

    private func decapitalizeFirstLetter(_ path: [CodingKey]) -> CodingKey {
        let original: String = path.last!.stringValue
        let uncapitalized = original.prefix(1).lowercased() + original.dropFirst()
        return Key(stringValue: uncapitalized) ?? path.last!
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
}

