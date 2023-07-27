//
//  ServerManagerTests.swift
//  ProtonVPN - Created on 27.06.19.
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

@testable import LegacyCommon
import XCTest
import VPNShared

class ServerManagerTests: XCTestCase {
    let serverStorage = ServerStorageMock(fileName: "ServerManagerTestServers", bundle: Bundle.module)
    
    private func assertCountry(_ group: ServerGroup, _ country: String) {
        switch group.kind {
        case .country(let countryModel):
            XCTAssertEqual(countryModel.countryCode, country)
        case .gateway:
            XCTFail("Gateway group instead of a country")
        }
    }

    private func assertGateway(_ group: ServerGroup, _ name: String) {
        switch group.kind {
        case .country:
            XCTFail("Gateway group instead of a country")
        case .gateway(let gatewayName):
            XCTAssertEqual(gatewayName, name)
        }
    }

    func testStandardGrouping() { 
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .standard)

        XCTAssert(grouping.count == 4)
        assertGateway(grouping[0], "Mega Gateway 2000")
        XCTAssert(grouping[0].servers.count == 1)
        XCTAssert(grouping[0].servers[0].entryCountryCode == "CA")
        XCTAssert(grouping[0].servers[0].exitCountryCode == "CA")

        assertCountry(grouping[1], "CA")
        assertCountry(grouping[2], "HK")
        assertCountry(grouping[3], "JP")
    }
    
    func testSecureCoreFreeGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 0, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .secureCore)
        
        XCTAssert(grouping.isEmpty)
    }
    
    func testSecureCorePlusGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .secureCore)

        XCTAssert(grouping.count == 1)
        assertCountry(grouping[0], "CA")
        XCTAssert(grouping[0].servers.count == 1)
        XCTAssert(grouping[0].servers[0].entryCountryCode == "CH")
        XCTAssert(grouping[0].servers[0].exitCountryCode == "CA")
    }
    
    func testP2pFreeGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 0, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .p2p)
        
        XCTAssert(grouping.isEmpty)
    }
    
    func testP2pPlusGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .p2p)

        XCTAssert(grouping.count == 1)
        assertCountry(grouping[0], "JP")
        XCTAssert(grouping[0].servers.count == 1)
        XCTAssert(grouping[0].servers[0].name == "JP#7")
    }
    
    func testTorFreeGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 0, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .tor)
        
        XCTAssert(grouping.isEmpty)
    }
    
    func testTorPlusGrouping() {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)
        let grouping = serverManager.grouping(for: .tor)

        XCTAssert(grouping.count == 1)
        assertCountry(grouping[0], "JP")
        XCTAssert(grouping[0].servers.count == 1)
        XCTAssert(grouping[0].servers[0].name == "JP#8")

        var unsupportedProtocols = VpnProtocol.allCases
        unsupportedProtocols.removeAll(where: { $0 == .wireGuard(.udp) })

        let serverModel = grouping[0].servers[0]
        XCTAssert(serverModel.supports(vpnProtocol: .wireGuard(.udp)))

        for vpnProtocol in unsupportedProtocols {
            XCTAssert(!serverModel.supports(vpnProtocol: vpnProtocol))
        }
    }

    func testLogicalThatOnlySupportsOneProtocol() throws {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)

        let grouping = serverManager.grouping(for: .tor)

        var unsupportedProtocols = VpnProtocol.allCases
        unsupportedProtocols.removeAll(where: { $0 == .wireGuard(.udp) })

        let serverModel = try XCTUnwrap(findServerModel(groupings: grouping,
                                                        withServerIpNamed: "JP#8"))

        XCTAssert(serverModel.supports(vpnProtocol: .wireGuard(.udp)))

        for vpnProtocol in unsupportedProtocols {
            XCTAssert(!serverModel.supports(vpnProtocol: vpnProtocol))
        }
    }

    func testLogicalThatSupportsAllProtocolsButHasServerIpEntrySupportingSubset() throws {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)

        let grouping = serverManager.grouping(for: .secureCore)

        let serverModel = try XCTUnwrap(findServerModel(groupings: grouping,
                                                        withServerIpNamed: "CH-CA#5"))

        for vpnProtocol in VpnProtocol.allCases {
            XCTAssert(serverModel.supports(vpnProtocol: vpnProtocol))
        }
    }

    func testLogicalThatSupportsSubsetOfProtocols() throws {
        let serverManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: serverStorage)

        let grouping = serverManager.grouping(for: .p2p)

        var unsupportedProtocols = VpnProtocol.allCases
        unsupportedProtocols.removeAll(where: { $0 == .wireGuard(.tcp) || $0 == .openVpn(.udp) })

        let serverModel = try XCTUnwrap(findServerModel(groupings: grouping,
                                                        withServerIpNamed: "JP#7"))

        XCTAssert(serverModel.supports(vpnProtocol: .wireGuard(.tcp)))
        XCTAssertEqual(serverModel.ips.first!.entryIp(using: .wireGuard(.tcp)),
                       "1.2.3.13")
        XCTAssert(serverModel.supports(vpnProtocol: .openVpn(.udp)))
        XCTAssertEqual(serverModel.ips.first!.entryIp(using: .openVpn(.udp)),
                       "1.2.3.12")

        for vpnProtocol in unsupportedProtocols {
            XCTAssert(!serverModel.supports(vpnProtocol: vpnProtocol))
        }
    }

    func findServerModel(groupings: [ServerGroup], withServerIpNamed name: String) -> ServerModel? {
        for grouping in groupings {
            for serverModel in grouping.servers {
                if serverModel.name == name {
                    return serverModel
                }
            }
        }

        XCTFail("Couldn't find server with name \(name)")
        return nil
    }
}
