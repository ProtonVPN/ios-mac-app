//
//  Created on 03/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import ComposableArchitecture

import struct Domain.VPNConnectionFeatures
import struct Domain.VPNServer

public struct LocalAgentFeature: Reducer, Sendable {
    // @Dependency(\.localAgent) var localAgent

    public init() { }

    public enum State: Equatable, Sendable {
        case disconnected
        case connecting
        case connected
    }

    public enum Action: Sendable {
        case startObservingStateChanges
        case connect // (VPNServer, VPNConnectionFeatures, VpnAuthenticationData)
        case disconnect
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startObservingStateChanges:
                return .none

            case .connect: // (let server, let features, let authenticationData):
                state = .connected
                return .none

            case .disconnect:
                state = .disconnected
                return .none
            }

        }
    }
}
