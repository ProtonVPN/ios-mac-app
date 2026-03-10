//
//  Created on 10/03/2026 by Max Kupetskyi.
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

#if DEBUG
    import ComposableArchitecture

    public extension SearchRecentsFeature.State {
        static var previewFilled: Self {
            var state = Self()
            state.recentSearches = ["United States", "Amsterdam", "CH-US#7"]
            return state
        }

        static var previewEmpty: Self {
            Self()
        }
    }

    public extension SearchResultsDisplayFeature.State {
        static var previewMixed: Self {
            .init(
                rows: IdentifiedArray(uniqueElements: [
                    .upsell,
                    .sectionHeader("Countries (1)"),
                    .country(.init(id: "us", countryCode: "US", name: "United States")),
                    .sectionHeader("Cities (1)"),
                    .city(.init(
                        id: "new-york-us",
                        cityName: "New York",
                        translatedCityName: nil,
                        countryName: "United States",
                        countryCode: "US"
                    )),
                    .sectionHeader("Plus (2)"),
                    .server(.init(
                        id: "us-ny-1",
                        serverName: "US-NY#1",
                        cityName: "New York",
                        translatedCityName: nil,
                        countryName: "United States",
                        exitCountryCode: "US",
                        entryCountryCode: nil,
                        tier: .plus,
                        load: 34,
                        isP2PAvailable: true,
                        isTorAvailable: true,
                        isSmartAvailable: false,
                        isStreamingAvailable: true,
                        isUsersTierTooLow: false,
                        underMaintenance: false
                    )),
                    .secureCoreCountry(.init(
                        id: "ch-us-7",
                        serverName: "CH-US#7",
                        cityName: "New York",
                        translatedCityName: nil,
                        countryName: "United States",
                        exitCountryCode: "US",
                        entryCountryCode: "CH",
                        tier: .plus,
                        load: 18,
                        isP2PAvailable: false,
                        isTorAvailable: false,
                        isSmartAvailable: false,
                        isStreamingAvailable: false,
                        isUsersTierTooLow: false,
                        underMaintenance: false
                    )),
                ]),
                searchText: "us"
            )
        }
    }
#endif
