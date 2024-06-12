//
//  Created on 27/05/2024.
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
import SwiftUI

@Reducer struct ConnectFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.inMemory("connectionState")) var connectionState: ConnectionState?
    }
    
    enum ConnectionState: Codable, Equatable {
        case connected(countryCode: String, ip: String)
        case connecting(countryCode: String?)
        case disconnected
        case disconnecting
    }
    
    enum Action {
        case userClickedConnect(CountryListItem?)
        case userClickedCancel
        case userClickedDisconnect
        case connectionEstablished(countryCode: String, ip: String)
        case connectionFailed
        case connectionTerminated
        case initialize
    }
    
    @Dependency(\.connectionClient) var client
    
    private enum CancelID { case connect }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .initialize:
                if state.connectionState == nil {
                    state.connectionState = .disconnected // TODO: properly initialise the connection state
                }
                return .none
            case .userClickedConnect(let item):
                withAnimation {
                    state.connectionState = .connecting(countryCode: item?.code)
                }
                return .run { send in
                    let (countryCode, ip) = try await client.connect(item?.code)
                    await send(.connectionEstablished(countryCode: countryCode, ip: ip))
                } catch: { error, send in
                    await send(.connectionFailed)
                }
                    .cancellable(id: CancelID.connect)
            case .userClickedCancel:
                withAnimation {
                    state.connectionState = .disconnected
                }
                return .cancel(id: CancelID.connect)
            case .userClickedDisconnect:
                withAnimation {
                    state.connectionState = .disconnecting
                }
                return .run { send in
                    try await client.disconnect()
                    await send(.connectionTerminated)
                }
            case .connectionEstablished(let countryCode, let ip):
                withAnimation {
                    state.connectionState = .connected(countryCode: countryCode, ip: ip)
                }
                return .none
            case .connectionTerminated, .connectionFailed:
                withAnimation {
                    state.connectionState = .disconnected
                }
                return .none
            }
        }
    }
}
