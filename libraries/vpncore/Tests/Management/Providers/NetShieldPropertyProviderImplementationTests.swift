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

class NetShieldPropertyProviderImplementationTests: XCTestCase {

    func testReturnsSettingFromProperties() throws {
        let variants: [NetShieldType] = NetShieldType.allCases
        
        for type in variants {
            XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: type, tier: 1)).netShieldType == type)
        }
    }
    
    func testWhenNothingIsSetReturnsLevel1ForPaidUsers() throws {
        XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.basic)).netShieldType == .level1)
        XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.visionary)).netShieldType == .level1)
        XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.max)).netShieldType == .level1)
    }
    
    func testWhenNothingIsSetReturnsOffForFreeUsers() throws {
        XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.free)).netShieldType == .off)
    }
    
    func testWhenUnavailableOptionIsSetReturnsDefault() throws {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.netShieldType = .level2 // Not available for free users
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.free)
        let factory = MocksFactory(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)
        
        let provider = NetShieldPropertyProviderImplementation(factory)
        XCTAssert(provider.netShieldType == .off)
    }
    
    func testSavesValueToPropertiesManager() {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.netShieldType = nil
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.basic)
        let factory = MocksFactory(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)
        
        let provider = NetShieldPropertyProviderImplementation(factory)
        
        for type in NetShieldType.allCases {
            provider.netShieldType = type
            XCTAssert(propertiesManager.netShieldType == type)
            XCTAssert(provider.netShieldType == type)
        }
    }
    
    func testFreeUserCantTurnNetShieldOn() throws {
        XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.free)).isUserEligibleForNetShield == false)
    }
    
    func testPaidUserCanTurnNetShieldOn() throws {
        XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.basic)).isUserEligibleForNetShield == true)
        XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.visionary)).isUserEligibleForNetShield == true)
        XCTAssert(NetShieldPropertyProviderImplementation(getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.max)).isUserEligibleForNetShield == true)
    }
    
    // MARK: -
    
    private func getFactory(netShieldType: NetShieldType?, tier: Int) -> MocksFactory {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.netShieldType = netShieldType
        let userTierProvider = UserTierProviderMock(tier)
        return MocksFactory(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)
    }
}

private class MocksFactory: PropertiesManagerFactory, UserTierProviderFactory {
    
    var propertiesManager: PropertiesManagerMock
    var userTierProviderMock: UserTierProviderMock
    
    init(propertiesManager: PropertiesManagerMock, userTierProviderMock: UserTierProviderMock) {
        self.propertiesManager = propertiesManager
        self.userTierProviderMock = userTierProviderMock
    }
    
    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }
    
    func makeUserTierProvider() -> UserTierProvider {
        return userTierProviderMock
    }
    
}
