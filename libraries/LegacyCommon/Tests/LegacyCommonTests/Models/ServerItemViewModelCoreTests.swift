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

final class ServerItemViewModelCoreTests: XCTestCase {

    func testBasicServer() throws {
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server1.serverInfo,
                                          vpnGateway: VpnGatewayMock(),
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertTrue(sut.isSmartAvailable)
        XCTAssertFalse(sut.isTorAvailable)
        XCTAssertFalse(sut.isP2PAvailable)
        XCTAssertFalse(sut.isSecureCoreEnabled)
        XCTAssertEqual(sut.load, 15)
        XCTAssertFalse(sut.underMaintenance)
        XCTAssertFalse(sut.isUsersTierTooLow)
        XCTAssertEqual(sut.alphaOfMainElements, 1.0)
        XCTAssertEqual(sut.userTier, .freeTier)
    }

    func testServerFeatures() throws {
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server7().serverInfo,
                                          vpnGateway: VpnGatewayMock(),
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertTrue(sut.isSmartAvailable)
        XCTAssertTrue(sut.isTorAvailable)
        XCTAssertTrue(sut.isP2PAvailable)
        XCTAssertTrue(sut.isSecureCoreEnabled)
    }

    func testServerAlpha0_5() throws {
        let gatewayMock = VpnGatewayMock()
        gatewayMock._userTier = .freeTier
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server7().serverInfo,
                                          vpnGateway: gatewayMock,
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertEqual(sut.alphaOfMainElements, 0.5)
        XCTAssertEqual(sut.userTier, .freeTier)
    }

    func testServerAlpha0_25() throws {
        let gatewayMock = VpnGatewayMock()
        gatewayMock._userTier = .freeTier
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server2UnderMaintenance.serverInfo,
                                          vpnGateway: gatewayMock,
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertEqual(sut.alphaOfMainElements, 0.25)
    }

    func testUserTierPlus() throws {
        let gatewayMock = VpnGatewayMock()
        gatewayMock._userTier = .paidTier
        let sut = ServerItemViewModelCore(serverModel: MockTestData().server1.serverInfo,
                                          vpnGateway: gatewayMock,
                                          appStateManager: AppStateManagerMock(),
                                          propertiesManager: PropertiesManagerMock())
        XCTAssertEqual(sut.userTier, .paidTier)
    }
}
