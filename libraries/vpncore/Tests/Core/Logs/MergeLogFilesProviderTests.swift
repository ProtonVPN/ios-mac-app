//
//  Created on 2022-02-15.
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

class MergeLogFilesProviderTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testMerge() throws {
        let inputData = [
            ("Unique name 1", URL(string: "File1.log")),
            ("Unique name 2", URL(string: "File2.log")),
            ("Unique name 10", URL(string: "File10.log")),
            ("Unique name 11", nil),
            ("Unique name 12", URL(string: "File2.log")), // Files url is the same here and in element at index 1, so this entry should be discarded during merge.
        ]

        let provider1 = MockLogFilesProvider()
        provider1.logFiles = [inputData[0], inputData[1]]
        let provider2 = MockLogFilesProvider()
        provider2.logFiles = [inputData[2], inputData[3], inputData[4]]
        let provider3 = MockLogFilesProvider()

        let merger = MergeLogFilesProvider(providers: provider1, provider2, provider3)
        let result = merger.logFiles

        XCTAssertEqual(result.count, 4)
        for i in 0...3 {
            XCTAssert(result[i] == inputData[i], "Elements at index \(i) are not equal: \(result[i]) vs. \(inputData[i]).")
        }
    }

}
