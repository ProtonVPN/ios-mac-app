//
//  Created on 27/05/2026 by Max Kupetskyi.
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
import Domain
import Foundation
@testable import ProtonVPN
import Testing
import VPNAppCore

@MainActor
@Suite("ConnectingOverlayFeature")
struct ConnectingOverlayFeatureTests {
    // MARK: - .buttonTapped

    @Test(
        "done/cancel while connected only dismisses — no disconnect command",
        arguments: [ConnectingOverlayFeature.ButtonKind.done, .cancel]
    )
    func doneOrCancelWhileConnectedOnlyDismisses(button: ConnectingOverlayFeature.ButtonKind) async {
        let client = ConnectionCommandClient(
            send: { _ in Issue.record("No command should be sent when already connected") },
            stream: { .finished }
        )
        let store = TestStore(
            initialState: ConnectingOverlayFeature.State(connectionState: .fakeConnected)
        ) {
            ConnectingOverlayFeature()
        } withDependencies: {
            $0.connectionCommandClient = client
        }

        await store.send(.buttonTapped(button))
        await store.receive(\.delegate.dismissRequested)
    }

    @Test(
        "done/cancel while not connected posts disconnect, then dismisses",
        arguments: [ConnectingOverlayFeature.ButtonKind.done, .cancel]
    )
    func doneOrCancelWhileNotConnectedPostsDisconnect(button: ConnectingOverlayFeature.ButtonKind) async {
        await confirmation("disconnect command sent") { confirm in
            let client = ConnectionCommandClient(
                send: { command in
                    if case .disconnect = command { confirm() }
                },
                stream: { .finished }
            )
            let store = TestStore(
                initialState: ConnectingOverlayFeature.State(
                    connectionState: .testConnecting(.defaultFastest)
                )
            ) {
                ConnectingOverlayFeature()
            } withDependencies: {
                $0.connectionCommandClient = client
            }

            await store.send(.buttonTapped(button))
            await store.receive(\.delegate.dismissRequested)
        }
    }

    @Test("retry clears timedOut flag and sends retry command")
    func retryClearsTimedOutAndSendsRetry() async {
        await confirmation("retry command sent") { confirm in
            let client = ConnectionCommandClient(
                send: { command in
                    if case .retry = command { confirm() }
                },
                stream: { .finished }
            )
            let store = TestStore(
                initialState: ConnectingOverlayFeature.State(timedOut: true)
            ) {
                ConnectingOverlayFeature()
            } withDependencies: {
                $0.connectionCommandClient = client
            }

            await store.send(.buttonTapped(.retry)) {
                $0.timedOut = false
            }
        }
    }

    @Test("retryWithoutKillSwitch clears timedOut, disables KS, sends retry")
    func retryWithoutKillSwitchDisablesKillSwitchAndRetries() async {
        @Shared(.killSwitch) var killSwitch: Bool
        $killSwitch.withLock { $0 = true }

        await confirmation("retry command sent") { confirm in
            let client = ConnectionCommandClient(
                send: { command in
                    if case .retry = command { confirm() }
                },
                stream: { .finished }
            )
            let store = TestStore(
                initialState: ConnectingOverlayFeature.State(timedOut: true)
            ) {
                ConnectingOverlayFeature()
            } withDependencies: {
                $0.connectionCommandClient = client
            }

            await store.send(.buttonTapped(.retryWithoutKillSwitch)) {
                $0.timedOut = false
            }
            #expect(killSwitch == false)
        }
    }

    @Test("delegate actions are inert")
    func delegateIsNoOp() async {
        let store = TestStore(initialState: ConnectingOverlayFeature.State()) {
            ConnectingOverlayFeature()
        } withDependencies: {
            $0.connectionCommandClient = .testValue
        }
        await store.send(.delegate(.dismissRequested))
    }

    // MARK: - State.displayState

    @Test("displayState falls back to connectionState when frozenState is nil")
    func displayStateUsesConnectionStateWhenNotFrozen() {
        let state = ConnectingOverlayFeature.State(
            connectionState: .testConnecting(.defaultFastest),
            frozenState: nil
        )
        #expect(state.displayState == .testConnecting(.defaultFastest))
    }

    @Test("displayState prefers frozenState when set")
    func displayStateUsesFrozenStateWhenSet() {
        let state = ConnectingOverlayFeature.State(
            connectionState: .disconnected,
            frozenState: .fakeConnected
        )
        #expect(state.displayState == .fakeConnected)
    }

    // MARK: - State.isIkeWithKsEnabled

