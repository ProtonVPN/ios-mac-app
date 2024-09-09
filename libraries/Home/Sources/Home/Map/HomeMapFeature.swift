//
//  Created on 17/09/2024.
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

import ComposableArchitecture
import Foundation
import Domain
import VPNAppCore
import SwiftUI

@available(iOS 17.0, *)
@Reducer
public struct HomeMapFeature {

    @ObservableState
    public struct State: Equatable {
        
        public var mapState: MapState = .disconnected
        public var pinMode: MapPin.Mode = .disconnected

        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus
        @SharedReader(.userCountry) public var userCountry: String?

        public init() { }
    }

    public enum MapState: Equatable {
        case connectedCountry(String)
        case connectedCoordinates(Coordinates, String?)
        case connectingCountry(String)
        case connectingCoordinates(Coordinates, String?)
        case disconnected
        fileprivate var pinMode: MapPin.Mode {
            switch self {
            case .connectedCountry, .connectedCoordinates:
                return .exitConnected
            case .connectingCountry, .connectingCoordinates:
                return .connecting
            case .disconnected:
                return .disconnected
            }
        }
        var code: String? {
            switch self {
            case .connectedCountry(let code):
                return code
            case .connectedCoordinates(_, let code):
                return code
            case .connectingCountry(let code):
                return code
            case .connectingCoordinates(_, let code):
                return code
            case .disconnected:
                return nil
            }
        }
        var coordinates: Coordinates? {
            switch self {
            case .connectedCountry(let code):
                return CountriesCoordinates.countryCenterCoordinates(code.uppercased())
            case .connectedCoordinates(let coordinates, _):
                return coordinates
            case .connectingCountry(let code):
                return CountriesCoordinates.countryCenterCoordinates(code.uppercased())
            case .connectingCoordinates(let coordinates, _):
                return coordinates
            case .disconnected:
                return nil
            }
        }
    }

    public enum Action: Equatable {
        case observeConnectionState
        case connectionStateUpdated(VPNConnectionStatus)
        case onAppear
    }

    enum CancelId {
        case connectionState
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .observeConnectionState:
                return .publisher {
                    state
                        .$vpnConnectionStatus
                        .publisher
                        .receive(on: UIScheduler.shared)
                        .map(Action.connectionStateUpdated)
                }
                .cancellable(id: CancelId.connectionState)
            case .onAppear:
                return .send(.observeConnectionState)
            case .connectionStateUpdated(let connectionStatus):
                let mapState: MapState
                switch connectionStatus {
                case .disconnected, .disconnecting:
                    mapState = .disconnected
                case .connected(let spec, let actual):
                    if let actual {
                        mapState = .connectedCoordinates(.init(coordinate: actual.coordinates), actual.country)
                    } else if let code = spec.countryCode {
                        mapState = .connectedCountry(code)
                    } else {
                        mapState = .disconnected
                    }
                case .connecting(let spec, let actual), .loadingConnectionInfo(let spec, let actual):
                    if let actual {
                        mapState = .connectingCoordinates(.init(coordinate: actual.coordinates), actual.country)
                    } else if let code = spec.countryCode {
                        mapState = .connectingCountry(code)
                    } else {
                        mapState = .disconnected
                    }
                }
                
                // withAnimation {  With animation causes the pin to sometimes show the previous state, not the actual. Disabling for now.
                state.pinMode = mapState.pinMode
                state.mapState = mapState
                // }
            }
            return .none
        }
    }
}

extension ConnectionSpec {
    var countryCode: String? {
        switch location {
        case .fastest:
            break
        case .region(code: let code):
            return code
        case .exact(_, _, _, let regionCode):
            return regionCode
        case .secureCore(let spec):
            switch spec {
            case .fastest:
                break
            case .fastestHop(let to):
                return to
            case .hop(let to, _):
                return to
            }
        }
        return nil
    }
}
