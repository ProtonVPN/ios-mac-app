//
//  Created on 14.03.2022.
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
@testable import Search

final class StringNormalizationTests: XCTestCase {
    func testStringAccentNormalization() {
        XCTAssertEqual("Brésil".normalized, "Bresil".normalized)
        XCTAssertEqual("Zurïch".normalized, "Zurich".normalized)
    }

    func testStringCaseNormalization() {
        XCTAssertEqual("bresil".normalized, "Bresil".normalized)
        XCTAssertEqual("United States".normalized, "unITed StaTEs".normalized)
        XCTAssertEqual("São Paulo".normalized, "sao paulo".normalized)
    }
}
