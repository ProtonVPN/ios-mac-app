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
    static let username = "user1"
    let testDefaults = UserDefaults(suiteName: "test")!

    override func setUp() {
        super.setUp()

        testDefaults.removeObject(forKey: "SafeMode\(Self.username)")
        Storage.setSpecificDefaults(defaults: testDefaults)
    }

    func testReturnsSettingFromProperties() throws {
        let variants: [Bool] = [true, false]

        for type in variants {
            let factory = getFactory(safeMode: type, tier: CoreAppConstants.VpnTiers.plus)
            XCTAssertEqual(SafeModePropertyProviderImplementation(factory).safeMode, type)
        }
    }

    func testReturnsSettingFromPropertiesWhenDisabledByFeatureFlag() throws {
        let variants: [Bool] = [true, false]

        for type in variants {
            let factory = getFactory(safeMode: type, tier: CoreAppConstants.VpnTiers.plus, safeModeFeatureFlag: false)
            XCTAssertNil(SafeModePropertyProviderImplementation(factory).safeMode)
        }
    }

    func testWhenNothingIsSetReturnsTrue() throws {
        var factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssertEqual(SafeModePropertyProviderImplementation(factory).safeMode, true)
        factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertEqual(SafeModePropertyProviderImplementation(factory).safeMode, true)
        factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertEqual(SafeModePropertyProviderImplementation(factory).safeMode, true)
    }

    func testWhenNothingIsSetReturnsFalseWhenDisabledByFeatureFlag() throws {
        var factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.basic, safeModeFeatureFlag: false)
        XCTAssertNil(SafeModePropertyProviderImplementation(factory).safeMode)
        factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.plus, safeModeFeatureFlag: false)
        XCTAssertNil(SafeModePropertyProviderImplementation(factory).safeMode)
        factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.visionary, safeModeFeatureFlag: false)
        XCTAssertNil(SafeModePropertyProviderImplementation(factory).safeMode)
    }

    func testSavesValueToStorage() {
        let factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.plus)
        let provider = SafeModePropertyProviderImplementation(factory)

        for type in [true, false] {
            provider.safeMode = type
            XCTAssertEqual(testDefaults.object(forKey: "SafeMode\(Self.username)") as? Bool, type)
            XCTAssertEqual(provider.safeMode, type)
        }
    }

    func testFreeUserCantTurnOffSafeMode() throws {
        let factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.free)
        XCTAssertFalse(SafeModePropertyProviderImplementation(factory).isUserEligibleForSafeModeChange)
    }

    func testPaidUserCanTurnOffSafeMode() throws {
        var factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.basic)
        XCTAssertTrue(SafeModePropertyProviderImplementation(factory).isUserEligibleForSafeModeChange)
        factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.plus)
        XCTAssertTrue(SafeModePropertyProviderImplementation(factory).isUserEligibleForSafeModeChange)
        factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.visionary)
        XCTAssertTrue(SafeModePropertyProviderImplementation(factory).isUserEligibleForSafeModeChange)
    }

    // MARK: -

    private func getFactory(safeMode: Bool?, tier: Int, safeModeFeatureFlag: Bool = true) -> PaidFeaturePropertyProviderFactoryMock {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.featureFlags = FeatureFlags(smartReconnect: true, vpnAccelerator: true, netShield: true, streamingServicesLogos: true, portForwarding: true, moderateNAT: true, pollNotificationAPI: true, serverRefresh: true, guestHoles: true, safeMode: safeModeFeatureFlag, promoCode: true)
        let userTierProvider = UserTierProviderMock(tier)
        let authKeychain = MockAuthKeychain(context: .mainApp)
        authKeychain.setMockUsername(Self.username)
        testDefaults.set(safeMode, forKey: "SafeMode\(Self.username)")
        return PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider, authKeychainMock: authKeychain)
    }
}
