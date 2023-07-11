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

import XCTest

import ComposableArchitecture

@testable import Settings

@MainActor
final class ProtocolSettingsTests: XCTestCase {

    func testProtocolSetWhenDisconnected() async throws {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(protocol: .smartProtocol, reconnectionAlert: nil)
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.vpnConnectionStatus = { .disconnected }
            $0.settingsStorage = .init(setConnectionProtocol: { _ in })
        }

        await store.send(.protocolTapped(.vpnProtocol(.ike)))

        await store.receive(.setProtocol(.success(.vpnProtocol(.ike)))) { resultState in
            resultState.protocol = .vpnProtocol(.ike)
        }
    }

    func testProtocolNotSetWhenStorageThrowsError() async throws {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(protocol: .smartProtocol, reconnectionAlert: nil)
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.vpnConnectionStatus = { .disconnected }
            $0.settingsStorage = .init(setConnectionProtocol: { _ in throw "Something went wrong" })
        }

        await store.send(.protocolTapped(.vpnProtocol(.ike)))

        await store.receive(.setProtocol(.failure("Something went wrong")))
    }

    func testAlertShownWhenConnected() async throws {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(protocol: .smartProtocol, reconnectionAlert: nil)
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.vpnConnectionStatus = { .connected(.init(location: .fastest, features: Set())) }
            $0.settingsStorage = .init(setConnectionProtocol: { _ in })
        }

        await store.send(.protocolTapped(.vpnProtocol(.ike)))

        await store.receive(.showReconnectionAlert(.vpnProtocol(.ike))) { resultState in
            resultState.reconnectionAlert = SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
        }
    }

    func testConnectionRestartedWithNewProtocol() async throws {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                reconnectionAlert: SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
            )
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.vpnConnectionStatus = { .connected(.init(location: .fastest, features: Set())) }
            $0.settingsStorage = .init(setConnectionProtocol: { _ in })
        }

        await store.send(.reconnectWith(.vpnProtocol(.ike)))

        await store.receive(.setProtocol(.success(.vpnProtocol(.ike)))) { resultState in
            resultState.protocol = .vpnProtocol(.ike)
        }
    }

    func testConnectionUninterruptedWhenAlertDismissed() async throws {
        let store = TestStore(
            initialState: ProtocolSettingsFeature.State(
                protocol: .smartProtocol,
                reconnectionAlert: SettingsAlert.reconnectionAlertState(for: .vpnProtocol(.ike))
            )
        ) {
            ProtocolSettingsFeature()
        } withDependencies: {
            $0.settingsStorage = .init(setConnectionProtocol: { _ in })
        }

        await store.send(.reconnectionAlertDismissed) { resultState in
            resultState.reconnectionAlert = nil
        }
    }
}

extension String: Error {}
