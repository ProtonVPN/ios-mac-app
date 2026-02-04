//
//  Created on 21/06/2024.
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

import ComposableArchitecture
import Domain
@testable import tvos_app
import XCTest

final class CountryListFeatureTests: XCTestCase {
    @MainActor
    func testCreateCountriesList() async {
        let store = TestStore(initialState: CountryListFeature.State()) {
            CountryListFeature()
        } withDependencies: {
            $0.serverRepository = .somePlusRecommendedCountries()
        }

        XCTAssertEqual(store.state.recommendedSection.items.count, 6) // 5 recommended + 1 fastest
        XCTAssertEqual(store.state.countriesSection.items.count, 10)
    }

    @MainActor
    func testCountryWithoutStreamingSupportIsMarkedAsSuch() async throws {
        let countryGroupWithoutStreamingSupport = ServerGroupInfo(
            kind: .country(code: "PL"),
            featureIntersection: .zero,
            featureUnion: .zero,
            minTier: 1,
            maxTier: 3,
            serverCount: 2,
            cityCount: 1,
            latitude: 0,
            longitude: 0,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: .all
        )

        let state = withDependencies {
            $0.serverRepository.groups = { _, _, _ in [countryGroupWithoutStreamingSupport] }
        } operation: {
            CountryListFeature.State()
        }

        let store = TestStore(initialState: state) {
            CountryListFeature()
        }

        let country = try XCTUnwrap(store.state.countriesSection.items.first)
        XCTAssertEqual(country.supportsStreaming, false)
    }
}
