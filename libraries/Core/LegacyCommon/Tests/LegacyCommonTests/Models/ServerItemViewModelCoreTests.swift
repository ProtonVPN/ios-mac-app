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

import CommonNetworking
import Dependencies
import Domain
@testable import LegacyCommon
import VPNShared
import XCTest

final class ServerItemViewModelCoreTests: XCTestCase {
    func testBasicServer() {
        let sut = ServerItemViewModelCore(serverModel: ServerModel.testServer1.serverInfo)
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

    func testServerFeatures() {
        let sut = ServerItemViewModelCore(serverModel: ServerModel.testServer7().serverInfo)
        XCTAssertTrue(sut.isSmartAvailable)
        XCTAssertTrue(sut.isTorAvailable)
        XCTAssertTrue(sut.isP2PAvailable)
        XCTAssertTrue(sut.isSecureCoreEnabled)
    }

    func testServerAlpha0_5() {
        withDependencies {
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .freeTier)
        } operation: {
            let sut = ServerItemViewModelCore(serverModel: ServerModel.testServer7().serverInfo)
            XCTAssertEqual(sut.alphaOfMainElements, 0.5)
            XCTAssertEqual(sut.userTier, .freeTier)
        }
    }

    func testServerAlpha0_25() {
        withDependencies {
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .freeTier)
        } operation: {
            let sut = ServerItemViewModelCore(serverModel: ServerModel.testServer2UnderMaintenance.serverInfo)
            XCTAssertEqual(sut.alphaOfMainElements, 0.25)
        }
    }

    func testUserTierPlus() {
        withDependencies {
            $0.vpnKeychain = VpnKeychainMock(planName: "plus", maxTier: .paidTier)
        } operation: {
            let sut = ServerItemViewModelCore(serverModel: ServerModel.testServer1.serverInfo)
            XCTAssertEqual(sut.userTier, .paidTier)
        }
    }
}
