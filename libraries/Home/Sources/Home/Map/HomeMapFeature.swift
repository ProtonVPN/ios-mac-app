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
import CoreLocation
import Ergonomics
import SVGView

@available(iOS 17.0, *)
@Reducer
public struct HomeMapFeature {

    private static let mapStateDebounceIntervalInMilliseconds: Int = 50

    @ObservableState
    public struct State: Equatable {
        public internal(set) var mapState: MapState = .disconnected
        public internal(set) var pinMode: MapPin.Mode = .disconnected

        var shouldShowPin: Bool {
            if case .connected = vpnConnectionStatus { // we're connected to a known country
                return true
            }
            return userCountry != nil // or we know the user country
        }

        var pinOffset: CGSize = .zero

        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus
        @SharedReader(.userCountry) public var userCountry: String?

        public init() { }
    }

    public enum MapState: Equatable {
        case connectedCoordinates(CLLocationCoordinate2D, String?)
        case connectingCoordinates(CLLocationCoordinate2D, String?)
        case disconnected

        init(_ connectionStatus: VPNConnectionStatus) {
            switch connectionStatus {
            case .disconnected:
                self = .disconnected
            case .disconnecting(_, _):
                // VPNAPPL-2654: Discrepancy between connection state and what we're showing in the map
                self = .disconnected

            case .connected(_, let actual):
                if let actual {
                    self = .connectedCoordinates(actual.server.logical.coordinates, actual.server.logical.exitCountryCode)
                } else {
                    self = .disconnected
                }
            case .connecting(_, .some(let server)):
                self = .connectingCoordinates(server.logical.coordinates, server.logical.exitCountryCode)

            case .connecting(_, nil):
                // We could retrieve the coordinates for the country instead, but this case should not be reachable
                // when using ConnectionFeature since it coalesces the state to resolving instead.
                log.assertionFailure("Cannot show connecting coordinates: server is nil")
                self = .disconnected

            case .resolving(_, let actual):
                if let actual {
                    self = .connectingCoordinates(actual.server.logical.coordinates, actual.server.logical.exitCountryCode)
                } else {
                    self = .disconnected
                }
            }
        }

        fileprivate var pinMode: MapPin.Mode {
            switch self {
            case .connectedCoordinates:
                return .exitConnected
            case .connectingCoordinates:
                return .connecting
            case .disconnected:
                return .disconnected
            }
        }

        func pinOffset(userCountry: String?) -> CGSize {
            guard let code = (code ?? userCountry)?.lowercased(),
                  let coordinates = coordinates ?? CountriesCoordinates.countryCenterCoordinates(code.uppercased()) else {
                return .zero
            }
            let location = CLLocationCoordinate2D(latitude: coordinates.latitude,
                                                  longitude: coordinates.longitude - 10) // -10 to account for the shifted map
            let projection = NaturalEarthProjection.projection(from: location, in: SVGView.mapBounds.size)

            return .init(width: projection.x, height: -projection.y)
        }

        var code: String? {
            switch self {
            case .connectedCoordinates(_, let code):
                return code
            case .connectingCoordinates(_, let code):
                return code
            case .disconnected:
                return nil
            }
        }
        
        var coordinates: CLLocationCoordinate2D? {
            switch self {
            case .connectedCoordinates(let coordinates, _):
                return coordinates
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
        case newMapState(MapState)
        case newPinOffset(CGSize)
    }

    private enum CancelId {
        case connectionState
    }

    private enum IDs {
        case mapState
    }

    @Dependency(\.debounceScheduler) private var scheduler

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
                let mapState = MapState(connectionStatus)
                let pinOffset = mapState.pinOffset(userCountry: state.userCountry)
                let animation: Animation? = UIAccessibility.isReduceMotionEnabled ? nil : .default
                let effect: Effect<Action> = .merge(
                    .send(.newMapState(mapState), animation: animation),
                    .send(.newPinOffset(pinOffset), animation: nil)
                )
                // If we're setting initial pinOffset
                if state.pinOffset == .zero {
                    return effect
                } else {
                    return effect
                        .debounce(
                            id: IDs.mapState,
                            for: .milliseconds(Self.mapStateDebounceIntervalInMilliseconds),
                            scheduler: scheduler
                        )
                }

            case .newMapState(let mapState):
                state.pinMode = mapState.pinMode
                state.mapState = mapState
                return .none

            case .newPinOffset(let offset):
                state.pinOffset = offset
                return .none
            }
        }
    }
}

extension ConnectionSpec {
    var countryCode: String? {
        switch location {
        case .random:
            break
        case .fastest:
            break
        case .region(code: let code):
            return code
        case .exact(_, _, _, _, let regionCode):
            return regionCode
        case .secureCore(let spec):
            switch spec {
            case .fastest, .random:
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
