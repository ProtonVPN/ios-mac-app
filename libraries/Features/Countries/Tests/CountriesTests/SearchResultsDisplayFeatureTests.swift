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
import Connection
@testable import CountriesShared
import Domain
import DomainTestSupport
import Testing

@Suite("SearchResultsDisplayFeature Tests")
@MainActor
struct SearchResultsDisplayFeatureReducerTests {
    @Test("free tier taps route to upsell delegates")
    func freeTierTapActionsEmitUpsellDelegates() async {
        let country = SearchCountryIndex(id: "GB", kind: .country(code: "GB"), name: "United Kingdom")
        let city = SearchCityIndex(
            id: "london-gb",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            countryCode: "GB"
        )
        let stateItem = SearchCityIndex(
            id: "california-us",
            cityName: "California",
            translatedCityName: nil,
            countryName: "United States",
            countryCode: "US"
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
            rows: [.country(country), .city(city), .state(stateItem), .server(server)],
            searchText: "uk",
            isFree: true
        )
        let store = TestStore(initialState: initialState) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countrySelected(country))
        await store.receive(\.delegate.showCountryUpsell, "GB")

        await store.send(.citySelected(city))
        await store.receive(\.delegate.showCountryUpsell, "GB")

        await store.send(.stateSelected(stateItem))
        await store.receive(\.delegate.showCountryUpsell, "US")

