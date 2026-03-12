//
//  Created on 19/02/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
@testable import CountriesShared
import Testing

@Suite("SearchResultsDisplayFeature Tests")
@MainActor
struct SearchResultsDisplayFeatureReducerTests {
    @Test("free tier taps route to upsell delegates")
    func freeTierTapActionsEmitUpsellDelegates() async {
        let country = SearchCountryIndex(id: "GB", countryCode: "GB", name: "United Kingdom")
        let city = SearchCityIndex(
            id: "london-gb",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            countryCode: "GB"
        )
        let server = SearchServerIndex(
            id: "gb-1",
            serverName: "UK#1",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            exitCountryCode: "GB",
            entryCountryCode: nil,
            tier: .free,
            load: 50,
            isP2PAvailable: false,
            isTorAvailable: false,
            isSmartAvailable: false,
            isStreamingAvailable: false,
            isUsersTierTooLow: false,
            underMaintenance: false
        )
        let initialState = SearchResultsDisplayFeature.State(
            rows: [.country(country), .city(city), .server(server)],
            searchText: "uk",
            isFreeTier: true
        )
        let store = TestStore(initialState: initialState) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countrySelected(country))
        await store.receive(\.delegate.showCountryUpsell)
        await store.send(.citySelected(city))
        await store.receive(\.delegate.showCountryUpsell)
        await store.send(.serverSelected(server))
        await store.send(.serverSelected(.init(
            id: "gb-2",
            serverName: "UK#2",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            exitCountryCode: "GB",
            entryCountryCode: nil,
            tier: .plus,
            load: 40,
            isP2PAvailable: false,
            isTorAvailable: false,
            isSmartAvailable: false,
            isStreamingAvailable: false,
            isUsersTierTooLow: true,
            underMaintenance: false
        )))
        await store.receive(\.delegate.showUpsell)
        await store.send(.showUpsell)
        await store.receive(\.delegate.showUpsell)
        await store.send(.showCountryUpsell("GB"))
        await store.receive(\.delegate.showCountryUpsell)
    }
}
