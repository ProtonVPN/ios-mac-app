//
//  Created on 20/05/2026 by Max Kupetskyi.
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
import Dependencies
import Domain
import Sharing
import VPNAppCore
import VPNShared

@Reducer
struct ConnectingOverlayFeature {
    enum ButtonKind: Equatable, Hashable {
        case cancel
        case done
        case retry
        case retryWithoutKillSwitch
    }

    @ObservableState
    struct State: Equatable {
        var connectionState: ConnectionState = .disconnected
        var frozenState: ConnectionState?
        var timedOut = false
        var intentionallyDisconnected = false
        var killSwitchEnabled = false
        var selectedProtocol: ConnectionProtocol = .smartProtocol

        enum GraphicKind: Equatable {
            case loading
            case connected
            case warning
        }

        var displayState: ConnectionState {
            frozenState ?? connectionState
        }

        var isIkeWithKsEnabled: Bool {
            selectedProtocol == .vpnProtocol(.ike) && killSwitchEnabled
        }

        var isReconnecting: Bool {
            switch displayState {
            case .resolving:
                // TODO: ProTUN: find a way to fix the code below
                // actual != nil
                false
            case .connecting:
                !intentionallyDisconnected
            default:
                false
            }
        }

        var hidePhase: Bool {
            timedOut || displayState.is(\.disconnected)
        }

        var graphicKind: GraphicKind {
            if timedOut {
                return .warning
            }
            if displayState.is(\.connected) {
                return .connected
            }
            return .loading
        }
    }

    enum Action: Equatable {
        case buttonTapped(ButtonKind)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case dismissRequested
        }
    }

    @Shared(.killSwitch) private var killSwitch: Bool
    @Dependency(\.connectionCommandClient) private var connectionCommandClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .buttonTapped(button):
                switch button {
                case .done, .cancel:
                    if !state.displayState.is(\.connected) {
                        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
                        connectionCommandClient.send(.disconnect(.auto))
                    }
                    return .send(.delegate(.dismissRequested))

                case .retry:
                    state.timedOut = false
                    connectionCommandClient.send(.retry)
                    return .none

                case .retryWithoutKillSwitch:
                    state.timedOut = false
                    $killSwitch.withLock { $0 = false }
                    connectionCommandClient.send(.retry)
                    return .none
                }

            case .delegate:
                return .none
            }
        }
    }
}

extension ConnectingOverlayFeature.State {
    enum HeadlinePhase: Equatable {
        case connected
        case unprotected
        case initializing
    }

    enum BodyPhase: Equatable {
        case timedOut(isIkeWithKsEnabled: Bool)
        case connected(serverName: ServerName)
        case connecting(serverName: ServerName)
        case reconnecting
        case preparing
    }

    struct ServerName: Equatable {
        let country: String
        let name: String
    }

    var headlinePhase: HeadlinePhase {
        if displayState.is(\.connected) { return .connected }
        return isReconnecting ? .unprotected : .initializing
    }

    var bodyPhase: BodyPhase {
        if timedOut {
            return .timedOut(isIkeWithKsEnabled: isIkeWithKsEnabled)
        }
        let serverName = displayState.resolvedServer.map {
            ServerName(country: $0.logical.country, name: $0.logical.name)
        }
        switch displayState {
        case .connected:
            return serverName.map { .connected(serverName: $0) } ?? .preparing
        case .disconnected:
            return isReconnecting ? .reconnecting : .preparing
        case .resolving, .connecting, .disconnecting:
            if isReconnecting { return .reconnecting }
            return serverName.map { .connecting(serverName: $0) } ?? .preparing
        }
    }

    mutating func beginConnecting(
        selectedProtocol: ConnectionProtocol,
        killSwitchEnabled: Bool,
        intentionallyDisconnected: Bool
    ) {
        connectionState = .resolving
        frozenState = nil
        timedOut = false
        self.selectedProtocol = selectedProtocol
        self.killSwitchEnabled = killSwitchEnabled
        self.intentionallyDisconnected = intentionallyDisconnected
    }

    mutating func sync(
        connectionState: ConnectionState,
        selectedProtocol: ConnectionProtocol,
        killSwitchEnabled: Bool,
        intentionallyDisconnected: Bool
    ) {
        self.connectionState = connectionState
        self.selectedProtocol = selectedProtocol
        self.killSwitchEnabled = killSwitchEnabled
        self.intentionallyDisconnected = intentionallyDisconnected
        if connectionState.is(\.connected) {
            frozenState = connectionState
        } else {
            frozenState = nil
        }
    }
}
