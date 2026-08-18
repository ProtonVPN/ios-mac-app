//
//  Created on 10/07/2023.
//
//  Copyright (c) 2023 Proton AG
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

import ComposableArchitecture
import Connection
import Ergonomics
@testable import Settings
@testable import SettingsShared
import Sharing
import Testing
import VPNAppCore

@Suite("Protocol Settings Tests")
@MainActor
struct ProtocolSettingsTests {
    @Test("Protocol is set when disconnected")
    func protocolSetWhenDisconnected() async {
        let store = TestStore(
            initialState: ProtocolSettingsFeature
                .State(protocol: .smartProtocol, connectionState: .disconnected, reconnectionAlert: nil)
        ) {
            ProtocolSettingsFeature()
        }

        await store.send(.protocolTapped(.vpnProtocol(.ike)))

        await store.receive(.setProtocol(.success(.vpnProtocol(.ike)))) { resultState in
            resultState.connectionProtocol = .vpnProtocol(.ike)
        }

        @SharedReader(.connectionProtocol) var connectionProtocol
        #expect(connectionProtocol == .vpnProtocol(.ike))
    }

    @Test("Reconnection alert is shown when connected")
    func alertShownWhenConnected() async {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                connectionState: .resolving,
                reconnectionAlert: nil
            )
        ) {
            ProtocolSettingsFeature()
        }

        await store.send(.protocolTapped(.vpnProtocol(.ike)))

        await store.receive(.showReconnectionAlert(.vpnProtocol(.ike))) { resultState in
            resultState.reconnectionAlert = SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
        }

        // Showing the alert must not persist anything yet.
        @SharedReader(.connectionProtocol) var connectionProtocol
        #expect(connectionProtocol == .smartProtocol)
    }

    @Test("Connection is restarted with the new protocol")
    func connectionRestartedWithNewProtocol() async {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                connectionState: .resolving,
                reconnectionAlert: SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
            )
        ) {
            ProtocolSettingsFeature()
        }

        await store.send(.reconnectionAlert(.presented(.reconnectWith(.vpnProtocol(.ike)))))

        await store.receive(.setProtocol(.success(.vpnProtocol(.ike)))) { resultState in
            resultState.connectionProtocol = .vpnProtocol(.ike)
        }

        @SharedReader(.connectionProtocol) var connectionProtocol
        #expect(connectionProtocol == .vpnProtocol(.ike))
    }

    @Test("Connection is uninterrupted when the alert is dismissed")
    func connectionUninterruptedWhenAlertDismissed() async {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                connectionState: .disconnected,
                reconnectionAlert: SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
            )
        ) {
            ProtocolSettingsFeature()
        }

        await store.send(.reconnectionAlert(.dismiss)) { resultState in
            resultState.reconnectionAlert = nil
        }

        // Dismissing the alert must leave the stored protocol untouched.
        @SharedReader(.connectionProtocol) var connectionProtocol
        #expect(connectionProtocol == .smartProtocol)
    }
}