    @Test(
        "isIkeWithKsEnabled is only true with IKE + KS",
        arguments: [
            (ConnectionProtocol.vpnProtocol(.ike), true, true),
            (.vpnProtocol(.ike), false, false),
            (.vpnProtocol(.wireGuard(.udp)), true, false),
            (.smartProtocol, true, false),
        ] as [(ConnectionProtocol, Bool, Bool)]
    )
    func isIkeWithKsEnabledCases(proto: ConnectionProtocol, ksOn: Bool, expected: Bool) {
        let state = ConnectingOverlayFeature.State(
            killSwitchEnabled: ksOn,
            selectedProtocol: proto
        )
        #expect(state.isIkeWithKsEnabled == expected)
    }

    // MARK: - State.isReconnecting

    @Test("isReconnecting: resolving with a prior server is a reconnect")
    func isReconnectingResolvingWithServer() {
        let state = ConnectingOverlayFeature.State(connectionState: .resolving)
        #expect(state.isReconnecting)
    }

    @Test("isReconnecting: resolving from cold start (no prior server) is not a reconnect")
    func isReconnectingResolvingNoServer() {
        let state = ConnectingOverlayFeature.State(connectionState: .resolving)
        #expect(!state.isReconnecting)
    }

    @Test("isReconnecting: connecting after a user disconnect is not a reconnect")
    func isReconnectingConnectingIntentional() {
        let state = ConnectingOverlayFeature.State(
            connectionState: .testConnecting(.defaultFastest),
            intentionallyDisconnected: true
        )
        #expect(!state.isReconnecting)
    }

    @Test("isReconnecting: connecting without a prior intentional disconnect is a reconnect")
    func isReconnectingConnectingPassive() {
        let state = ConnectingOverlayFeature.State(
            connectionState: .testConnecting(.defaultFastest),
            intentionallyDisconnected: false
        )
        #expect(state.isReconnecting)
    }

    @Test("isReconnecting: terminal states never count as reconnecting")
    func isReconnectingTerminalStates() {
        let connected = ConnectingOverlayFeature.State(connectionState: .fakeConnected)
        let disconnected = ConnectingOverlayFeature.State(connectionState: .disconnected)
        #expect(!connected.isReconnecting)
        #expect(!disconnected.isReconnecting)
    }

    // MARK: - State.headlinePhase

    @Test("headlinePhase: connected → .connected")
    func headlinePhaseConnected() {
        let state = ConnectingOverlayFeature.State(connectionState: .fakeConnected)
        #expect(state.headlinePhase == .connected)
    }

    @Test("headlinePhase: resolving with prior server (reconnecting) → .unprotected")
    func headlinePhaseUnprotected() {
        let state = ConnectingOverlayFeature.State(connectionState: .resolving)
        #expect(state.headlinePhase == .unprotected)
    }

    @Test("headlinePhase: fresh user-initiated connect → .initializing")
    func headlinePhaseInitializing() {
        let state = ConnectingOverlayFeature.State(
            connectionState: .testConnecting(.defaultFastest),
            intentionallyDisconnected: true
        )
        #expect(state.headlinePhase == .initializing)
    }

    // MARK: - State.bodyPhase

    @Test(
        "bodyPhase: timedOut carries IKE+KS flag",
        arguments: [
            (ConnectionProtocol.vpnProtocol(.ike), true, true),
            (.vpnProtocol(.wireGuard(.udp)), true, false),
            (.vpnProtocol(.ike), false, false),
        ] as [(ConnectionProtocol, Bool, Bool)]
    )
    func bodyPhaseTimedOutCarriesIkeKsFlag(proto: ConnectionProtocol, ks: Bool, expected: Bool) {
        let state = ConnectingOverlayFeature.State(
            timedOut: true,
            killSwitchEnabled: ks,
            selectedProtocol: proto
        )
        #expect(state.bodyPhase == .timedOut(isIkeWithKsEnabled: expected))
    }

