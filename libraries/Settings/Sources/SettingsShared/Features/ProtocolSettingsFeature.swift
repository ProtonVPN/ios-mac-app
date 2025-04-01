//
//  Created on 03/07/2023.
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
import Dependencies

import Domain
import VPNAppCore
import VPNShared

public struct ProtocolSettingsFeature: Reducer {
    @Dependency(\.disconnectVPN) var disconnectVPN
    @Dependency(\.connectToVPN) var connectVPN
    @Dependency(\.settingsStorage) var storage


    public struct State: Equatable {
        public var `protocol`: ConnectionProtocol
        public var vpnConnectionStatus: VPNConnectionStatus
        @PresentationState public var reconnectionAlert: AlertState<Action.Alert>?

        public init(
            protocol: ConnectionProtocol,
            vpnConnectionStatus: VPNConnectionStatus,
            reconnectionAlert: AlertState<Action.Alert>?
        ) {
            self.protocol = `protocol`
            self.vpnConnectionStatus = vpnConnectionStatus
            self.reconnectionAlert = reconnectionAlert
        }

        public init() {
            self.protocol = .smartProtocol
            self.vpnConnectionStatus = .disconnected
            self.reconnectionAlert = nil
        }
    }

    @CasePathable
    public enum Action: Equatable {
        case protocolTapped(ConnectionProtocol)
        case setProtocol(TaskResult<ConnectionProtocol>)
        case showReconnectionAlert(ConnectionProtocol)
        case reconnectionAlert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            case reconnectWith(ConnectionProtocol)
        }
    }

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .protocolTapped(`protocol`):
            if state.protocol == `protocol` {
                return .none // Do nothing when the user taps on the currently selected protocol
            }
            if state.vpnConnectionStatus == .disconnected {
                return .run { send in
                    return await send(.setProtocol(TaskResult {
                        try await storage.setConnectionProtocol(`protocol`)
                        return `protocol`
                    }))
                }
            } else {
                return .run { send in
                    return await send(.showReconnectionAlert(`protocol`))
                }
            }

        case let .setProtocol(.success(`protocol`)):
            state.protocol = `protocol`
            return .none

        case .setProtocol(.failure):
            // We have a chance to show a generic 'failed to apply settings, please file a bug report' alert
            return .none

        case let .showReconnectionAlert(`protocol`):
            if #available(macOS 12, *) {
                state.reconnectionAlert = SettingsAlert.reconnectionAlertState(for: `protocol`)
            }
            return .none

        case .reconnectionAlert(.presented(.reconnectWith(let `protocol`))):
            // This may require a blocking interface to at least disconnecting (maybe also connecting)
            return .run { send in
                // let status = await connectionStatus()
                // disconnectVPN()
                await send(.setProtocol(TaskResult {
                    try await storage.setConnectionProtocol(`protocol`)
                    return `protocol`
                }))
                // guard case let .connected(specs) = status else { return }
                // connectVPN(specs)
                return
            }

        case .reconnectionAlert(.dismiss):
            state.reconnectionAlert = nil
            return .none
        }
    }
}
