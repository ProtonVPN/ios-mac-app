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

import Foundation
import XCTest
@testable import Review

final class UserDefaultsReviewDataStorageTests: XCTestCase {
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()

        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
    }

    func testDefaultValues() {
        let storage = UserDefaultsReviewDataStorage(userDefaults: userDefaults)
        XCTAssertNil(storage.firstSuccessConnectionStartTimestamp)
        XCTAssertNil(storage.activeConnectionStartTimestamp)
        XCTAssertNil(storage.lastReviewShownTimestamp)
        XCTAssertEqual(storage.successConnectionsInARowCount, 0)
    }

    func testStoringValues() {
        let storage = UserDefaultsReviewDataStorage(userDefaults: userDefaults)
        storage.successConnectionsInARowCount = 4
        XCTAssertEqual(storage.successConnectionsInARowCount, 4)
        storage.successConnectionsInARowCount = 1
        XCTAssertEqual(storage.successConnectionsInARowCount, 1)

        var date = Date().addingTimeInterval(45)
        storage.lastReviewShownTimestamp = date
        XCTAssertNotNil(storage.lastReviewShownTimestamp)
        XCTAssertEqual(storage.lastReviewShownTimestamp!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)

        date = Date().addingTimeInterval(78778)
        storage.lastReviewShownTimestamp = date
        XCTAssertNotNil(storage.lastReviewShownTimestamp)
        XCTAssertEqual(storage.lastReviewShownTimestamp!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)

        date = Date().addingTimeInterval(-6568)
        storage.activeConnectionStartTimestamp = date
        XCTAssertNotNil(storage.activeConnectionStartTimestamp)
        XCTAssertEqual(storage.activeConnectionStartTimestamp!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)

        date = Date().addingTimeInterval(-15)
        storage.activeConnectionStartTimestamp = date
        XCTAssertNotNil(storage.activeConnectionStartTimestamp)
        XCTAssertEqual(storage.activeConnectionStartTimestamp!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)

        date = Date().addingTimeInterval(8978)
        storage.firstSuccessConnectionStartTimestamp = date
        XCTAssertNotNil(storage.firstSuccessConnectionStartTimestamp)
        XCTAssertEqual(storage.firstSuccessConnectionStartTimestamp!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)

        date = Date().addingTimeInterval(-1875)
        storage.firstSuccessConnectionStartTimestamp = date
        XCTAssertNotNil(storage.firstSuccessConnectionStartTimestamp)
        XCTAssertEqual(storage.firstSuccessConnectionStartTimestamp!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testClearingValues() {
        let storage = UserDefaultsReviewDataStorage(userDefaults: userDefaults)
        storage.successConnectionsInARowCount = 4
        storage.lastReviewShownTimestamp = Date().addingTimeInterval(45)
        storage.activeConnectionStartTimestamp = Date().addingTimeInterval(69)
        storage.firstSuccessConnectionStartTimestamp = Date().addingTimeInterval(89)
        storage.clear()

        XCTAssertNil(storage.firstSuccessConnectionStartTimestamp)
        XCTAssertNil(storage.activeConnectionStartTimestamp)
        XCTAssertNil(storage.lastReviewShownTimestamp)
        XCTAssertEqual(storage.successConnectionsInARowCount, 0)
    }

    func testValuesBeingOnlyDepedendOnUserDefauts() {
        let storage = UserDefaultsReviewDataStorage(userDefaults: userDefaults)
        storage.successConnectionsInARowCount = 4

        let storage2 = UserDefaultsReviewDataStorage(userDefaults: userDefaults)
        XCTAssertEqual(storage2.successConnectionsInARowCount, 4)
    }
}