    @Test("bodyPhase: connected → .connected(serverName:)")
    func bodyPhaseConnected() throws {
        let state = ConnectingOverlayFeature.State(connectionState: .fakeConnected)
        let server = try #require(ConnectionState.fakeConnected.resolvedServer)
        #expect(state.bodyPhase == .connected(
            serverName: .init(country: server.logical.country, name: server.logical.name)
        ))
    }

    @Test("bodyPhase: disconnected → .preparing")
    func bodyPhaseDisconnected() {
        let state = ConnectingOverlayFeature.State(connectionState: .disconnected)
        #expect(state.bodyPhase == .preparing)
    }

    @Test("bodyPhase: resolving with prior server → .reconnecting")
    func bodyPhaseReconnecting() {
        let state = ConnectingOverlayFeature.State(connectionState: .resolving)
        #expect(state.bodyPhase == .reconnecting)
    }

    @Test("bodyPhase: connecting after a user disconnect (no server) → .preparing")
    func bodyPhaseConnectingIntentional() {
        let state = ConnectingOverlayFeature.State(
            connectionState: .testConnecting(.defaultFastest),
            intentionallyDisconnected: true
        )
        #expect(state.bodyPhase == .preparing)
    }

    // MARK: - State.hidePhase

    @Test("hidePhase is true when timedOut OR when displayState is disconnected")
    func hidePhaseCases() {
        var timedOut = ConnectingOverlayFeature.State(timedOut: true)
        timedOut.connectionState = .testConnecting(.defaultFastest)
        #expect(timedOut.hidePhase)

        let disconnected = ConnectingOverlayFeature.State(connectionState: .disconnected)
        #expect(disconnected.hidePhase)

        let active = ConnectingOverlayFeature.State(
            connectionState: .testConnecting(.defaultFastest)
        )
        #expect(!active.hidePhase)
    }

    // MARK: - State.graphicKind

    @Test("graphicKind: timedOut wins over everything else")
    func graphicKindTimedOut() {
        var state = ConnectingOverlayFeature.State(timedOut: true)
        state.connectionState = .fakeConnected
        #expect(state.graphicKind == .warning)
    }

    @Test("graphicKind: connected → .connected, otherwise → .loading")
    func graphicKindConnectedVsLoading() {
        let connected = ConnectingOverlayFeature.State(connectionState: .fakeConnected)
        #expect(connected.graphicKind == .connected)

        let loading = ConnectingOverlayFeature.State(
            connectionState: .testConnecting(.defaultFastest)
        )
        #expect(loading.graphicKind == .loading)
    }

    // MARK: - State.beginConnecting

    @Test("beginConnecting resets to .resolving(nil, nil), clears frozen + timedOut")
    func beginConnectingResetsTransientFields() {
        var state = ConnectingOverlayFeature.State(
            connectionState: .fakeConnected,
            frozenState: .fakeConnected,
            timedOut: true,
            intentionallyDisconnected: false,
            killSwitchEnabled: false,
            selectedProtocol: .smartProtocol
        )

        state.beginConnecting(
            selectedProtocol: .vpnProtocol(.ike),
            killSwitchEnabled: true,
            intentionallyDisconnected: true
        )

        #expect(state.connectionState == .resolving)
        #expect(state.frozenState == nil)
        #expect(state.timedOut == false)
        #expect(state.intentionallyDisconnected == true)
        #expect(state.killSwitchEnabled == true)
        #expect(state.selectedProtocol == .vpnProtocol(.ike))
    }

    // MARK: - State.sync

    @Test("sync(connectionState:) freezes when transitioning to .connected")
    func syncFreezesOnConnected() {
        var state = ConnectingOverlayFeature.State()

        state.sync(
            connectionState: .fakeConnected,
            selectedProtocol: .vpnProtocol(.wireGuard(.udp)),
            killSwitchEnabled: false,
            intentionallyDisconnected: false
        )

        #expect(state.connectionState == .fakeConnected)
        #expect(state.frozenState == .fakeConnected)
    }

    @Test("sync(connectionState:) clears frozenState for non-connected states")
    func syncClearsFrozenForNonConnected() {
        var state = ConnectingOverlayFeature.State(frozenState: .fakeConnected)

        state.sync(
            connectionState: .testConnecting(.defaultFastest),
            selectedProtocol: .smartProtocol,
            killSwitchEnabled: false,
            intentionallyDisconnected: false
        )

        #expect(state.frozenState == nil)
        #expect(state.connectionState == .testConnecting(.defaultFastest))
    }

    // MARK: - Helpers

    private func intent(spec: ConnectionSpec = .defaultFastest) -> ServerConnectionIntent {
        ServerConnectionIntent(
            spec: spec,
            server: server(),
            protocolConfiguration: .ike,
            features: VPNConnectionFeatures(
                netshield: .off,
                vpnAccelerator: true,
                natType: .moderateNAT,
                safeMode: nil,
                portForwarding: nil
            )
        )
    }

    private func server() -> Server {
        VPNConnectionActual.mock().server
    }
}

// MARK: - ConnectionState helpers shared with SidebarFeatureTests

// `testConnecting` / `testConnected` / `fakeConnected` are defined in `SidebarFeatureTests`
// at file scope; if those tests are ever split into their own module these helpers should
// move to a small shared test-support file.

private extension ConnectionState {
    // `static let` so the captured `Date()` is computed once. With `static var`, every read
    // builds a fresh `.connected(..., Date(), ...)` and equality checks across two reads fail.
    static let fakeConnected: ConnectionState = {
        let actual = VPNConnectionActual.mock()
        return .connected(
            .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["peer-id"]),
            .init(currentPeer: actual.server, connectionDate: .now, protocolConnectionData: .ike)
        )
    }()

    static func testConnecting(_ spec: ConnectionSpec) -> ConnectionState {
        .connecting(.unresolved(ConnectionPreparationIntent(spec: spec, acceptableProtocols: .ikev2)))
    }
}
