//
//  Created on 21.02.2022.
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
@testable import vpncore

final class NATTypePropertyProviderImplementationTests: XCTestCase {
    let testDefauls = UserDefaults(suiteName: "test")!

    override func setUp() {
        super.setUp()

        testDefauls.removeObject(forKey: "NATType")
        Storage.setSpecificDefaults(defaults: testDefauls)
    }

    func testReturnsSettingFromProperties() throws {
        let variants: [NATType] = NATType.allCases

        for type in variants {
            let (factory, storage) = getFactory(natType: type, tier: CoreAppConstants.VpnTiers.plus)
            XCTAssertEqual(NATTypePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).natType, type)
        }
    }

    func testWhenNothingIsSetReturnsStrict() throws {
        var (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssertEqual(NATTypePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).natType, NATType.strictNAT)
        (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertEqual(NATTypePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).natType, NATType.strictNAT)
        (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertEqual(NATTypePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).natType, NATType.strictNAT)
    }

    func testSavesValueToStorage() {
        let propertiesManager = PropertiesManagerMock()
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.plus)
        let factory = PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)

        let provider = NATTypePropertyProviderImplementation(factory, storage: Storage(), userInfoProvider: self)

        for type in NATType.allCases {
            provider.natType = type
            XCTAssertEqual(testDefauls.integer(forKey: "NATType"), type.rawValue)
            XCTAssertEqual(provider.natType, type)
        }
    }

    func testFreeUserCantTurnModerateNATOn() throws {
        let (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.free)
        XCTAssertFalse(NATTypePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForNATTypeChange)
    }

    func testPaidUserCanTurnModerateNATOn() throws {
        var (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertTrue(NATTypePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForNATTypeChange)
        (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertTrue(NATTypePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForNATTypeChange)
    }

    // MARK: -

    private func getFactory(natType: NATType?, tier: Int) -> (PaidFeaturePropertyProviderFactoryMock, Storage) {
        let propertiesManager = PropertiesManagerMock()
        let userTierProvider = UserTierProviderMock(tier)
        testDefauls.set(natType?.rawValue, forKey: "NATType")
        return (PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider), Storage())
    }
}

extension NATTypePropertyProviderImplementationTests: UserInfoProvider {
    static var username: String? {
        return nil
    }
}
