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

import CommonNetworking
import ComposableArchitecture
import Connection
import Domain
import Foundation
@testable import ProtonVPN
import Testing
@testable import VPNAppCore
import VPNShared
import VPNSharedTesting

@MainActor
struct PlutoniumFeatureTests {
    @Shared(.killSwitch) var killSwitch
    @Shared(.connectionState) var connectionState
    @Shared(.connectionProtocol) var connectionProtocol

    init() {
        $killSwitch.withLock { $0 = false }
        $connectionState.withLock { $0 = .disconnected }
        $connectionProtocol.withLock { $0 = .smartProtocol }
    }

    @Test
    func onAppear() async {
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        } withDependencies: {
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
            $connectionProtocol.withLock { $0 = .smartProtocol }
        }
        #expect(store.state.requiresReconnection == false)

        await store.send(.onAppear) {
            $0.discoveredApps = [.huzza]
        }

        await store.send(.toggleModeClicked)
        await store.receive(\.installExtensions) {
            $0.$feature.withLock {
                $0 = .enabled(.exclusion)
            }
        }
        await store.receive(\.extensionInstallationCompleted)
    }

    @Test
    func toggleModeKillSwitchConflict() async {
        $killSwitch.withLock {
            $0 = true
        }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        } withDependencies: {
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
            $connectionProtocol.withLock { $0 = .smartProtocol }
        }

        await store.send(.toggleModeClicked) {
            $0.alert = PlutoniumFeature.confirmAlert
        }
        await store.send(.alert(.presented(.toggleModeConfirmed))) {
            $0.alert = nil
        }
        await store.receive(\.installExtensions) {
            $0.$feature.withLock {
                $0 = .enabled(.exclusion)
            }
        }
        await store.receive(\.extensionInstallationCompleted)
    }

    @Test
    func toggleModeIKEConflict() async {
        $killSwitch.withLock {
            $0 = false
        }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        } withDependencies: {
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
            $connectionProtocol.withLock { $0 = .vpnProtocol(.ike) }
        }

        await store.send(.toggleModeClicked) {
            $0.alert = PlutoniumFeature.unsupportedProtocolErrorAlert
        }
    }

    @Test
    func toggleModeIKEProfileConflict() async {
        let actual = VPNConnectionActual.mock(vpnProtocol: .ike)
        $connectionState.withLock {
            $0 = .connected(
                .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["peer-id"], killSwitch: false),
                .init(currentPeer: actual.server, connectionDate: .now, protocolConnectionData: .ike)
            )
        }
        $killSwitch.withLock {
            $0 = true
        }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        } withDependencies: {
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
            $connectionProtocol.withLock { $0 = .smartProtocol }
        }

        await store.send(.toggleModeClicked) {
            $0.alert = PlutoniumFeature.unsupportedProfileErrorAlert
        }
    }

    @Test
    func toggleMode() async {
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        } withDependencies: {
            $0.vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
            $connectionProtocol.withLock { $0 = .smartProtocol }
        }
        #expect(store.state.requiresReconnection == false)

        await store.send(.toggleModeClicked)
        await store.receive(\.installExtensions) {
            $0.$feature.withLock {
                $0 = .enabled(.exclusion)
            }
        }
        await store.receive(\.extensionInstallationCompleted)
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
    @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated
    @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated

    @Shared(.plutoniumFeatureApplied) var featureApplied: PlutoniumFeatureToggle
    @Shared(.inclusionActivatedApplied) var inclusionActivatedApplied: PlutoniumActivated
    @Shared(.exclusionActivatedApplied) var exclusionActivatedApplied: PlutoniumActivated

    @Test
    func requiresReconnectionAfterDisabling() async {
        $featureApplied.withLock { $0 = .enabled(.exclusion) }
        $feature.withLock { $0 = .enabled(.exclusion) }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature()
        } withDependencies: { _ in
            $connectionProtocol.withLock { $0 = .smartProtocol }
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
        } withDependencies: { _ in
            $connectionProtocol.withLock { $0 = .smartProtocol }
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
        } withDependencies: { _ in
            $connectionProtocol.withLock { $0 = .smartProtocol }
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
        } withDependencies: { _ in
            $connectionProtocol.withLock { $0 = .smartProtocol }
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
        } withDependencies: { _ in
            $connectionProtocol.withLock { $0 = .smartProtocol }
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
