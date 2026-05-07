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
import Ergonomics
@testable import Settings
@testable import SettingsShared
import Testing

@Suite("Protocol Settings Tests", .serialized)
@MainActor
struct ProtocolSettingsTests {
    @Test("Protocol is set when disconnected")
    func protocolSetWhenDisconnected() async {
        let store = TestStore(
            initialState: ProtocolSettingsFeature
                .State(protocol: .smartProtocol, vpnConnectionStatus: .disconnected, reconnectionAlert: nil)
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.settingsStorage = .init(setConnectionProtocol: { _ in })
        }

        await store.send(.protocolTapped(.vpnProtocol(.ike)))

        await store.receive(.setProtocol(.success(.vpnProtocol(.ike)))) { resultState in
            resultState.connectionProtocol = .vpnProtocol(.ike)
        }
    }

    @Test("Protocol is not set when storage throws an error")
    func protocolNotSetWhenStorageThrowsError() async {
        let error = GenericError(message: "Something went wrong")
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                vpnConnectionStatus: .disconnected,
                reconnectionAlert: nil
            )
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.settingsStorage = .init(setConnectionProtocol: { _ in throw error })
        }

        await store.send(.protocolTapped(.vpnProtocol(.ike)))

        await store.receive(.setProtocol(.failure(error)))
    }

    @Test("Reconnection alert is shown when connected")
    func alertShownWhenConnected() async {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                vpnConnectionStatus: .connected(.init(location: .any(.fastest), features: Set()), nil),
                reconnectionAlert: nil
            )
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.settingsStorage = .init(setConnectionProtocol: { _ in })
        }

        await store.send(.protocolTapped(.vpnProtocol(.ike)))

        await store.receive(.showReconnectionAlert(.vpnProtocol(.ike))) { resultState in
            resultState.reconnectionAlert = SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
        }
    }

    @Test("Connection is restarted with the new protocol")
    func connectionRestartedWithNewProtocol() async {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                vpnConnectionStatus: .connected(.init(location: .any(.fastest), features: Set()), nil),
                reconnectionAlert: SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
            )
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.settingsStorage = .init(setConnectionProtocol: { _ in })
        }

        await store.send(.reconnectionAlert(.presented(.reconnectWith(.vpnProtocol(.ike)))))

        await store.receive(.setProtocol(.success(.vpnProtocol(.ike)))) { resultState in
            resultState.connectionProtocol = .vpnProtocol(.ike)
        }
    }

    @Test("Connection is uninterrupted when the alert is dismissed")
    func connectionUninterruptedWhenAlertDismissed() async {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                vpnConnectionStatus: .disconnected,
                reconnectionAlert: SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
            )
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.settingsStorage = .init(setConnectionProtocol: { _ in })
        }

        await store.send(.reconnectionAlert(.dismiss)) { resultState in
            resultState.reconnectionAlert = nil
        }
    }
}
