//
//  Created on 2022-06-27.
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

import Foundation
import XCTest

import Localization
import Strings

class LocalizationUtilityTests: XCTestCase {
    let mockResolver = LocaleResolverMock()

    override func setUp() {
        super.setUp()
        LocalizationUtility.localeResolver = mockResolver
    }

    override func tearDown() {
        super.tearDown()
        LocalizationUtility.localeResolver = LocaleResolverImplementation.default
    }

    func testLocalizationUtility() {
        XCTAssertEqual(LocalizationUtility.default.countryName(forCode: "CH"), "Suisse")
        XCTAssertNil(LocalizationUtility.default.countryName(forCode: "CA"))

        mockResolver.preferredLanguages = ["en-US"]
        XCTAssertEqual(LocalizationUtility.default.countryName(forCode: "US"), "Murica")
        XCTAssertEqual(LocalizationUtility.default.countryName(forCode: "FR"), "France")
    }
}
