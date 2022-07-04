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
    static let username = "user1"
    let testDefaults = UserDefaults(suiteName: "test")!

    override func setUp() {
        super.setUp()

        testDefaults.removeObject(forKey: "NATType\(Self.username)")
        Storage.setSpecificDefaults(defaults: testDefaults)
    }

    func testReturnsSettingFromProperties() throws {
        let variants: [NATType] = NATType.allCases

        for type in variants {
            let (factory, storage) = getFactory(natType: type, tier: CoreAppConstants.VpnTiers.plus)
            XCTAssertEqual(NATTypePropertyProviderImplementation(factory, storage: storage).natType, type)
        }
    }

    func testWhenNothingIsSetReturnsStrict() throws {
        var (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssertEqual(NATTypePropertyProviderImplementation(factory, storage: storage).natType, NATType.strictNAT)
        (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertEqual(NATTypePropertyProviderImplementation(factory, storage: storage).natType, NATType.strictNAT)
        (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertEqual(NATTypePropertyProviderImplementation(factory, storage: storage).natType, NATType.strictNAT)
    }

    func testSavesValueToStorage() {
        let propertiesManager = PropertiesManagerMock()
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.plus)
        let factory = PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)

        let provider = NATTypePropertyProviderImplementation(factory, storage: Storage())

        for type in NATType.allCases {
            provider.natType = type
            XCTAssertEqual(testDefaults.integer(forKey: "NATType\(Self.username)"), type.rawValue)
            XCTAssertEqual(provider.natType, type)
        }
    }

    func testFreeUserCantTurnModerateNATOn() throws {
        let (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.free)
        XCTAssertFalse(NATTypePropertyProviderImplementation(factory, storage: storage).isUserEligibleForNATTypeChange)
    }

    func testPaidUserCanTurnModerateNATOn() throws {
        var (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssertTrue(NATTypePropertyProviderImplementation(factory, storage: storage).isUserEligibleForNATTypeChange)
        (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertTrue(NATTypePropertyProviderImplementation(factory, storage: storage).isUserEligibleForNATTypeChange)
        (factory, storage) = getFactory(natType: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertTrue(NATTypePropertyProviderImplementation(factory, storage: storage).isUserEligibleForNATTypeChange)
    }

    // MARK: -

    private func getFactory(natType: NATType?, tier: Int) -> (PaidFeaturePropertyProviderFactoryMock, Storage) {
        let propertiesManager = PropertiesManagerMock()
        let userTierProvider = UserTierProviderMock(tier)
        let authKeychain = MockAuthKeychain(context: .mainApp)
        authKeychain.setMockUsername(Self.username)

        testDefaults.set(natType?.rawValue, forKey: "NATType\(Self.username)")
        return (PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider, authKeychainMock: authKeychain), Storage())
    }
}
