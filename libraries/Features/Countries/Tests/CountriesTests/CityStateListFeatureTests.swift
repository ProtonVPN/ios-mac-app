//
//  Created on 2026-02-03 by Pawel Jurczyk.
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
import Domain
import DomainTestSupport
import PersistenceTestSupport
import Testing

@Suite("City State List Feature Tests")
@MainActor
struct CityStateListFeatureTests {
    // MARK: - onAppear Tests

    @Test("onAppear sets loading state and reloads content")
    func onAppearSetsLoadingStateAndReloadsContent() async {
        let store = TestStore(initialState: .init(countryCode: "US")) {
            CityStateListFeature()
        } withDependencies: {
            $0.serverRepository = .mockWithUSStates()
        }

        store.exhaustivity = .off

        await store.send(.didAppear)

        await store.receive(\.loaded) {
            $0.sectionTitle = "States (3)"
//            $0.listState = .loaded(.states([]))
        }
    }

    // MARK: - Connected Row Tests

    @Test("a state row reads as connected for any server inside it")
    func stateRowFollowsTheServerTheTunnelIsOn() {
        // Reached by picking one server out of California, rather than by tapping California itself.
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connected(to: .stub(id: "us-ca-5", exitCountryCode: "US", city: "Los Angeles", state: "California"))
        }

        let state = CityStateListFeature.State(countryCode: "US")

        #expect(state.isCurrentlyConnected(to: .stub(kind: .state(name: "California", code: "US"))))
        #expect(state.isCurrentlyConnected(to: .stub(kind: .city(name: "Los Angeles", code: "US"))))
        #expect(!state.isCurrentlyConnected(to: .stub(kind: .state(name: "New York", code: "US"))))
        #expect(!state.isCurrentlyConnected(to: .stub(kind: .city(name: "San Jose", code: "US"))))
        // Same state name, different country.
        #expect(!state.isCurrentlyConnected(to: .stub(kind: .state(name: "California", code: "CA"))))
    }

    @Test("a state row reads as connected while the app is still picking its server")
    func stateRowFollowsTheRequestBeforeTheServerIsPicked() {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connecting(to: .state(name: "California", code: "US", order: .fastest))
        }

        let state = CityStateListFeature.State(countryCode: "US")

        #expect(state.isCurrentlyConnected(to: .stub(kind: .state(name: "California", code: "US"))))
        #expect(!state.isCurrentlyConnected(to: .stub(kind: .state(name: "New York", code: "US"))))
    }

    @Test("with the kill switch row still renders as connected")
    func killSwitchRowReadsAsConnected() {
        // No server is carrying traffic, so the spec the kill switch holds is what names the place.
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .killSwitchActive(
                ConnectionSpec(location: .state(name: "California", code: "US", order: .fastest), features: []),
                .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: [], killSwitch: true)
            )
        }

        let state = CityStateListFeature.State(countryCode: "US")

        #expect(state.isCurrentlyConnected(to: .stub(kind: .state(name: "California", code: "US"))))
        #expect(!state.isCurrentlyConnected(to: .stub(kind: .state(name: "New York", code: "US"))))
    }

    @Test("no row reads as connected once the tunnel is down")
    func noRowIsConnectedWhileDisconnected() {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }

        let state = CityStateListFeature.State(countryCode: "US")

        #expect(!state.isCurrentlyConnected(to: .stub(kind: .state(name: "California", code: "US"))))
    }

    @Test("a Secure Core tunnel leaves the standard city and state rows alone")
    func secureCoreTunnelLeavesStandardRowsAlone() {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connected(to: .stub(
                id: "us-sc-1",
                exitCountryCode: "US",
                entryCountryCode: "CH",
                city: "Los Angeles",
                state: "California"
            ))
        }

        let state = CityStateListFeature.State(countryCode: "US")

        // These lists only ever offer standard servers, so none of their rows stands for this tunnel.
        #expect(!state.isCurrentlyConnected(to: .stub(kind: .state(name: "California", code: "US"))))
        #expect(!state.isCurrentlyConnected(to: .stub(kind: .city(name: "Los Angeles", code: "US"))))
    }
}
