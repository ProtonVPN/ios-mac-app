//
//  Created on 03/01/2023.
//
//  Copyright (c) 2023 Proton AG
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
@testable import vpncore

class UniquelyMergeableArrayTests: XCTestCase {

    // MARK: Uniqued tests

    func testUniquingPreservesUniqueElements() {
        let original = [2, 3, 14, 1, 5, 15, 4, 7, 9, 8, 11, 17]

        let uniqued = original.uniqued

        XCTAssertEqual(Set(original), Set(uniqued), "Membership of elements should be preserved.")
    }

    func testUniquingPreservesUniqueElementOrder() {
        let original = [2, 3, 14, 1, 5, 15, 4, 7, 9, 8, 11, 17]

        (1 ..< 100).forEach { _ in
            let uniqued = original.uniqued

            XCTAssertEqual(original, uniqued, "The order of unique elements should be preserved.")
        }
    }
    
    func testUniquingRemovesDuplicateElements() {
        let original = [2, 3, 1, 5, 3, 2]

        let uniqued = original.uniqued

        XCTAssertEqual(uniqued, [2, 3, 1, 5], "Duplicate elements should be removed while preserving order.")
    }

    // MARK: Merging tests

    func testMergingEmptyWithEmptyReturnsEmpty() {
        let empty: [Int] = []

        let merged = empty.uniquelyMerging(with: empty)
        
        XCTAssertEqual(merged, [], "Merging empty arrays should result in an empty array.")
    }

    func testMergingWithEmptyReturnsOriginal() {
        let empty: [Int] = []
        let original = [1, 3, 2]

        let merged = original.uniquelyMerging(with: empty)

        XCTAssertEqual(merged, original, "Merging with an empty array should preserve the original array.")
    }

    func testMergingEmptyWithArrayReturnsArray() {
        let empty: [Int] = []
        let original = [1, 3, 2]

        let merged = empty.uniquelyMerging(with: original)

        XCTAssertEqual(merged, original, "Merging an empty array should preserve the second array.")
    }

    func testMergingPreservesOrder() {
        let first = [1, 3, 2]
        let second = [5, 4]

        let merged = first.uniquelyMerging(with: second)

        XCTAssertEqual(merged, [1, 3, 2, 5, 4], "Elements from the first array should precede the second array.")
    }

    func testMergingRemovesDuplicates() {
        let first = [1, 2, 2, 3]
        let second = [2, 3, 4, 5]

        let merged = first.uniquelyMerging(with: second)

        XCTAssertEqual(merged, [1, 2, 3, 4, 5], "Duplicate elements should be removed by merging.")
    }
}