        // Free-tier + .free server that isn't flagged `isUsersTierTooLow`
        // routes to a connect request, not an upsell.
        await store.send(.serverSelected(server))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(
                    location: .exact(.free, logicalID: "gb-1", number: nil, subregion: "London", regionCode: "GB"),
                    features: []
                ),
                .searchServer
            ))
        )

        // A server the user can't access (isUsersTierTooLow == true) routes to upsell.
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
        await store.receive(\.delegate.showCountryUpsell, "GB")
    }

    @Test("paid tier supports country navigation and connect actions")
    func paidTierActionsEmitNavigationAndConnectDelegates() async {
        let country = SearchCountryIndex(id: "GB", kind: .country(code: "GB"), name: "United Kingdom")
        let city = SearchCityIndex(
            id: "london-gb",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            countryCode: "GB"
        )
        let stateItem = SearchCityIndex(
            id: "california-us",
            cityName: "California",
            translatedCityName: nil,
            countryName: "United States",
            countryCode: "US"
        )
        let server = SearchServerIndex(
            id: "gb-1",
            serverName: "UK#1",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            exitCountryCode: "GB",
            entryCountryCode: nil,
            tier: .plus,
            load: 50,
            isP2PAvailable: false,
            isTorAvailable: false,
            isSmartAvailable: false,
            isStreamingAvailable: false,
            isUsersTierTooLow: false,
            underMaintenance: false
        )
        let store = TestStore(
            initialState: .init(rows: [.country(country), .city(city), .state(stateItem), .server(server)], searchText: "uk", isFree: false)
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countrySelected(country))
        await store.receive(.delegate(.navigateTo(.country(code: "GB"))))

        await store.send(.countryConnectTapped(country))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .country(code: "GB", order: .fastest), features: []),
                .searchCountry
            ))
        )

        await store.send(.citySelected(city))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .city(name: "London", code: "GB", order: .fastest), features: []),
                .searchCity
            ))
        )

        await store.send(.stateSelected(stateItem))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .state(name: "California", code: "US", order: .fastest), features: []),
                .searchState
            ))
        )

        await store.send(.serverSelected(server))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(
                    location: .exact(.paid, logicalID: "gb-1", number: nil, subregion: "London", regionCode: "GB"),
                    features: []
                ),
                .searchServer
            ))
        )
    }

    @Test("secure core results connect through a secure core hop")
    func secureCoreServerConnectsThroughHop() async {
        let server = SearchServerIndex(
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
        let store = TestStore(
            initialState: .init(rows: [.secureCoreCountry(server)], searchText: "sw", isFree: false)
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.serverSelected(server))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .secureCore(.hop(to: "CH", via: "SE")), features: []),
                .searchServer
            ))
        )
    }

    @Test("connect button on a connected row disconnects")
    func connectedRowsRequestDisconnect() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connected(to: .stub(id: "gb-1", exitCountryCode: "GB", city: "London", state: "England"))
        }

        let country = SearchCountryIndex(id: "GB", kind: .country(code: "GB"), name: "United Kingdom")
        let city = SearchCityIndex(
            id: "london-gb",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            countryCode: "GB"
        )
        let stateItem = SearchCityIndex(
            id: "england-gb",
            cityName: "England",
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
            tier: .plus,
            load: 50,
            isP2PAvailable: false,
            isTorAvailable: false,
            isSmartAvailable: false,
            isStreamingAvailable: false,
            isUsersTierTooLow: false,
            underMaintenance: false
        )
        let store = TestStore(
            initialState: .init(
                rows: [.country(country), .city(city), .state(stateItem), .server(server)],
                searchText: "uk",
                isFree: false
            )
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(country))
        await store.receive(.delegate(.disconnectRequested(.searchCountry)))

        await store.send(.citySelected(city))
        await store.receive(.delegate(.disconnectRequested(.searchCity)))

        await store.send(.stateSelected(stateItem))
        await store.receive(.delegate(.disconnectRequested(.searchState)))

        await store.send(.serverSelected(server))
        await store.receive(.delegate(.disconnectRequested(.searchServer)))
    }

    @Test("connect action on a not connected row connects")
    func rowsAwayFromTheTunnelStillConnect() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connected(to: .stub(id: "gb-1", exitCountryCode: "GB", city: "London", state: "England"))
        }

        let otherCity = SearchCityIndex(
            id: "manchester-gb",
            cityName: "Manchester",
            translatedCityName: nil,
            countryName: "United Kingdom",
            countryCode: "GB"
        )
        let otherServer = SearchServerIndex(
            id: "gb-2",
            serverName: "UK#2",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            exitCountryCode: "GB",
            entryCountryCode: nil,
            tier: .plus,
            load: 50,
            isP2PAvailable: false,
            isTorAvailable: false,
            isSmartAvailable: false,
            isStreamingAvailable: false,
            isUsersTierTooLow: false,
            underMaintenance: false
        )
        let store = TestStore(
            initialState: .init(rows: [.city(otherCity), .server(otherServer)], searchText: "uk", isFree: false)
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.citySelected(otherCity))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .city(name: "Manchester", code: "GB", order: .fastest), features: []),
                .searchCity
            ))
        )

        // A second server in the connected city is still a connect: only that one logical is in use.
        await store.send(.serverSelected(otherServer))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(
                    location: .exact(.paid, logicalID: "gb-2", number: nil, subregion: nil, regionCode: "GB"),
                    features: []
                ),
                .searchServer
            ))
        )
    }

    @Test("a Secure Core row counts as connected for any server on its hop")
    func secureCoreRowsMatchTheirHop() async {
        // The app picked CH#2 out of the Sweden hop, so every row for that hop reads as connected.
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
        let country = SearchCountryIndex(id: "CH", kind: .country(code: "CH"), name: "Switzerland")
        let store = TestStore(
            initialState: .init(
                rows: [.secureCoreCountry(sameHop), .secureCoreCountry(otherHop), .country(country)],
                searchText: "sw",
                isFree: false
            )
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.serverSelected(sameHop))
        await store.receive(.delegate(.disconnectRequested(.searchServer)))

        // Same exit country, different entry country: a different hop, so still a connect.
        await store.send(.serverSelected(otherHop))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .secureCore(.hop(to: "CH", via: "IS")), features: []),
                .searchServer
            ))
        )

        // A plain country row stands for standard servers, so a Secure Core tunnel leaves it alone.
        await store.send(.countryConnectTapped(country))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .country(code: "CH", order: .fastest), features: []),
                .searchCountry
            ))
        )
    }

    @Test("a gateway row connects to the gateway rather than to a country")
    func gatewayRowConnectsToTheGateway() async {
        let gateway = SearchCountryIndex(id: "gateway-DEV-VPN", kind: .gateway(name: "DEV-VPN"), name: "DEV-VPN")
        let store = TestStore(initialState: .init(rows: [.country(gateway)], searchText: "dev", isFree: false)) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(gateway))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .gateway(name: "DEV-VPN"), features: []),
                .searchCountry
            ))
        )

        // Opening it carries the gateway's name, so the countries list can tell one gateway from another.
        await store.send(.countrySelected(gateway))
        await store.receive(.delegate(.navigateTo(.gateway(name: "DEV-VPN"))))
    }

    @Test("a gateway row reads as connected if connected to one of its servers")
    func gatewayRowFollowsItsServers() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connected(to: .stub(id: "dev-1", exitCountryCode: "CH", gatewayName: "DEV-VPN"))
        }

        let gateway = SearchCountryIndex(id: "gateway-DEV-VPN", kind: .gateway(name: "DEV-VPN"), name: "DEV-VPN")
        let otherGateway = SearchCountryIndex(id: "gateway-CN", kind: .gateway(name: "CN"), name: "CN")
        // The tunnel exits Switzerland, but through a gateway, so the plain country row stays out of it.
        let country = SearchCountryIndex(id: "CH", kind: .country(code: "CH"), name: "Switzerland")
        let store = TestStore(
            initialState: .init(
                rows: [.country(gateway), .country(otherGateway), .country(country)],
                searchText: "c",
                isFree: false
            )
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(gateway))
        await store.receive(.delegate(.disconnectRequested(.searchCountry)))

        await store.send(.countryConnectTapped(otherGateway))
        await store.receive(
            .delegate(.connectRequested(ConnectionSpec(location: .gateway(name: "CN"), features: []), .searchCountry))
        )

        await store.send(.countryConnectTapped(country))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .country(code: "CH", order: .fastest), features: []),
                .searchCountry
            ))
        )
    }

    @Test("a free user is never upsold a gateway")
    func gatewayRowIsNeverUpsold() async {
        let gateway = SearchCountryIndex(id: "gateway-DEV-VPN", kind: .gateway(name: "DEV-VPN"), name: "DEV-VPN")
        let store = TestStore(initialState: .init(rows: [.country(gateway)], searchText: "dev", isFree: true)) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(gateway))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .gateway(name: "DEV-VPN"), features: []),
                .searchCountry
            ))
        )
    }

    @Test("a gateway with every server down says so")
    func gatewayUnderMaintenanceRaisesItsOwnAlert() async {
        let gateway = SearchCountryIndex(
            id: "gateway-DEV-VPN",
            kind: .gateway(name: "DEV-VPN"),
            name: "DEV-VPN",
            underMaintenance: true
        )
        let store = TestStore(initialState: .init(rows: [.country(gateway)], searchText: "dev", isFree: false)) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(gateway))
        await store.receive(.delegate(.showMaintenanceAlert(.gateway)))
    }

    @Test("a pending request matches its row however it was spelled")
    func pendingRequestMatchesItsRowStructurally() {
        // Asking for a random server in the country is still asking for the country, and a request
        // raised from the servers list carries the number and subregion this row leaves out.
        let country = SearchCountryIndex(id: "GB", kind: .country(code: "GB"), name: "United Kingdom")
        let server = SearchServerIndex(
            id: "gb-1",
            serverName: "UK#1",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            exitCountryCode: "GB",
            entryCountryCode: nil,
            tier: .plus,
            load: 50,
            isP2PAvailable: false,
            isTorAvailable: false,
            isSmartAvailable: false,
            isStreamingAvailable: false,
            isUsersTierTooLow: false,
            underMaintenance: false
        )
        let state = SearchResultsDisplayFeature.State(
            rows: [.country(country), .server(server)],
            searchText: "uk",
            isFree: false
        )

        @Shared(.connectionState) var connectionState

        $connectionState.withLock { $0 = .connecting(to: .country(code: "GB", order: .random)) }
        #expect(state.isCurrentlyConnected(.country(country)))

        $connectionState.withLock {
            $0 = .connecting(to: .exact(.free, logicalID: "gb-1", number: 1, subregion: "London", regionCode: "GB"))
        }
        #expect(state.isCurrentlyConnected(.server(server)))

        // A request for a different server in the same country leaves both rows alone.
        $connectionState.withLock {
            $0 = .connecting(to: .exact(.paid, logicalID: "gb-2", number: 2, subregion: "London", regionCode: "GB"))
        }
        #expect(!state.isCurrentlyConnected(.server(server)))
        #expect(!state.isCurrentlyConnected(.country(country)))
    }

    @Test("a pending Secure Core hop matches its row")
    func pendingSecureCoreHopMatchesItsRow() {
        let hop = SearchServerIndex(
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
        let state = SearchResultsDisplayFeature.State(rows: [.secureCoreCountry(hop)], searchText: "sw", isFree: false)

        @Shared(.connectionState) var connectionState

        $connectionState.withLock { $0 = .connecting(to: .secureCore(.hop(to: "CH", via: "SE"))) }
        #expect(state.isCurrentlyConnected(.secureCoreCountry(hop)))

        $connectionState.withLock { $0 = .connecting(to: .secureCore(.hop(to: "CH", via: "IS"))) }
        #expect(!state.isCurrentlyConnected(.secureCoreCountry(hop)))
    }

    @Test("the connected row when kill switch is on can disconnect")
    func killSwitchRowStillDisconnects() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .killSwitchActive(
                ConnectionSpec(location: .country(code: "GB", order: .fastest), features: []),
                .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: [], killSwitch: true)
            )
        }

        let country = SearchCountryIndex(id: "GB", kind: .country(code: "GB"), name: "United Kingdom")
        let elsewhere = SearchCountryIndex(id: "CH", kind: .country(code: "CH"), name: "Switzerland")
        let store = TestStore(
            initialState: .init(rows: [.country(country), .country(elsewhere)], searchText: "u", isFree: false)
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(country))
        await store.receive(.delegate(.disconnectRequested(.searchCountry)))

        await store.send(.countryConnectTapped(elsewhere))
        await store.receive(
            .delegate(.connectRequested(
                ConnectionSpec(location: .country(code: "CH", order: .fastest), features: []),
                .searchCountry
            ))
        )
    }

    @Test("a place that goes into maintenance under a live tunnel can still be left")
    func maintenanceUnderALiveTunnelStillDisconnects() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connected(to: .stub(id: "gb-1", exitCountryCode: "GB", city: "London", state: "England"))
        }

        // Every server here has since gone down, but the tunnel is still up on one of them.
        let country = SearchCountryIndex(
            id: "GB",
            kind: .country(code: "GB"),
            name: "United Kingdom",
            underMaintenance: true
        )
        let city = SearchCityIndex(
            id: "london-gb",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            countryCode: "GB",
            underMaintenance: true
        )
        let server = SearchServerIndex(
            id: "gb-1",
            serverName: "UK#1",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            exitCountryCode: "GB",
            entryCountryCode: nil,
            tier: .plus,
            load: 50,
            isP2PAvailable: false,
            isTorAvailable: false,
            isSmartAvailable: false,
            isStreamingAvailable: false,
            isUsersTierTooLow: false,
            underMaintenance: true
        )
        let store = TestStore(
            initialState: .init(
                rows: [.country(country), .city(city), .server(server)],
                searchText: "uk",
                isFree: false
            )
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(country))
        await store.receive(.delegate(.disconnectRequested(.searchCountry)))

        await store.send(.citySelected(city))
        await store.receive(.delegate(.disconnectRequested(.searchCity)))

        await store.send(.serverSelected(server))
        await store.receive(.delegate(.disconnectRequested(.searchServer)))
    }

    @Test("rows under maintenance raise an alert instead of connecting")
    func maintenanceRowsRaiseAnAlert() async {
        let country = SearchCountryIndex(id: "GB", kind: .country(code: "GB"), name: "United Kingdom", underMaintenance: true)
        let city = SearchCityIndex(
            id: "london-gb",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            countryCode: "GB",
            underMaintenance: true
        )
        let stateItem = SearchCityIndex(
            id: "england-gb",
            cityName: "England",
            translatedCityName: nil,
            countryName: "United Kingdom",
            countryCode: "GB",
            underMaintenance: true
        )
        let server = SearchServerIndex(
            id: "gb-1",
            serverName: "UK#1",
            cityName: "London",
            translatedCityName: nil,
            countryName: "United Kingdom",
            exitCountryCode: "GB",
            entryCountryCode: nil,
            tier: .plus,
            load: 50,
            isP2PAvailable: false,
            isTorAvailable: false,
            isSmartAvailable: false,
            isStreamingAvailable: false,
            isUsersTierTooLow: false,
            underMaintenance: true
        )
        let store = TestStore(
            initialState: .init(
                rows: [.country(country), .city(city), .state(stateItem), .server(server)],
                searchText: "uk",
                isFree: false
            )
        ) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(country))
        await store.receive(.delegate(.showMaintenanceAlert(.country)))

        await store.send(.citySelected(city))
        await store.receive(.delegate(.showMaintenanceAlert(.city)))

        await store.send(.stateSelected(stateItem))
        await store.receive(.delegate(.showMaintenanceAlert(.state)))

        await store.send(.serverSelected(server))
        await store.receive(.delegate(.showMaintenanceAlert(.server)))

        // Opening the country's own list still works: individual servers in it may be fine.
        await store.send(.countrySelected(country))
        await store.receive(.delegate(.navigateTo(.country(code: "GB"))))
    }

    @Test("a row the app is still resolving reads as connected")
    func rowBeingConnectedToReadsAsConnected() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connecting(to: .country(code: "GB", order: .fastest))
        }

        let country = SearchCountryIndex(id: "GB", kind: .country(code: "GB"), name: "United Kingdom")
        let store = TestStore(initialState: .init(rows: [.country(country)], searchText: "uk", isFree: false)) {
            SearchResultsDisplayFeature()
        }

        await store.send(.countryConnectTapped(country))
        await store.receive(.delegate(.disconnectRequested(.searchCountry)))
    }
}
