//
//  Created on 09/04/2024.
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

import XCTest

import Dependencies
import GRDB

import Domain
import PersistenceTestSupport
@testable import Persistence

final class RoundingTests: CaseIsolatedDatabaseTestCase {

    func testRoundToSmallest100() {
        XCTAssertEqual(4123.roundedServerCount(), 4100)
    }

    func testRoundToSmallest100With14kServers() {
        XCTAssertEqual(14123.roundedServerCount(), 14100)
    }

    func testRoundToSmallest100EvenIfTheNumberIsAlreadyRounded() {
        XCTAssertEqual(4200.roundedServerCount(), 4100)
    }

    func testRoundToSmallest100JustToBeSure() {
        XCTAssertEqual(4201.roundedServerCount(), 4200)
    }

    func testRoundToSmallest100IfItsLessThan1000() {
        XCTAssertEqual(201.roundedServerCount(), 200)
    }

    func testRoundToSmallest100IfItsLessThan201() {
        XCTAssertEqual(200.roundedServerCount(), 100)
    }

    func testRoundToSmallest100IfItsLessThan101() {
        XCTAssertEqual(100.roundedServerCount(), 100)
    }

    func testDontRoundToSmallest100IfItsLessThan100() {
        XCTAssertEqual(99.roundedServerCount(), 99)
    }

    func testDontRoundToSmallest100IfIts1() {
        XCTAssertEqual(1.roundedServerCount(), 1)
    }
}
