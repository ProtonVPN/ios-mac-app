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

final class SafeModePropertyProviderImplementationTests: XCTestCase {
    let testDefauls = UserDefaults(suiteName: "test")!

    override func setUp() {
        super.setUp()

        testDefauls.removeObject(forKey: "SafeMode")
        Storage.setSpecificDefaults(defaults: testDefauls)
    }

    func testReturnsSettingFromProperties() throws {
        let variants: [Bool] = [true, false]

        for type in variants {
            let (factory, storage) = getFactory(safeMode: type, tier: CoreAppConstants.VpnTiers.plus)
            XCTAssertEqual(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).safeMode, type)
        }
    }

    func testReturnsSettingFromPropertiesWhenDisabledByFeatureFlag() throws {
        let variants: [Bool] = [true, false]

        for type in variants {
            let (factory, storage) = getFactory(safeMode: type, tier: CoreAppConstants.VpnTiers.plus, safeModeFeatureFlag: false)
            XCTAssertNil(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).safeMode)
        }
    }

    func testWhenNothingIsSetReturnsTrue() throws {
        var (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssertEqual(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).safeMode, true)
        (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertEqual(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).safeMode, true)
        (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertEqual(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).safeMode, true)
    }

    func testWhenNothingIsSetReturnsFalseWhenDisabledByFeatureFlag() throws {
        var (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.basic, safeModeFeatureFlag: false)
        XCTAssertNil(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).safeMode)
        (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.plus, safeModeFeatureFlag: false)
        XCTAssertNil(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).safeMode)
        (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.visionary, safeModeFeatureFlag: false)
        XCTAssertNil(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).safeMode)
    }

    func testSavesValueToStorage() {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.featureFlags = FeatureFlags(smartReconnect: true, vpnAccelerator: true, netShield: true, streamingServicesLogos: true, portForwarding: true, moderateNAT: true, pollNotificationAPI: true, serverRefresh: true, guestHoles: true, safeMode: true)
        let userTierProvider = UserTierProviderMock(CoreAppConstants.VpnTiers.plus)
        let factory = PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider)

        let provider = SafeModePropertyProviderImplementation(factory, storage: Storage(), userInfoProvider: self)

        for type in [true, false] {
            provider.safeMode = type
            XCTAssertEqual(testDefauls.object(forKey: "SafeMode") as? Bool, type)
            XCTAssertEqual(provider.safeMode, type)
        }
    }

    func testFreeUserCantTurnOffSafeMode() throws {
        let (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.free)
        XCTAssertFalse(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForSafeModeChange)
    }

    func testPaidUserCanTurnOffSafeMode() throws {
        var (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssertTrue(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForSafeModeChange)
        (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertTrue(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForSafeModeChange)
        (factory, storage) = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertTrue(SafeModePropertyProviderImplementation(factory, storage: storage, userInfoProvider: self).isUserEligibleForSafeModeChange)
    }

    // MARK: -

    private func getFactory(safeMode: Bool?, tier: Int, safeModeFeatureFlag: Bool = true) -> (PaidFeaturePropertyProviderFactoryMock, Storage) {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.featureFlags = FeatureFlags(smartReconnect: true, vpnAccelerator: true, netShield: true, streamingServicesLogos: true, portForwarding: true, moderateNAT: true, pollNotificationAPI: true, serverRefresh: true, guestHoles: true, safeMode: safeModeFeatureFlag)
        let userTierProvider = UserTierProviderMock(tier)
        testDefauls.set(safeMode, forKey: "SafeMode")
        return (PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider), Storage())
    }
}

extension SafeModePropertyProviderImplementationTests: UserInfoProvider {
    static var username: String? {
        return nil
    }
}

