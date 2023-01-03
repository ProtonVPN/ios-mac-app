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

class UniquelyMergeableDictionaryTests: XCTestCase {

    // MARK: Uniqued tests

    func testUniquingPreservesDictionary() {
        let original = [1: [1, 1], 2: [2, 2]]

        let uniqued = original.uniqued

        XCTAssertEqual(original, uniqued, "Membership of elements should be preserved.")
    }

    // MARK: Merging tests

    func testMergingEmptyWithEmptyReturnsEmpty() {
        let empty: [Int: [Int]] = [:]

        let merged = empty.uniquelyMerging(with: empty)

        XCTAssertEqual(merged, empty, "Merging empty dictionaries should result in an empty dictionary.")
    }

    func testMergingWithEmptyReturnsOriginal() {
        let empty: [Int: [Int]] = [:]
        let original = [
            1: [3],
            2: [4]
        ]

        let merged = original.uniquelyMerging(with: empty)

        XCTAssertEqual(merged, original, "Merging with an empty dictionary should preserve the original dictionary.")
    }

    func testMergingEmptyWithArrayReturnsArray() {
        let empty: [Int: [Int]] = [:]
        let original = [
            1: [3],
            2: [4]
        ]

        let merged = empty.uniquelyMerging(with: original)

        XCTAssertEqual(merged, original, "Merging an empty dictionary should preserve the second dictionary.")
    }

    func testMergedDictionaryContainsAllKeys() {
        let first = [1: [3]]
        let second = [2: [4], 5: [1]]
        let expected = [
            1: [3],
            2: [4],
            5: [1]
        ]

        let merged = first.uniquelyMerging(with: second)

        XCTAssertEqual(Set(merged.keys), Set([1, 2, 5]), "Merged dictionary should contain all keys.")
        XCTAssertEqual(merged, expected, "Merging should combine entries from the child dictionaries.")
    }

    func testMergingCombinesValuesWithDuplicateKeys() {
        let first = [1: [3]]
        let second = [1: [4]]
        let expected = [1: [3, 4]]

        let merged = first.uniquelyMerging(with: second)

        XCTAssertEqual(merged, expected, "Values under the same keys should be combined.")
    }

    // MARK: Flattening tests

    func testFlatteningEmptyDictionaryReturnsEmptyDictionary() {
        let original: [Int: [Int]] = [:]

        let flattened = original.flattened(removing: 0)

        XCTAssertEqual(flattened, [:], "Flattening empty dictionaries should return an empty dictionary.")
    }

    func testFlatteningDictionaryWithoutWildcardPreservesDictionary() {
        let raw = [
            "CH": [1]
        ]

        let flattened = raw.flattened(removing: "*")

        XCTAssertEqual(raw, flattened, "Flattening a dictionary without a wildcard should not alter the dictionary.")
    }

    func testFlatteningEmptyDictionaryRemovesWildcardEntry() {
        let original = [
            "*": [1]
        ]

        let flattened = original.flattened(removing: "*")

        XCTAssertNil(flattened["*"], "The wildcard entry should be removed from the dictionary after flattening.")
    }

    func testFlatteningRemovesWildcardEntry() {
        let original = [
            "X": [1],
            "*": [2]
        ]

        let flattened = original.flattened(removing: "*")

        XCTAssertNil(flattened["*"], "The wildcard entry should be removed from the dictionary after flattening.")
    }

    func testFlatteningMergesValues() {
        let original = [
            "CH": [1],
            "*": [3]
        ]

        let flattened = original.flattened(removing: "*")

        XCTAssertEqual(flattened["CH"]!, [1, 3], "Wildcard values should be merged with other values.")
    }

    func testFlatteningDoesNotDuplicateValues() {
        let original = [
            "CH": [1],
            "*": [1]
        ]

        let flattened = original.flattened(removing: "*")

        XCTAssertEqual(flattened["CH"]!, [1], "Merged values should not be duplicated when flattening.")
    }

    func testFlatteningNestedDictionary() {
        let original = [
            "CH": [1: [1]],
            "US": [1: [1, 3]],
            "*": [1: [2]]
        ]
        let expected = [
            "CH": [1: [1, 2]],
            "US": [1: [1, 3, 2]]
        ]

        let flattened = original.flattened(removing: "*")

        XCTAssertEqual(flattened, expected, "Flattening nested dictionaries")
    }
}
