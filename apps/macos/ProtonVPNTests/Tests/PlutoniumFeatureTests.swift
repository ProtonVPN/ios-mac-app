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

import LegacyCommon

import Foundation
@testable import ProtonVPN
@testable import VPNAppCore
import VPNSharedTesting

@MainActor
struct PlutoniumFeatureTests {
    @Shared(.killSwitch) var killSwitch
    @Dependency(\.propertiesManager) private var propertiesManager

    init() {
        $killSwitch.withLock { $0 = false }
    }

    @Test
    func onAppear() async {
        let clock = TestClock()
        @Dependency(\.propertiesManager) var propertiesManager
        let vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
        let alertService = CoreAlertServiceDummy()
        let profileManager = ProfileManager(
            profileStorage: ProfileStorage(authKeychain: MockAuthKeychain())
        )
        let systemExtensionManager = SystemExtensionManagerMock(
            factory: SystemExtensionManagerMockFactory(
                vpnKeychain: vpnKeychain,
                profileManager: profileManager,
                alertService: alertService
            )
        )
        propertiesManager.connectionProtocol = .smartProtocol
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
        } withDependencies: {
            $0.continuousClock = clock
            $0.systemExtensionManager = systemExtensionManager
        }
        systemExtensionManager.requestRequiresUserApproval = { request in
            Task {
                try await clock.sleep(for: .nanoseconds(1))
                systemExtensionManager.approve(request: request)
            }
        }
        #expect(store.state.requiresReconnection == false)

        await store.send(.onAppear) {
            $0.discoveredApps = [.huzza]
        }

        await store.send(.toggleModeClicked)
        await store.receive(\.installExtensions)
        await clock.advance(by: .seconds(1))
        await store.receive(\.extensionInstallationCompleted) {
            $0.$feature.withLock {
                $0 = .enabled(.exclusion)
            }
        }
    }

    @Test
    func toggleModeKillSwitchConflict() async {
        let clock = TestClock()
        let vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
        let alertService = CoreAlertServiceDummy()
        let profileManager = ProfileManager(
            profileStorage: ProfileStorage(authKeychain: MockAuthKeychain())
        )
        let systemExtensionManager = SystemExtensionManagerMock(
            factory: SystemExtensionManagerMockFactory(
                vpnKeychain: vpnKeychain,
                profileManager: profileManager,
                alertService: alertService
            )
        )
        propertiesManager.connectionProtocol = .smartProtocol
        $killSwitch.withLock {
            $0 = true
        }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
        } withDependencies: {
            $0.continuousClock = clock
            $0.systemExtensionManager = systemExtensionManager
        }
        systemExtensionManager.requestRequiresUserApproval = { request in
            Task {
                try await clock.sleep(for: .nanoseconds(1))
                systemExtensionManager.approve(request: request)
            }
        }

        await store.send(.toggleModeClicked) {
            $0.alert = PlutoniumFeature.confirmAlert
        }
        await store.send(.alert(.presented(.toggleModeConfirmed))) {
            $0.alert = nil
        }
        await store.receive(\.installExtensions)
        await clock.advance(by: .seconds(1))
        await store.receive(\.extensionInstallationCompleted) {
            $0.$feature.withLock {
                $0 = .enabled(.exclusion)
            }
        }
    }

    @Test
    func toggleModeIKEConflict() async {
        let vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
        let alertService = CoreAlertServiceDummy()
        let profileManager = ProfileManager(
            profileStorage: ProfileStorage(authKeychain: MockAuthKeychain())
        )
        let systemExtensionManager = SystemExtensionManagerMock(
            factory: SystemExtensionManagerMockFactory(
                vpnKeychain: vpnKeychain,
                profileManager: profileManager,
                alertService: alertService
            )
        )
        propertiesManager.connectionProtocol = .vpnProtocol(.ike)
        $killSwitch.withLock {
            $0 = true
        }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
        } withDependencies: {
            $0.systemExtensionManager = systemExtensionManager
        }

        await store.send(.toggleModeClicked) {
            $0.alert = PlutoniumFeature.unsupportedProtocolErrorAlert
        }
    }

    @Test
    func toggleModeIKEProfileConflict() async {
        let vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
        let alertService = CoreAlertServiceDummy()
        let profileManager = ProfileManager(
            profileStorage: ProfileStorage(authKeychain: MockAuthKeychain())
        )
        let systemExtensionManager = SystemExtensionManagerMock(
            factory: SystemExtensionManagerMockFactory(
                vpnKeychain: vpnKeychain,
                profileManager: profileManager,
                alertService: alertService
            )
        )

        propertiesManager.connectionProtocol = .smartProtocol
        let gateway = VpnGatewayMock()
        gateway.connection = .connected
        let appStateManager = AppStateManagerMock()
        appStateManager.mockActiveConnection = ConnectionConfiguration.ikev2ConnectionConfig
        $killSwitch.withLock {
            $0 = true
        }
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature(appStateManager: appStateManager, vpnGateway: gateway)
        } withDependencies: {
            $0.systemExtensionManager = systemExtensionManager
        }

        await store.send(.toggleModeClicked) {
            $0.alert = PlutoniumFeature.unsupportedProfileErrorAlert
        }
    }

    @Test
    func toggleMode() async {
        let clock = TestClock()
        let vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .max)
        let alertService = CoreAlertServiceDummy()
        let profileManager = ProfileManager(
            profileStorage: ProfileStorage(authKeychain: MockAuthKeychain())
        )
        let systemExtensionManager = SystemExtensionManagerMock(
            factory: SystemExtensionManagerMockFactory(
                vpnKeychain: vpnKeychain,
                profileManager: profileManager,
                alertService: alertService
            )
        )
        propertiesManager.connectionProtocol = .smartProtocol
        let store = TestStore(initialState: PlutoniumFeature.State()) {
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
        } withDependencies: {
            $0.continuousClock = clock
            $0.systemExtensionManager = systemExtensionManager
        }
        systemExtensionManager.requestRequiresUserApproval = { request in
            Task {
                try await clock.sleep(for: .nanoseconds(1))
                systemExtensionManager.approve(request: request)
            }
        }
        #expect(store.state.requiresReconnection == false)

        await store.send(.toggleModeClicked)
        await store.receive(\.installExtensions)
        await clock.advance(by: .seconds(1))
        await store.receive(\.extensionInstallationCompleted) {
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
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
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
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
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
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
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
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
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
            PlutoniumFeature(appStateManager: AppStateManagerMock(), vpnGateway: VpnGatewayMock())
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

extension ConnectionConfiguration {
    static var ikev2ConnectionConfig: ConnectionConfiguration {
        let server = ServerModel(
            id: "",
            name: "",
            domain: "",
            load: 0,
            entryCountryCode: "",
            exitCountryCode: "",
            tier: 1,
            feature: .zero,
            city: nil,
            ips: [ServerIp](),
            score: 0.0,
            status: 0,
            location: ServerLocation(lat: 0, long: 0),
            hostCountry: nil,
            translatedCity: nil,
            gatewayName: nil
        )
        let serverIp = ServerIp(
            id: "",
            entryIp: "",
            exitIp: "",
            domain: "",
            status: 0
        )
        return ConnectionConfiguration(
            id: UUID(),
            server: server,
            serverIp: serverIp,
            vpnProtocol: .ike,
            netShieldType: .off,
            natType: .default,
            safeMode: true,
            portForwarding: true,
            ports: [500],
            intent: .fastest
        )
    }
}
