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
import Connection
import CoreLocation
import Domain
import Ergonomics
import Foundation
import SharedViews
import SVGView
import SwiftUI
import VPNAppCore

@Reducer
public struct HomeMapFeature {
    private static let mapStateDebounceIntervalInMilliseconds: Int = 50

    @ObservableState
    public struct State: Equatable {
        public internal(set) var mapState: MapState = .disconnected
        public internal(set) var pinMode: MapPin.Mode = .disconnected

        var shouldShowPin: Bool {
            if case .connected = connectionState { // we're connected to a known country
                return true
            }
            return userCountry != nil // or we know the user country
        }

        var pinOffset: CGSize = .zero

        @SharedReader(.connectionState) var connectionState: ConnectionState
        @SharedReader(.userCountry) public var userCountry: String?

        public init() {}
    }

    public enum MapState: Equatable {
        case connecting(String?)
        case connectedCoordinates(CLLocationCoordinate2D, String?)
        case connectingCoordinates(CLLocationCoordinate2D, String?)
        case disconnected

        init(_ connectionState: ConnectionState) {
            switch connectionState {
            case .disconnected:
                self = .disconnected

            case .killSwitchActive:
                self = .disconnected

            case .disconnecting:
                // VPNAPPL-2654: Discrepancy between connection state and what we're showing in the map
                self = .disconnected

            case let .connected(_, connectionData):
                self = .connectedCoordinates(connectionData.currentPeer.logical.coordinates, connectionData.currentPeer.logical.exitCountryCode)

            case let .connecting(.resolved(intent), _):
                self = .connectingCoordinates(intent.resolvedServer.logical.coordinates, intent.resolvedServer.logical.exitCountryCode)

            case let .connecting(.unresolved(intent), _):
                // We've started connecting according to a `ConnectionSpec`, but we've not yet chosen a specific server
                // We *could* retrieve the coordinates for the country, but we want to avoid the pin moving once to the
                // country, and then again to the specific location of the server
                self = .connecting(intent.spec.countryCode)

            case .resolving:
                // During the resolve window, if we have a prior server, keep the pin on it
                // for UI continuity; otherwise fall back to disconnected.

                // TODO: ProTUN: think about how to restore the code below so we may have server data available
                self = .disconnected
//                if let server {
//                    self = .connectingCoordinates(server.logical.coordinates, server.logical.exitCountryCode)
//                } else {
//                    self = .disconnected
//                }
            }
        }

        fileprivate var pinMode: MapPin.Mode {
            switch self {
            case .connecting:
                .invisible // Don't show the pin until we resolve the server
            case .connectedCoordinates:
                .exitConnected
            case .connectingCoordinates:
                .connecting
            case .disconnected:
                .disconnected
            }
        }

        func pinOffset(userCountry: String?) -> CGSize {
            guard let code = (code ?? userCountry)?.lowercased(),
                  let coordinates = coordinates ?? CountriesCoordinates.countryCenterCoordinates(code.uppercased()) else {
                return .zero
            }
            let projection = NaturalEarthProjection.projection(
                from: coordinates.withMapShift,
                in: SVGView.mapBounds.size
            )

            return .init(width: projection.x, height: -projection.y)
        }

        var code: String? {
            switch self {
            case let .connecting(code):
                code
            case let .connectedCoordinates(_, code):
                code
            case let .connectingCoordinates(_, code):
                code
            case .disconnected:
                nil
            }
        }

        var coordinates: CLLocationCoordinate2D? {
            switch self {
            case let .connectedCoordinates(coordinates, _):
                coordinates
            case let .connectingCoordinates(coordinates, _):
                coordinates
            case .connecting, .disconnected:
                nil
            }
        }
    }

    public enum Action: Equatable {
        case observeConnectionState
        case connectionStateUpdated(ConnectionState)
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
                        .$connectionState
                        .publisher
                        .receive(on: UIScheduler.shared)
                        .map(Action.connectionStateUpdated)
                }
                .cancellable(id: CancelId.connectionState)

            case let .connectionStateUpdated(connectionState):
                let mapState = MapState(connectionState)
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

            case let .newMapState(mapState):
                state.pinMode = mapState.pinMode
                state.mapState = mapState
                let highlightedCountryCode = mapState.code ?? state.userCountry
                SVGView.updateWith(code: highlightedCountryCode)

                return .none

            case let .newPinOffset(offset):
                state.pinOffset = offset
                return .none
            }
        }
    }
}

private extension CLLocationCoordinate2D {
    var withMapShift: Self {
        .init(
            latitude: latitude,
            longitude: withLongitudeShift
        )
    }

    private var withLongitudeShift: CLLocationDegrees {
        let withShift = longitude - 10 // -10 to account for the shifted map
        if withShift < -180 {
            let delta = abs(withShift) - 180
            return 180 - delta
        } else {
            return withShift
        }
    }
}
