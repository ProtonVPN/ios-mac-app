//
//  Created on 30.03.2022.
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
@testable import Review

final class ExtensionsTests: XCTestCase {
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()

        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
    }

    func testStoringDateInUserDefaults() {
        let date = Date(timeIntervalSinceNow: 5) // just so it is not now
        userDefaults.set(date, forKey: "K1")
        XCTAssertNotNil(userDefaults.date(forKey: "K1"))
        XCTAssertEqual(date.timeIntervalSince1970, userDefaults.date(forKey: "K1")!.timeIntervalSince1970, accuracy: 0.001)
    }

    func testStoringNilDateInUserDefaults() {
        let date = Date(timeIntervalSinceNow: 5) // just so it is not now
        userDefaults.set(date, forKey: "K1")

        let nilDate: Date? = nil
        userDefaults.set(nilDate, forKey: "K1")
        XCTAssertNil(userDefaults.date(forKey: "K1"))
    }
}
