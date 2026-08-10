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
    import Connection
    @testable import Countries_iOS
    @testable import CountriesShared
    import Domain
    import DomainTestSupport
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
            let country = SearchCountryIndex(id: "US", kind: .country(code: "US"), name: "United States")
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

        @Test("SearchResultsView Paid All Categories")
        func searchResultsViewPaidAllCategories() {
            let country = SearchCountryIndex(id: "US", kind: .country(code: "US"), name: "United States")
            let city = SearchCityIndex(
                id: "new-york-US",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                countryCode: "US"
            )
            let stateItem = SearchCityIndex(
                id: "california-US",
                cityName: "California",
                translatedCityName: nil,
                countryName: "United States",
                countryCode: "US"
            )
            let plusServer = SearchServerIndex(
                id: "us-ca-1",
                serverName: "US-CA#1",
                cityName: "Los Angeles",
                translatedCityName: nil,
                countryName: "United States",
                exitCountryCode: "US",
                entryCountryCode: nil,
                tier: .plus,
                load: 21,
                isP2PAvailable: true,
                isTorAvailable: true,
                isSmartAvailable: true,
                isStreamingAvailable: true,
                isUsersTierTooLow: false,
                underMaintenance: false
            )
            let freeServer = SearchServerIndex(
                id: "us-ny-1",
                serverName: "US-NY#1",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                exitCountryCode: "US",
                entryCountryCode: nil,
                tier: .free,
                load: 44,
                isP2PAvailable: true,
                isTorAvailable: false,
                isSmartAvailable: false,
                isStreamingAvailable: false,
                isUsersTierTooLow: false,
                underMaintenance: false
            )
            let rows = IdentifiedArray(uniqueElements: [
                SearchResultRow.sectionHeader("Countries (1)"),
                SearchResultRow.country(country),
                SearchResultRow.sectionHeader("Cities (1)"),
                SearchResultRow.city(city),
                SearchResultRow.sectionHeader("States (1)"),
                SearchResultRow.state(stateItem),
                SearchResultRow.sectionHeader("Plus (1)"),
                SearchResultRow.server(plusServer),
                SearchResultRow.sectionHeader("Free (1)"),
                SearchResultRow.server(freeServer),
            ])

            let view = SearchResultsView(
                store: Store(
                    initialState: .init(
                        rows: rows,
                        searchText: "us",
                        isFree: false
                    )
                ) {
                    EmptyReducer()
                }
            )
            .background(Color(.background))
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        @Test("SearchResultsView Connected")
        func searchResultsViewConnected() {
            // The tunnel rests on US-NY#1 in New York, so its row, its city, and its country all read
            // as connected while the second New York server keeps offering to connect.
            @Shared(.connectionState) var connectionState
            $connectionState.withLock {
                $0 = .connected(to: .stub(id: "us-ny-1", exitCountryCode: "US", city: "New York"))
            }

            let country = SearchCountryIndex(id: "US", kind: .country(code: "US"), name: "United States")
            let city = SearchCityIndex(
                id: "new-york-US",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                countryCode: "US"
            )
            let connectedServer = SearchServerIndex(
                id: "us-ny-1",
                serverName: "US-NY#1",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                exitCountryCode: "US",
                entryCountryCode: nil,
                tier: .plus,
                load: 37,
                isP2PAvailable: true,
                isTorAvailable: false,
                isSmartAvailable: false,
                isStreamingAvailable: false,
                isUsersTierTooLow: false,
                underMaintenance: false
            )
            let otherServer = SearchServerIndex(
                id: "us-ny-2",
                serverName: "US-NY#2",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                exitCountryCode: "US",
                entryCountryCode: nil,
                tier: .plus,
                load: 67,
                isP2PAvailable: false,
                isTorAvailable: false,
                isSmartAvailable: false,
                isStreamingAvailable: false,
                isUsersTierTooLow: false,
                underMaintenance: false
            )
            let rows = IdentifiedArray(uniqueElements: [
                SearchResultRow.sectionHeader("Countries (1)"),
                SearchResultRow.country(country),
                SearchResultRow.sectionHeader("Cities (1)"),
                SearchResultRow.city(city),
                SearchResultRow.sectionHeader("Plus (2)"),
                SearchResultRow.server(connectedServer),
                SearchResultRow.server(otherServer),
            ])

            let view = SearchResultsView(
                store: Store(
                    initialState: .init(
                        rows: rows,
                        searchText: "us",
                        isFree: false
                    )
                ) {
                    EmptyReducer()
                }
            )
            .background(Color(.background))
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        @Test("SearchResultsView Gateway")
        func searchResultsViewGateway() {
            // The tunnel sits on a server inside DEV-VPN, so that gateway reads as connected while the
            // other one offers to connect. Gateways carry the gateway badge instead of a flag.
            @Shared(.connectionState) var connectionState
            $connectionState.withLock {
                $0 = .connected(to: .stub(id: "dev-1", exitCountryCode: "CH", gatewayName: "DEV-VPN"))
            }

            let connectedGateway = SearchCountryIndex(
                id: "gateway-DEV-VPN",
                kind: .gateway(name: "DEV-VPN"),
                name: "DEV-VPN"
            )
            let otherGateway = SearchCountryIndex(id: "gateway-CN", kind: .gateway(name: "CN"), name: "CN")
            let downGateway = SearchCountryIndex(
                id: "gateway-DE-STAGING",
                kind: .gateway(name: "DE-STAGING"),
                name: "DE-STAGING",
                underMaintenance: true
            )
            let switzerland = SearchCountryIndex(id: "CH", kind: .country(code: "CH"), name: "Switzerland")
            let rows = IdentifiedArray(uniqueElements: [
                SearchResultRow.sectionHeader("Countries (4)"),
                SearchResultRow.country(connectedGateway),
                SearchResultRow.country(otherGateway),
                SearchResultRow.country(downGateway),
                SearchResultRow.country(switzerland),
            ])

            let view = SearchResultsView(
                store: Store(
                    initialState: .init(
                        rows: rows,
                        searchText: "c",
                        isFree: false
                    )
                ) {
                    EmptyReducer()
                }
            )
            .background(Color(.background))
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        @Test("SearchResultsView Under Maintenance")
        func searchResultsViewUnderMaintenance() {
            @Shared(.connectionState) var connectionState
            $connectionState.withLock { $0 = .disconnected }

            let country = SearchCountryIndex(
                id: "US",
                kind: .country(code: "US"),
                name: "United States",
                underMaintenance: true
            )
            let city = SearchCityIndex(
                id: "new-york-US",
                cityName: "New York",
                translatedCityName: nil,
                countryName: "United States",
                countryCode: "US",
                underMaintenance: true
            )
            let stateItem = SearchCityIndex(
                id: "california-US",
                cityName: "California",
                translatedCityName: nil,
                countryName: "United States",
                countryCode: "US",
                underMaintenance: true
            )
            let workingCity = SearchCityIndex(
                id: "los-angeles-US",
                cityName: "Los Angeles",
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
                tier: .plus,
                load: 37,
                isP2PAvailable: false,
                isTorAvailable: false,
                isSmartAvailable: false,
                isStreamingAvailable: false,
                isUsersTierTooLow: false,
                underMaintenance: true
            )
            let rows = IdentifiedArray(uniqueElements: [
                SearchResultRow.sectionHeader("Countries (1)"),
                SearchResultRow.country(country),
                SearchResultRow.sectionHeader("Cities (2)"),
                SearchResultRow.city(city),
                SearchResultRow.city(workingCity),
                SearchResultRow.sectionHeader("States (1)"),
                SearchResultRow.state(stateItem),
                SearchResultRow.sectionHeader("Plus (1)"),
                SearchResultRow.server(server),
            ])

            let view = SearchResultsView(
                store: Store(
                    initialState: .init(
                        rows: rows,
                        searchText: "us",
                        isFree: false
                    )
                ) {
                    EmptyReducer()
                }
            )
            .background(Color(.background))
            .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        @Test("SearchResultsView Secure Core Connected")
        func searchResultsViewSecureCoreConnected() {
            // The app picked CH#2 out of the Sweden hop. The row for CH#1 stands for that same hop, so
            // it reads as connected, while the Iceland hop below it does not.
            @Shared(.connectionState) var connectionState
            $connectionState.withLock {
                $0 = .connected(to: .stub(id: "ch-2", exitCountryCode: "CH", entryCountryCode: "SE"))
            }

            let sameHop = SearchServerIndex(
                id: "ch-1",
                serverName: "CH#1",
                cityName: "Zurich",
                translatedCityName: nil,
                countryName: "Switzerland",
                exitCountryCode: "CH",
                entryCountryCode: "SE",
                tier: .plus,
                load: 12,
                isP2PAvailable: false,
                isTorAvailable: false,
                isSmartAvailable: false,
                isStreamingAvailable: false,
                isUsersTierTooLow: false,
                underMaintenance: false
            )
            let otherHop = SearchServerIndex(
                id: "ch-3",
                serverName: "CH#3",
                cityName: "Zurich",
                translatedCityName: nil,
                countryName: "Switzerland",
                exitCountryCode: "CH",
                entryCountryCode: "IS",
                tier: .plus,
                load: 30,
                isP2PAvailable: false,
                isTorAvailable: false,
                isSmartAvailable: false,
                isStreamingAvailable: false,
                isUsersTierTooLow: false,
                underMaintenance: false
            )
            let rows = IdentifiedArray(uniqueElements: [
                SearchResultRow.sectionHeader("Secure Core countries (2)"),
                SearchResultRow.secureCoreCountry(sameHop),
                SearchResultRow.secureCoreCountry(otherHop),
            ])

            let view = SearchResultsView(
                store: Store(
                    initialState: .init(
                        rows: rows,
                        searchText: "sw",
                        isFree: false
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
