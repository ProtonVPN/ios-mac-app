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
import Foundation
import Persistence
import SharedViews
import SwiftUI
import VPNAppCore

@Reducer
public struct HomeMapFeature {
    private static let mapStateDebounceIntervalInMilliseconds: Int = 50

    @ObservableState
    public struct State: Equatable {
        public internal(set) var mapState: MapState = .disconnected
        public internal(set) var pinMode: MapPin.Mode = .disconnected

        /// Connectable locations shown as grey pins when the map is in interactive (full) view. Loaded once
        /// when observation starts.
        public internal(set) var cityPins: [CityPin] = []

        var shouldShowPin: Bool {
            if case .connected = connectionState { // we're connected to a known country
                return true
            }
            return userCountry != nil // or we know the user country
        }

        /// The first map-state update is emitted immediately (so the initial render isn't delayed); later
        /// ones are debounced to coalesce rapid connection transitions. (Previously inferred from the
        /// now-removed `pinOffset == .zero`.)
        var hasEmittedInitialMapState = false

        @SharedReader(.connectionState) var connectionState: ConnectionState
        @SharedReader(.userCountry) public var userCountry: String?
        @SharedReader(.userTier) public var userTier: Int?

        public init() {}
    }

    public enum MapState: Equatable {
        case connecting(String?)
        case connectedCoordinates(CLLocationCoordinate2D, String?)
        case connectingCoordinates(CLLocationCoordinate2D, String?)
        case disconnected

        init(_ connectionState: ConnectionState, cityPins: [CityPin] = []) {
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
                // We've started connecting via a `ConnectionSpec` but haven't picked a specific server yet. If the
                // spec is a city pin we've already loaded, send the pin straight to its coordinates — the resolved
                // server lives in that city, so there's no second hop. Otherwise keep just the country code, and the
                // pin parks on the country centre (the view's fallback) until the server resolves.
                if let pin = cityPins.first(where: { $0.location == intent.spec.location }) {
                    self = .connectingCoordinates(
                        CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                        intent.spec.countryCode
                    )
                } else {
                    self = .connecting(intent.spec.countryCode)
                }

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

        var pinMode: MapPin.Mode {
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
        case cityPinsLoaded([CityPin])
        /// A grey location pin was tapped in interactive view.
        case cityPinTapped(CityPin)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            /// Paid user tapped a location — connect to it (parent issues the command).
            case connect(ConnectionSpec)
            /// Free user tapped a location — choosing a location is paid, so route to the upsell.
            case showUpsell
        }
    }

    private enum CancelId {
        case connectionState
    }

    private enum IDs {
        case mapState
    }

    @Dependency(\.debounceScheduler) private var scheduler
    @Dependency(\.serverRepository) private var serverRepository

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .observeConnectionState:
                // Kick off connection-state observation and load the connectable locations (grey pins) once.
                let repository = serverRepository
                return .merge(
                    .publisher {
                        state
                            .$connectionState
                            .publisher
                            .receive(on: UIScheduler.shared)
                            .map(Action.connectionStateUpdated)
                    }
                    .cancellable(id: CancelId.connectionState),
                    .run { send in await send(.cityPinsLoaded(Self.loadCityPins(from: repository))) }
                )

            case let .connectionStateUpdated(connectionState):
                let mapState = MapState(connectionState, cityPins: state.cityPins)
                let animation: Animation? = UIAccessibility.isReduceMotionEnabled ? nil : .default
                let effect: Effect<Action> = .send(.newMapState(mapState), animation: animation)
                // Emit the first update immediately so the initial render isn't delayed; debounce
                // subsequent ones to coalesce rapid connecting→connected transitions.
                guard state.hasEmittedInitialMapState else {
                    state.hasEmittedInitialMapState = true
                    return effect
                }
                return effect.debounce(
                    id: IDs.mapState,
                    for: .milliseconds(Self.mapStateDebounceIntervalInMilliseconds),
                    scheduler: scheduler
                )

            case let .newMapState(mapState):
                state.pinMode = mapState.pinMode
                state.mapState = mapState
                // Highlight is derived from state by HomeMapView; no imperative map mutation needed.
                return .none

            case let .cityPinsLoaded(pins):
                state.cityPins = pins
                return .none

            case let .cityPinTapped(pin):
                if (state.userTier ?? .freeTier).isFreeTier {
                    return .send(.delegate(.showUpsell))
                }
                return .send(.delegate(.connect(pin.connectionSpec)))

            case .delegate:
                return .none
            }
        }
    }

    /// Reads the connectable standard locations (one entry per city/state group), skipping gateways,
    /// secure-core and under-maintenance groups, and maps them to grey pins at their aggregated centre.
    static func loadCityPins(from repository: ServerRepository) -> [CityPin] {
        repository
            .getGroups(filteredBy: [.features(.standard), .isNotUnderMaintenance], groupedBy: .cityName)
            .compactMap { group in
                let displayName: String
                let code: String
                let location: ConnectionSpec.Location
                switch group.kind {
                case let .city(name, countryCode):
                    displayName = name
                    code = countryCode
                    location = .city(name: name, code: countryCode, order: .fastest)
                case let .state(name, countryCode):
                    displayName = name
                    code = countryCode
                    location = .state(name: name, code: countryCode, order: .fastest)
                case .country, .gateway:
                    return nil
                }
                return CityPin(
                    id: "\(code)#\(displayName)",
                    displayName: displayName,
                    latitude: group.latitude,
                    longitude: group.longitude,
                    minTier: group.minTier,
                    location: location
                )
            }
    }
}
