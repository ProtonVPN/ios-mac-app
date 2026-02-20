//
//  Created on 22/01/2026 by Max Kupetskyi.
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
import PersistenceTestSupport
import Testing

@Suite("Countries Main Feature Tests")
@MainActor
struct CountriesMainFeatureTests {
    // MARK: - onAppear Tests

    @Test("onAppear sets loading state and reloads content")
    func onAppearSetsLoadingStateAndReloadsContent() async {
        let store = TestStore(initialState: .loading) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .mockWithUSServers()
        }

        // Use exhaustivity off since we're dealing with notification observations
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0 = .loading
        }

        await store.receive(\.reloadContent)
    }

    @Test("Reload content with standard server type")
    func reloadContentWithStandardServerType() async {
        let mockSections = IdentifiedArrayOf<CountrySectionFeature.State>()

        let store = TestStore(initialState: .loading) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }

        await store.send(.reloadContent)
        await store.receive(\.contentReloaded) {
            $0 = .standard(.init(sections: mockSections))
        }
    }

    @Test("Reload content with secure core server type")
    func reloadContentWithSecureCoreServerType() async {
        @Shared(.secureCoreToggle) var isSecureCore = true
        let mockSections = IdentifiedArrayOf<CountrySectionFeature.State>()

        let store = TestStore(initialState: .loading) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }

        await store.send(.reloadContent)
        await store.receive(\.contentReloaded) {
            $0 = .secureCore(.init(sections: mockSections))
        }
    }

    @Test("Reload content with P2P server type maps to standard")
    func reloadContentWithP2PServerType() async {
        let mockSections = IdentifiedArrayOf<CountrySectionFeature.State>()

        let store = TestStore(initialState: .loading) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }

        await store.send(.contentReloaded(.p2p, mockSections)) {
            $0 = .standard(.init(sections: mockSections))
        }
    }

    @Test("Reload content with Tor server type maps to standard")
    func reloadContentWithTorServerType() async {
        let mockSections = IdentifiedArrayOf<CountrySectionFeature.State>()

        let store = TestStore(initialState: .loading) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }

        await store.send(.contentReloaded(.tor, mockSections)) {
            $0 = .standard(.init(sections: mockSections))
        }
    }

    // MARK: - Plan Change Update Tests

    @Test("Plan changed triggers reload content")
    func planChagedTriggersReloadContent() async {
        let store = TestStore(initialState: .loading) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }

        await store.send(.planChanged)
        await store.receive(\.reloadContent)
        await store.receive(\.contentReloaded) {
            $0 = .standard(.init(sections: []))
        }
    }

    // MARK: - Secure Core Toggle Tests

    @Test("Apply secure core toggle from standard state")
    func applySecureCoreToggleFromStandard() async {
        @Shared(.secureCoreToggle) var isSecureCore = false
        let initialState = CountriesMainFeature.State.standard(.init(sections: []))

        let store = TestStore(initialState: initialState) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }

        await store.send(.standard(.applySecureCoreToggle)) {
            guard case var .standard(state) = $0 else {
                Issue.record("Expected standard state")
                return
            }
            state.$isSecureCore.withLock { $0 = true }
            $0 = .standard(state)
        }
        await store.receive(\.reloadContent) {
            $0 = .loading
        }
        await store.receive(\.contentReloaded) {
            $0 = .secureCore(.init(sections: []))
        }
    }

    @Test("Apply secure core toggle from secure core state")
    func applySecureCoreToggleFromSecureCore() async {
        @Shared(.secureCoreToggle) var isSecureCore = true
        let initialState = CountriesMainFeature.State.secureCore(.init(sections: []))

        let store = TestStore(initialState: initialState) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .empty()
        }

        await store.send(.secureCore(.applySecureCoreToggle)) {
            guard case var .secureCore(state) = $0 else {
                Issue.record("Expected secure core state")
                return
            }
            state.$isSecureCore.withLock { $0 = false }
            $0 = .secureCore(state)
        }
        await store.receive(\.reloadContent) {
            $0 = .loading
        }
        await store.receive(\.contentReloaded) {
            $0 = .standard(.init(sections: []))
        }
    }

    // MARK: - State Enum Tests

    @Test("Loading state is correctly identified")
    func loadingState() {
        let state: CountriesMainFeature.State = .loading
        switch state {
        case .loading:
            #expect(true)
        default:
            Issue.record("Expected loading state")
        }
    }

    @Test("Standard state contains correct inner state")
    func standardState() {
        let countriesState = CountriesFeature.State(sections: [])
        let state: CountriesMainFeature.State = .standard(countriesState)

        switch state {
        case let .standard(innerState):
            #expect(innerState.sections.isEmpty)
        default:
            Issue.record("Expected standard state")
        }
    }

    @Test("Secure core state contains correct inner state")
    func secureCoreState() {
        let countriesState = CountriesFeature.State(sections: [])
        let state: CountriesMainFeature.State = .secureCore(countriesState)

        switch state {
        case let .secureCore(innerState):
            #expect(innerState.sections.isEmpty)
        default:
            Issue.record("Expected secureCore state")
        }
    }

    // MARK: - Child Feature Action Forwarding Tests

    @Test("Standard feature action passes through")
    func standardFeatureActionPassthrough() async {
        let initialState = CountriesMainFeature.State.standard(.init(sections: []))

        let store = TestStore(initialState: initialState) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .mockWithUSServers()
        }

        await store.send(.standard(.showSearch)) {
            guard case var .standard(state) = $0 else {
                Issue.record("Expected standard state")
                return
            }
            state.path.append(.search(.loading([])))
            $0 = .standard(state)
        }
    }

    @Test("Secure core feature action passes through")
    func secureCoreFeatureActionPassthrough() async {
        let initialState = CountriesMainFeature.State.secureCore(.init(sections: []))

        let store = TestStore(initialState: initialState) {
            CountriesMainFeature()
        } withDependencies: {
            $0.serverRepository = .mockWithUSServers()
        }

        await store.send(.secureCore(.showSearch)) {
            guard case var .secureCore(state) = $0 else {
                Issue.record("Expected secure core state")
                return
            }
            state.path.append(.search(.loading([])))
            $0 = .secureCore(state)
        }
    }
}
