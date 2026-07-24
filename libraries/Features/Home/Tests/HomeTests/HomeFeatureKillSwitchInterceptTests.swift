//
//  Created on 23/07/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

#if DEBUG // MockTunnelManager is only built for debug configurations
    import ComposableArchitecture
    @testable import Connection
    import Domain
    import DomainTestSupport
    @testable import ExtensionManager
    @testable import HomeShared
    import Testing
    import VPNAppCore

    /// Exercises the Advanced kill switch disconnect intercept: an intentional disconnect that would
    /// leave the device offline must be confirmed by the user first. The intercept requires all of:
    /// no completion to settle, a non-exempt trigger, the Advanced mode, and a connected tunnel that
    /// actually carries the kill switch flag. Each pass-through test drops exactly one requirement
    /// and expects the disconnect to go straight to the connection.
    @MainActor
    struct HomeFeatureKillSwitchInterceptTests {
        @Shared(.killSwitchMode) private var killSwitchMode: KillSwitchMode
        @Shared(.connectionState) private var connectionState: ConnectionState

        private static func connected(tunnelKillSwitch: Bool) -> ConnectionState {
            .connected(
                .init(
                    connectionSpec: .defaultFastest,
                    tunnelProtocol: .wireGuard,
                    peerIDs: ["peer-id"],
                    killSwitch: tunnelKillSwitch
                ),
                .init(currentPeer: .mock, connectionDate: .now, protocolConnectionData: .ike)
            )
        }

        private func makeStore() -> TestStoreOf<HomeFeature> {
            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                // A pass-through disconnect cascades into ConnectionFeature and the tunnel mock.
                $0.connectionFeatureProvider = .init(
                    connectionFeatures: { .mock },
                    requestedFeatures: { .init(killSwitch: false, excludeLocalNetworks: false) },
                    connectionProtocol: { .smartProtocol }
                )
                $0.tunnelManager = MockTunnelManager()
                $0.continuousClock = ImmediateClock()
                $0.date = .constant(.now)
            }
            store.exhaustivity = .off
            return store
        }

        @Test
        func armedAdvancedDisconnectIsIntercepted() async {
            $killSwitchMode.withLock { $0 = .advanced }
            $connectionState.withLock { $0 = Self.connected(tunnelKillSwitch: true) }
            let store = makeStore()

            await store.send(.connectionCommandReceived(.disconnect(.quick)))
            #expect(store.state.alert != nil)

            // Confirming performs the disconnect it held back.
            await store.send(.alert(.presented(.confirmDisconnectWithAdvancedKillSwitch(.quick))))
            await store.receive(\.connection.input.disconnect)
        }

        @Test
        func disconnectPassesThroughWhenTunnelIsNotArmed() async {
            // Advanced was enabled mid-session: the live tunnel does not carry the flag, so
            // disconnecting does not black-hole the device and needs no confirmation.
            $killSwitchMode.withLock { $0 = .advanced }
            $connectionState.withLock { $0 = Self.connected(tunnelKillSwitch: false) }
            let store = makeStore()

            await store.send(.connectionCommandReceived(.disconnect(.quick)))
            #expect(store.state.alert == nil)
            await store.receive(\.connection.input.disconnect)
        }

        @Test
        func disconnectPassesThroughForStandardMode() async {
            // Standard releases on intentional disconnect, so the device stays online.
            $killSwitchMode.withLock { $0 = .standard }
            $connectionState.withLock { $0 = Self.connected(tunnelKillSwitch: true) }
            let store = makeStore()

            await store.send(.connectionCommandReceived(.disconnect(.quick)))
            #expect(store.state.alert == nil)
            await store.receive(\.connection.input.disconnect)
        }

        @Test
        func disconnectPassesThroughForExemptTrigger() async {
            // Sign-out shows its own kill-switch-aware confirmation, so this one stays silent.
            $killSwitchMode.withLock { $0 = .advanced }
            $connectionState.withLock { $0 = Self.connected(tunnelKillSwitch: true) }
            let store = makeStore()

            await store.send(.connectionCommandReceived(.disconnect(.signout)))
            #expect(store.state.alert == nil)
            await store.receive(\.connection.input.disconnect)
        }

        @Test
        func disconnectPassesThroughWhenCompletionNeedsResolving() async {
            // Completion-carrying commands (the widget) must resolve, so they are never held up.
            $killSwitchMode.withLock { $0 = .advanced }
            $connectionState.withLock { $0 = Self.connected(tunnelKillSwitch: true) }
            let store = makeStore()

            await store.send(.connectionCommandReceived(.disconnect(.quick, completion: {})))
            #expect(store.state.alert == nil)
            await store.receive(\.connection.input.disconnect)
        }
    }
#endif
