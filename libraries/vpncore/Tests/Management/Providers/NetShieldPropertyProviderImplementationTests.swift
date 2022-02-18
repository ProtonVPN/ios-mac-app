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
@testable import vpncore

class NetShieldPropertyProviderImplementationTests: XCTestCase {
    func testReturnsSettingFromProperties() throws {
        let variants: [NetShieldType] = NetShieldType.allCases
        
        for type in variants {
            let (factory, storage) = getFactory(netShieldType: type, tier: CoreAppConstants.VpnTiers.basic)
            XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).netShieldType == type)
        }
    }
    
    func testWhenNothingIsSetReturnsLevel1ForPaidUsers() throws {
        var (factory, storage) = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).netShieldType == .level1)
        (factory, storage) = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).netShieldType == .level1)
        (factory, storage) = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).netShieldType == .level1)
    }
    
    func testWhenNothingIsSetReturnsOffForFreeUsers() throws {
        let (factory, storage) = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.free)
        XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).netShieldType == .off)
    }
    
    func testWhenUnavailableOptionIsSetReturnsDefault() throws {
        let propertiesManager = PropertiesManagerMock()
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.free)
        let factory = MocksFactory(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)

        let defaults = UserDefaults(suiteName: "test")!
        let storage = Storage(defaults: defaults)
        let provider = NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self)
        XCTAssert(provider.netShieldType == .off)
    }
    
    func testSavesValueToStorage() {
        let propertiesManager = PropertiesManagerMock()
        let defaults = UserDefaults(suiteName: "test")!
        defaults.removeObject(forKey: "NetShield\(Self.username!)")
        let storage = Storage(defaults: defaults)
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.basic)
        let factory = MocksFactory(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)
        
        let provider = NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self)
        
        for type in NetShieldType.allCases {
            provider.netShieldType = type
            XCTAssertEqual(defaults.integer(forKey: "NetShield\(Self.username!)"), type.rawValue)
            XCTAssert(provider.netShieldType == type)
        }
    }
    
    func testFreeUserCantTurnNetShieldOn() throws {
        let (factory, storage) = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.free)
        XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForNetShield == false)
    }
    
    func testPaidUserCanTurnNetShieldOn() throws {
        var (factory, storage) = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForNetShield == true)
        (factory, storage) = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForNetShield == true)
        (factory, storage) = getFactory(netShieldType: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssert(NetShieldPropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForNetShield == true)
    }
    
    // MARK: -
    
    private func getFactory(netShieldType: NetShieldType?, tier: Int) -> (MocksFactory, Storage) {
        let propertiesManager = PropertiesManagerMock()
        let defaults = UserDefaults(suiteName: "test")!
        defaults.set(netShieldType?.rawValue, forKey: "NetShield\(Self.username!)")
        let storage = Storage(defaults: defaults)
        let userTierProvider = UserTierProviderMock(tier)
        return (MocksFactory(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider), storage)
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

extension NetShieldPropertyProviderImplementationTests: UserInfoProvider {
    static var username: String? {
        return "user1"
    }
}
