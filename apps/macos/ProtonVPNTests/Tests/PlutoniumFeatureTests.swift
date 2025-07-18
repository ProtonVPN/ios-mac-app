//
//  Created on 2025-05-30 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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

import Testing

import ComposableArchitecture

@testable import ProtonVPN
@testable import VPNAppCore

@MainActor
struct PlutoniumFeatureTests {
    @Test
    func onAppear() async {
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        }
        #expect(store.state.requiresReconnection == false)

        await store.send(.onAppear) {
            $0.discoveredApps = [.huzza]
        }

        await store.send(.toggleModeClicked)
        await store.receive(\.toggleModeConfirmed) {
            $0.$feature.withLock {
                $0 = .enabled(.exclusion)
            }
        }
    }

    @Test
    func toggleModeConflict() async {
        @Shared(.killSwitch) var killSwitch = true
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        }

        await store.send(.toggleModeClicked) {
            $0.alert = PlutoniumFeature.confirmAlert
        }
        await store.send(.alert(.presented(.toggleModeConfirmed))) {
            $0.alert = nil
            $0.$feature.withLock {
                $0 = .enabled(.exclusion)
            }
        }
        await store.receive(\.toggleModeConfirmed)
    }

    @Test
    func toggleMode() async {
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        }
        #expect(store.state.requiresReconnection == false)

        await store.send(.toggleModeClicked)
        await store.receive(\.toggleModeConfirmed) {
            $0.$feature.withLock {
                $0 = .enabled(.exclusion)
            }
        }
        #expect(store.state.requiresReconnection == true)

        await store.send(.modeSelectionClicked(.inclusion)) {
            $0.$feature.withLock {
                $0 = .enabled(.inclusion)
            }
        }
        #expect(store.state.requiresReconnection == true)

        await store.send(.toggleModeClicked) {
            $0.$feature.withLock {
                $0 = .disabled(.inclusion)
            }
        }
        await store.receive(\.toggleModeConfirmed)
        #expect(store.state.requiresReconnection == false)
    }

    @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
    @Shared(.inclusionActivated) var inclusionActivated: PlutoniumActivated
    @Shared(.exclusionActivated) var exclusionActivated: PlutoniumActivated

    @Shared(.plutoniumFeatureApplied) var featureApplied: PlutoniumFeatureToggle
    @Shared(.inclusionActivatedApplied) var inclusionActivatedApplied: PlutoniumActivated
    @Shared(.exclusionActivatedApplied) var exclusionActivatedApplied: PlutoniumActivated

    @Test
    func requiresReconnectionAfterDisabling() async {
        $featureApplied.withLock { $0 = .enabled(.exclusion) }
        $feature.withLock { $0 = .enabled(.exclusion) }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        }
        #expect(store.state.requiresReconnection == false)
        await store.send(.toggleModeClicked) {
            $0.$feature.withLock {
                $0 = .disabled(.exclusion)
            }
        }
        await store.receive(\.toggleModeConfirmed)
        #expect(store.state.requiresReconnection == true)
    }

    @Test
    func requiresReconnectionIPsExclusionList() async {
        // initial state of feature
        $feature.withLock { $0 = .enabled(.exclusion) }
        $featureApplied.withLock { $0 = .enabled(.exclusion) }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        }
        #expect(store.state.requiresReconnection == false)
        // modify the activated list
        await store.send(.entryClicked(.ip("1.1.1.1"), .add, .exclusion)) {
            $0.$exclusionActivated.withLock { $0.ips = ["1.1.1.1"] }
        }
        await store.receive(\.inputFieldChanged)
        #expect(store.state.requiresReconnection == true)
        // modify the activated applied list in the same way
        $exclusionActivatedApplied.withLock {
            $0.ips = ["1.1.1.1"]
        }
        #expect(store.state.requiresReconnection == false)
    }

    @Test
    func requiresReconnectionAppsInclusionList() async {
        // initial state of feature
        $feature.withLock { $0 = .enabled(.inclusion) }
        $featureApplied.withLock { $0 = .enabled(.inclusion) }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        }
        #expect(store.state.requiresReconnection == false)
        // modify the activated list
        await store.send(.entryClicked(.app(.huzza), .add, .inclusion)) {
            $0.$inclusionActivated.withLock { $0.apps = [.huzza] }
        }
        #expect(store.state.requiresReconnection == true)
        // modify the activated applied list in the same way
        $inclusionActivatedApplied.withLock {
            $0.apps = [.huzza]
        }
        #expect(store.state.requiresReconnection == false)
    }

    @Test
    func modifyIPsList() async {
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        }
        await store.send(.entryClicked(.ip("1.1.1.1"), .add, .exclusion)) {
            $0.$exclusionActivated.withLock { $0.ips = ["1.1.1.1"] }
        }
        await store.receive(\.inputFieldChanged)
        await store.send(.entryClicked(.ip("1.1.1.1"), .add, .exclusion)) {
            $0.validationError = .alreadyExists
        }
        await store.send(.entryClicked(.ip("1.1.1."), .add, .exclusion)) {
            $0.validationError = .invalidIP
        }
        await store.send(.inputFieldChanged(" ")) {
            $0.ipEntry = " "
            $0.validationError = nil
        }
        await store.send(.entryClicked(.ip("1.1.1.1"), .remove, .exclusion)) {
            $0.$exclusionActivated.withLock { $0.ips = [] }
        }
    }

    @Test
    func modifyAppsList() async {
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        }
        await store.send(.entryClicked(.app(.huzza), .add, .exclusion)) {
            $0.$exclusionActivated.withLock { $0.apps = [.huzza] }
        }
        await store.send(.entryClicked(.app(.huzza), .add, .exclusion)) {
            $0.$exclusionActivated.withLock { $0.apps = [.huzza] }
        }
        await store.send(.entryClicked(.app(.huzza), .remove, .exclusion)) {
            $0.$exclusionActivated.withLock { $0.apps = [] }
        }
    }
}
