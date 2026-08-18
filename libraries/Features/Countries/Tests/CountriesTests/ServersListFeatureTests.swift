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

@Suite("Servers List Feature Tests")
@MainActor
struct ServersListFeatureTests {
    // MARK: - onAppear Tests

    @Test("onAppear sets loading state and reloads content")
    func onAppearSetsLoadingStateAndReloadsContent() async {
        let store = TestStore(initialState: .init(countryCode: "US", listType: .state("California"))) {
            ServersListFeature()
        } withDependencies: {
            $0.serverRepository = .mockWithUSStates()
        }

        store.exhaustivity = .off

        await store.send(.didAppear)

        await store.receive(\.loaded) { state in
            if case let .loaded(servers) = state.list {
                #expect(servers.count == 8)
            }
        }
    }

    // MARK: - Connected Row Tests

    @Test("a server row shows as connected if connected")
    func serverRowFollowsTheConnectedServer() {
        // Reached by tapping California, which landed the user on US-CA#5 rather than on US-CA#6.
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connected(to: .stub(id: "us-ca-5", exitCountryCode: "US", city: "Los Angeles", state: "California"))
        }

        let state = ServersListFeature.State(countryCode: "US", listType: .state("California"))

        #expect(state.isCurrentlyConnected(to: .stub(logical: .stub(id: "us-ca-5", exitCountryCode: "US"))))
        #expect(!state.isCurrentlyConnected(to: .stub(logical: .stub(id: "us-ca-6", exitCountryCode: "US"))))
    }

    @Test("a server row shows as connected for connecting state")
    func serverRowFollowsTheRequestBeforeTheServerIsPicked() {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connecting(to: .exact(
                .paid,
                logicalID: "us-ca-5",
                number: 5,
                subregion: "California",
                regionCode: "US"
            ))
        }

        let state = ServersListFeature.State(countryCode: "US", listType: .state("California"))

        #expect(state.isCurrentlyConnected(to: .stub(logical: .stub(id: "us-ca-5", exitCountryCode: "US"))))
        #expect(!state.isCurrentlyConnected(to: .stub(logical: .stub(id: "us-ca-6", exitCountryCode: "US"))))
    }

    @Test("no server row shows as connected once the connection is down")
    func noServerRowIsConnectedWhileDisconnected() {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }

        let state = ServersListFeature.State(countryCode: "US", listType: .state("California"))

        #expect(!state.isCurrentlyConnected(to: .stub(logical: .stub(id: "us-ca-5", exitCountryCode: "US"))))
    }
}
