//
//  Created on 06/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation
//import enum NetworkExtension.NEVPNStatus

//import Clocks
import ComposableArchitecture
//import Dependencies

import Domain
//import CoreConnection
//import CertificateAuthentication
//import ExtensionManager
//import LocalAgent
//import VPNAppCore

@available(iOS 16, *)
public struct VPNFeature: Reducer, Sendable {
    public init() { }

    @Shared(.connectionState) var connectionState: ConnectionState?

    public struct State: Equatable, Sendable {
        public internal(set) var connectionState: ConnectionState
        public internal(set) var internalState: ConnectionFeature.State

        public init(
            connectionState: ConnectionState,
            internalState: ConnectionFeature.State
        ) {
            self.connectionState = connectionState
            self.internalState = internalState
        }
    }

    @CasePathable
    public enum Action: Sendable {
        case preparation(ConnectionSpec, Server, ConnectionProtocol, TunnelFeatures)
        case connect(ServerConnectionIntent)
        case internalAction(ConnectionFeature.Action)
        case clearErrors
        case startObserving
        case stopObserving
        case handleLogout
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.internalState, action: \.internalAction) { ConnectionFeature() }
        Reduce { state, action in
            return .none
        }
    }
}
