//
//  Created on 12/03/2024.
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

import Foundation
import XCTest

import Dependencies

import Domain
import Localization
import PersistenceTestSupport

final class TextSearchTests: TestIsolatedDatabaseTestCase {

    let mockCountryNameProvider: CountryNameProvider = .mock(
        codeToNameDictionary: [
            "TR": "Türkiye", // extra diacritics for fun
            "LV": "Łotwa", // 'Ł' edge case (apparently is not a diacritic)
            "UK": "A Kingdom United", // ISO region API edge case (United Kingdom is represented under ISO code "GB")
            "US": "'Merica", // code and name with disjoint character sets: testMatchesFullCountryCode
            "ZZ": "Zzz"
        ]
    )

    override func setUpWithError() throws {
        try withDependencies {
            $0.countryNameProvider = mockCountryNameProvider
        } operation: {
            try super.setUpWithError()
        }
    }

    private func evaluate(scenarios: [(String, VPNServer?, String)]) {
        scenarios.forEach { (query, expectedResult, reason) in
            let result = getServerMatching(query: query)
            XCTAssertEqual(result, expectedResult, reason)
        }
    }

    private func getServerMatching(query: String) -> VPNServer? {
        repository.getFirstServer(filteredBy: [.matches(query)], orderedBy: .nameAscending)
    }

    // MARK: Country Name

    func testMatchesLocalizedCountryName() {
        let server = TestData.createMockServer(withID: "UK1", countryCode: "UK") // "A Kingdom United"
        repository.upsert(servers: [server])

        let scenarios: [(String, VPNServer?, String)] = [
            ("A Kingdom United", server, "Country name should be matched when query is a full, case sensitive match"),
            ("a kInGdOm unITeD", server, "Country name should be matched when query is a full match"),
            ("a kingdom", server, "Country name should be matched for queries that are a prefix of the country name"),
            ("kingdom", server, "Country name should be matched for queries that are a substring of the country name"),
            ("xyz", nil, "No matches expected when query is not a substring of the country name"),
            // The following are not necessarily functional requirements, but help highlight unintentional changes
            ("king dom", nil, "Spaces should be evaluated when matching against country name"),
            (" ", server, "If the country name contains spaces, ' ' queries should match against it"),
            ("", server, "Empty queries should match against everything")
        ]

        evaluate(scenarios: scenarios)
    }

    func testDiacriticInsensitiveMatches() {
        let server = TestData.createMockServer(withID: "TR1", countryCode: "TR")
        repository.upsert(servers: [server])

        XCTAssertEqual(getServerMatching(query: "tür"), server, "Queries with explicit diacritics should match")
        XCTAssertEqual(getServerMatching(query: "tur"), server, "Queries without explicit diacritics should match")
    }

    func testExtraDiacriticMatches() {
        let server = TestData.createMockServer(withID: "LV1", countryCode: "LV")
        repository.upsert(servers: [server])

        XCTAssertEqual(getServerMatching(query: "łotw"), server, "Queries with explicit diacritics should match")
        XCTAssertEqual(getServerMatching(query: "lotw"), server, "Queries without explicit diacritics should match")
    }

    // MARK: Country Code

    func testMatchesFullCountryCode() {
        // Server for which the localized country name's character set is disjoing with the country code
        let server = TestData.createMockServer(withID: "US1", name: "abcd", countryCode: "US") // "'Merica"
        repository.upsert(servers: [server])


        let scenarios: [(String, VPNServer?, String)] = [
            ("U", nil, "Partial country codes should not be matched"),
            ("US", server, "Full country codes should be matched"),
            ("uS", server, "Country code search should be case insensitive")
        ]

        evaluate(scenarios: scenarios)
    }

    // MARK: Server Name

    func testMatchesServerName() {
        let server = TestData.createMockServer(withID: "abcd", name: "US#01", countryCode: "ZZ")

        repository.upsert(servers: [server])

        let scenarios: [(String, VPNServer?, String)] = [
            ("US#01", server, "Full server name should be matched"),
            ("US#0", server, "Server name prefix with partial server number should be matched"),
            ("US#2", nil, "Search terms with more characters following a matching server prefix, should not be matched"),
            ("S#01", nil, "Server name suffixes should not be matched"),
            ("S#0", nil, "Server name substrings should not be matched"),
        ]

        evaluate(scenarios: scenarios)
    }
}
