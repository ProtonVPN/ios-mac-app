//
//  Created on 23/02/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Dependencies
import Domain
import DomainTestSupport
import Foundation
@testable import LegacyCommon
import Sharing
import Telemetry
import VPNShared
import VPNSharedTesting
import XCTest

class PropertiesManagerTests: XCTestCase {
    var sut: PropertiesManagerProtocol!
    private static let userDefaults: UserDefaults = .testValue(suiteName: #file)
    @Shared(.userAccountCreationDate) var userAccountCreationDate

    static let watershed = DomainConstants.WatershedEvent.telemetrySettingDefaultValue.timeIntervalSince1970

    override func invokeTest() {
        withDependencies { values in
            values.storage = MemoryStorage()
            let keychain = MockAuthKeychain()
            keychain.setMockUsername("user")
            values.authKeychain = keychain
            values.defaultAppStorage = Self.userDefaults
            values.defaultsProvider = DefaultsProvider(
                getDefaults: { Self.userDefaults }
            )
            $userAccountCreationDate.withLock {
                $0 = .init(timeIntervalSince1970: Self.watershed - 1)
            }
        } operation: {
            super.invokeTest()
        }
    }

    override func setUp() {
        super.setUp()
        sut = PropertiesManager()
    }

    override func tearDown() {
        super.tearDown()
        Self.userDefaults.removePersistentDomain(forName: #file)
    }
}
