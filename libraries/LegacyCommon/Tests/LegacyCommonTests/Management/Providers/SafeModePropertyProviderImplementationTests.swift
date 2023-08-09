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
import Dependencies
import VPNShared
import VPNSharedTesting
@testable import LegacyCommon

final class SafeModePropertyProviderImplementationTests: XCTestCase {
    static let username = "user1"

    override func setUp() {
        super.setUp()
        @Dependency(\.defaultsProvider) var provider
        provider.getDefaults().removeObject(forKey: "SafeMode\(Self.username)")
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
        @Dependency(\.defaultsProvider) var defaultsProvider
        let factory = getFactory(safeMode: nil, tier: CoreAppConstants.VpnTiers.plus)
        let provider = SafeModePropertyProviderImplementation(factory)

        for type in [true, false] {
            provider.safeMode = type
            XCTAssertEqual(defaultsProvider.getDefaults().object(forKey: "SafeMode\(Self.username)") as? Bool, type)
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
        propertiesManager.featureFlags = FeatureFlags(safeMode: safeModeFeatureFlag)
        let userTierProvider = UserTierProviderMock(tier)
        let authKeychain = MockAuthKeychain(context: .mainApp)
        authKeychain.setMockUsername(Self.username)
        @Dependency(\.defaultsProvider) var provider
        provider.getDefaults().set(safeMode, forKey: "SafeMode\(Self.username)")
        return PaidFeaturePropertyProviderFactoryMock(propertiesManager: propertiesManager, userTierProviderMock: userTierProvider, authKeychainMock: authKeychain)
    }
}

private extension FeatureFlags {
    init(safeMode: Bool) {
        self.init(
            smartReconnect: true,
            vpnAccelerator: true,
            netShield: true,
            netShieldStats: true,
            streamingServicesLogos: true,
            portForwarding: true,
            moderateNAT: true,
            pollNotificationAPI: true,
            serverRefresh: true,
            guestHoles: true,
            safeMode: safeMode,
            promoCode: true,
            wireGuardTls: true,
            enforceDeprecatedProtocols: true,
            unsafeLanWarnings: true,
            newFree: true,
            localOverrides: nil
        )
    }
}
