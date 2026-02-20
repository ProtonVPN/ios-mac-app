//
//  Created on 20/02/2026 by Max Kupetskyi.
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

#if os(iOS)
    import ComposableArchitecture
    @testable import Countries_iOS
    @testable import CountriesShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct SearchResultsViewSnapshotTests {
        @Test("SearchResultsView")
        func searchResultsView() {
            let country = SearchCountryIndex(id: "US", countryCode: "US", name: "United States")
            let city = SearchCityIndex(
                id: "new-york-US",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                countryCode: "US"
            )
            let server = SearchServerIndex(
                id: "us-ny-1",
                serverName: "US-NY#1",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                exitCountryCode: "US",
                entryCountryCode: nil,
                tier: .free,
                load: 37,
                isP2PAvailable: true,
                isTorAvailable: true,
                isSmartAvailable: true,
                isStreamingAvailable: true,
                isUsersTierTooLow: false,
                underMaintenance: false
            )
            let server2 = SearchServerIndex(
                id: "us-ny-2",
                serverName: "US-NY#2",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                exitCountryCode: "US",
                entryCountryCode: nil,
                tier: .free,
                load: 67,
                isP2PAvailable: true,
                isTorAvailable: true,
                isSmartAvailable: true,
                isStreamingAvailable: true,
                isUsersTierTooLow: false,
                underMaintenance: true
            )
            let rows = IdentifiedArray(uniqueElements: [
                SearchResultRow.sectionHeader("Countries (1)"),
                SearchResultRow.country(country),
                SearchResultRow.sectionHeader("Cities (1)"),
                SearchResultRow.city(city),
                SearchResultRow.sectionHeader("Free (1)"),
                SearchResultRow.server(server),
                SearchResultRow.server(server2),
            ])

            let view = SearchResultsView(
                store: Store(
                    initialState: .init(
                        rows: rows,
                        searchText: "us"
                    )
                ) {
                    EmptyReducer()
                }
            )
            .background(Color(.background))
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }
    }

    extension SearchResultsViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Countries/Tests/CountriesTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
