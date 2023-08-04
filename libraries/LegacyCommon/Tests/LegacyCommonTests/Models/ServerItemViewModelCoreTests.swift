//
//  Created on 25/11/2022.
//
//  Copyright (c) 2022 Proton AG
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

import XCTest
@testable import LegacyCommon
@testable import LegacyCommonTestSupport

final class ServerItemViewModelCoreTests: XCTestCase {

    func testBasicServer() throws {
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server1,
                                          vpnGateway: VpnGatewayMock(),
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertTrue(sut.isSmartAvailable)
        XCTAssertFalse(sut.isTorAvailable)
        XCTAssertFalse(sut.isP2PAvailable)
        XCTAssertFalse(sut.isPartnerServer)
        XCTAssertFalse(sut.isSecureCoreEnabled)
        XCTAssertEqual(sut.load, 15)
        XCTAssertFalse(sut.underMaintenance)
        XCTAssertFalse(sut.isUsersTierTooLow)
        XCTAssertEqual(sut.alphaOfMainElements, 1.0)
        XCTAssertEqual(sut.partners, [])
        XCTAssertEqual(sut.userTier, CoreAppConstants.VpnTiers.free)
    }

    func testServerFeatures() throws {
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server7(),
                                          vpnGateway: VpnGatewayMock(),
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertTrue(sut.isSmartAvailable)
        XCTAssertTrue(sut.isTorAvailable)
        XCTAssertTrue(sut.isP2PAvailable)
        XCTAssertTrue(sut.isPartnerServer)
        XCTAssertTrue(sut.isSecureCoreEnabled)
    }

    func testServerAlpha0_5() throws {
        let gatewayMock = VpnGatewayMock()
        gatewayMock._userTier = CoreAppConstants.VpnTiers.free
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server7(),
                                          vpnGateway: gatewayMock,
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertEqual(sut.alphaOfMainElements, 0.5)
        XCTAssertEqual(sut.userTier, CoreAppConstants.VpnTiers.free)
    }

    func testServerAlpha0_25() throws {
        let gatewayMock = VpnGatewayMock()
        gatewayMock._userTier = CoreAppConstants.VpnTiers.free
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server2UnderMaintenance,
                                          vpnGateway: gatewayMock,
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertEqual(sut.alphaOfMainElements, 0.25)
    }

    func testUserTierPlus() throws {
        let gatewayMock = VpnGatewayMock()
        gatewayMock._userTier = CoreAppConstants.VpnTiers.plus
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server1,
                                          vpnGateway: gatewayMock,
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertEqual(sut.userTier, CoreAppConstants.VpnTiers.plus)
    }

    func testEmptyPartners() throws {
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server1,
                                          vpnGateway: VpnGatewayMock(),
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertTrue(sut.partners.isEmpty)
    }

    func testPartnersWithOneMatch() throws {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.partnerTypes = [.onePartner(logicalIDs: ["someId"])]
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server7(id: "someId"),
                                          vpnGateway: VpnGatewayMock(),
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: propertiesManager)
        XCTAssertEqual(sut.partners.count, 1)
    }

    func testPartnersWithNoMatch() throws {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.partnerTypes = [.onePartner(logicalIDs: ["someId"])]
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server7(id: "someOtherId"),
                                          vpnGateway: VpnGatewayMock(),
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: propertiesManager)
        XCTAssertTrue(sut.partners.isEmpty)
    }
}
