//
//  NetShieldPropertyProviderImplementationTests.swift
//  vpncore - Created on 2021-01-06.
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

import XCTest
import VPNShared
import VPNSharedTesting
@testable import vpncore

final class NetShieldPropertyProviderImplementationTests: XCTestCase {
    static let username = "user1"
    let testDefaults = UserDefaults(suiteName: "test")!

    override func setUp() {
        super.setUp()

        testDefaults.removeObject(forKey: "NetShield\(Self.username)")
        Storage.setSpecificDefaults(defaults: testDefaults)
    }

    func testReturnsSettingFromProperties() throws {
        let variants: [NetShieldType] = NetShieldType.allCases
        
        for type in variants {
            let factory = getFactory(netShieldType: type, tier: CoreAppConstants.VpnTiers.basic)
            XCTAssertEqual(NetShieldPropertyProviderImplementation(factory).netShieldType, type)
        }
    }
    
    func testWhenNothingIsSetReturnsLevel1ForPaidUsers() throws {
        var factory = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssertEqual(NetShieldPropertyProviderImplementation(factory).netShieldType, NetShieldType.level1)
        factory = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertEqual(NetShieldPropertyProviderImplementation(factory).netShieldType, NetShieldType.level1)
        factory = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertEqual(NetShieldPropertyProviderImplementation(factory).netShieldType, NetShieldType.level1)
    }
    
    func testWhenNothingIsSetReturnsOffForFreeUsers() throws {
        let factory = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.free)
        XCTAssertEqual(NetShieldPropertyProviderImplementation(factory).netShieldType, NetShieldType.off)
    }
    
    func testWhenUnavailableOptionIsSetReturnsDefault() throws {
        let propertiesManager = PropertiesManagerMock()
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.free)
        let factory = PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)

        let provider = NetShieldPropertyProviderImplementation(factory)
        XCTAssertEqual(provider.netShieldType, NetShieldType.off)
    }
    
    func testSavesValueToStorage() {
        let propertiesManager = PropertiesManagerMock()
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.basic)
        let keychain = MockAuthKeychain()
        keychain.setMockUsername(Self.username)
        let factory = PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider, authKeychainMock: keychain)
        
        let provider = NetShieldPropertyProviderImplementation(factory)
        
        for type in NetShieldType.allCases {
            provider.netShieldType = type
            XCTAssertEqual(testDefaults.integer(forKey: "NetShield\(Self.username)"), type.rawValue)
            XCTAssertEqual(provider.netShieldType, type)
        }
    }
    
    func testFreeUserCantTurnNetShieldOn() throws {
        let factory = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.free)
        XCTAssert(NetShieldPropertyProviderImplementation(factory).isUserEligibleForNetShield == false)
    }
    
    func testPaidUserCanTurnNetShieldOn() throws {
        var factory = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssert(NetShieldPropertyProviderImplementation(factory).isUserEligibleForNetShield == true)
        factory = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssert(NetShieldPropertyProviderImplementation(factory).isUserEligibleForNetShield == true)
        factory = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssert(NetShieldPropertyProviderImplementation(factory).isUserEligibleForNetShield == true)
    }
    
    // MARK: -
    
    private func getFactory(netShieldType: NetShieldType?, tier: Int) -> PaidFeaturePropertyProviderFactoryMock {
        let propertiesManager = PropertiesManagerMock()
        let userTierProvider = UserTierProviderMock(tier)
        let authKeychain = MockAuthKeychain(context: .mainApp)
        authKeychain.setMockUsername(Self.username)
        testDefaults.set(netShieldType?.rawValue, forKey: "NetShield\(Self.username)")
        return PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider, authKeychainMock: authKeychain)
    }
}
