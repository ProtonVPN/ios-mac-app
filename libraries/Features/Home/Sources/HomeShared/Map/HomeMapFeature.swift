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

import Combine
import ComposableArchitecture
import Connection
import CoreLocation
import Domain
import Foundation
import Persistence
import SwiftUI
import VPNAppCore

@Reducer
public struct HomeMapFeature {
    private enum Constants {
        /// Debounce window collapsing rapid connection-state churn into a single store update.
        static let connectionStateDebounceIntervalInMilliseconds: Int = 50
        /// How close a pin's coordinates must come to the connection's, in degrees, to count as the same city.
        static let sameCityTolerance = 0.05
    }

    @ObservableState
    public struct State: Equatable {
        public internal(set) var mapConnectionState: MapConnectionState = .disconnected

        /// How the user/connection pin renders. Derived from `mapConnectionState` (the two can never disagree).
        public var pinMode: ConnectionPin.Mode {
            mapConnectionState.pinMode
        }

        /// Whether the camera still tracks the connection: it re-centers on the connected or user country whenever that
        /// target or the visible region changes. A drag, pinch, or cluster zoom means the user took the camera
        /// somewhere deliberate, so tracking stops until the connection changes again or the user pin is tapped, both
        /// of which result in a re-centering of the connection pin.
        public internal(set) var isFollowingConnection = true

        public internal(set) var selectedLocationID: LocationPin.ID?

        /// Connectable locations shown as grey pins when the map is in interactive (full) view: one per city or state
        /// group, plus one per gateway. Loaded once when observation starts.
        public internal(set) var locationPins: [LocationPin] = []

        /// The selected pin resolved against the current pin set, or nil when nothing is selected (or the selected
        /// location disappeared in a refresh).
        public var selectedLocation: LocationPin? {
            selectedLocationID.flatMap { id in locationPins.first { $0.id == id } }
        }

        /// The city pins and clusters, with every location except the one drawn by the connection pin.
        public var displayedLocationPins: [LocationPin] {
            guard let coordinates = mapConnectionState.coordinates else { return locationPins }
            return locationPins.filter {
                abs($0.latitude - coordinates.latitude) > Constants.sameCityTolerance
                    || abs($0.longitude - coordinates.longitude) > Constants.sameCityTolerance
            }
        }

        var shouldShowPin: Bool {
            if case .connected = connectionState { // we're connected to a known country
                return true
            }
            return userCountry != nil // or we know the user country
        }

        @SharedReader(.connectionState) public var connectionState: ConnectionState
        @SharedReader(.userCountry) public var userCountry: String?
        @SharedReader(.userTier) public var userTier: VpnTier?

        public init() {}
    }

    public enum MapConnectionState: Equatable {
        /// Connected: the exit server's position and country.
        case connected(coordinates: CLLocationCoordinate2D, code: String?)
        /// Connecting: the target's position when known (a resolved server, or a spec matching a loaded location pin),
        /// else nil while only the country is known and the pin waits for the server to resolve.
        case connecting(coordinates: CLLocationCoordinate2D?, code: String?)
        case disconnected

        init(_ connectionState: ConnectionState, locationPins: [LocationPin] = []) {
            switch connectionState {
            case .disconnected:
                self = .disconnected

            case .killSwitchActive:
                self = .disconnected

            case .disconnecting:
                // VPNAPPL-2654: Discrepancy between connection state and what we're showing in the map
                self = .disconnected

            case let .connected(_, connectionData):
                self = .connected(
                    coordinates: connectionData.currentPeer.logical.coordinates,
                    code: connectionData.currentPeer.logical.exitCountryCode
                )

            case let .connecting(.resolved(intent), _),
                 let .authenticationRequired(.resolved(intent), _):
                self = .connecting(
                    coordinates: intent.resolvedServer.logical.coordinates,
                    code: intent.resolvedServer.logical.exitCountryCode
                )

            case let .connecting(.unresolved(intent), _),
                 let .authenticationRequired(.unresolved(intent), _):
                // We've started connecting via a `ConnectionSpec` but haven't picked a specific server yet. If the spec
                // matches a location pin we've already loaded, send the pin straight to its coordinates, since the
                // resolved server will live in that city anyway. Otherwise keep just the country code, and the pin
                // parks on the country center until the server resolves.
                let pin = locationPins.first { $0.location == intent.spec.location }
                self = .connecting(
                    coordinates: pin.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                    code: intent.spec.countryCode
                )

            case .resolving:
                // During the resolve window, if we have a prior server, keep the pin on it for UI continuity; otherwise
                // fall back to disconnected.

                // TODO: ProTUN: think about how to restore the code below so we may have server data available
                self = .disconnected
//                if let server {
//                    self = .connecting(coordinates: server.logical.coordinates, code: server.logical.exitCountryCode)
//                } else {
//                    self = .disconnected
//                }
            }
        }

        var pinMode: ConnectionPin.Mode {
            switch self {
            case .connected:
                .exitConnected
            case .connecting(nil, _):
                .invisible // Don't show the pin until we resolve the server
            case .connecting:
                .connecting
            case .disconnected:
                .disconnected
            }
        }

        var code: String? {
            switch self {
            case let .connected(_, code), let .connecting(_, code):
                code
            case .disconnected:
                nil
            }
        }

        var coordinates: CLLocationCoordinate2D? {
            switch self {
            case let .connected(coordinates, _):
                coordinates
            case let .connecting(coordinates, _):
                coordinates
            case .disconnected:
                nil
            }
        }
    }

    public enum Action {
        case observeConnectionState
        case connectionStateUpdated(ConnectionState)
        case locationPinsLoaded([LocationPin])
        case locationPinTapped(LocationPin)

        /// The selected city's connect pill was tapped. Connects (or upsells) and dismisses the pill.
        case connectPillTapped(LocationPin)
        /// A coalesced multi-pin disc was tapped. The view zooms the camera; any pill is dismissed.
        case pinClusterTapped
        /// The user/connection pin was tapped. The view recenters the camera; any pill is dismissed.
        case userPinTapped
        /// A tap on the map that hit no pin: dismisses the selected location's pill, if one is up.
        case mapBackgroundTapped
        /// The user started moving the map with a drag or a pinch; any pill is dismissed.
        case mapMoved
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            /// Paid user tapped a location. The parent issues the connect command.
            case connect(ConnectionSpec)
            /// Free user tapped a location. Choosing a location is paid, so route to the upsell.
            case showUpsell
        }
    }

    private enum CancelID {
        case locationPins
        case connectionState
    }

    @Dependency(\.debounceScheduler) private var scheduler
    @Dependency(\.serverRepository) private var serverRepository

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .observeConnectionState:
                // Kick off connection-state observation and load the connectable locations (grey pins).
                // `cancelInFlight` keeps a repeated kick (scene reconstruction) from stacking a duplicate subscription
                // or re-running the repository sweep concurrently.
                let repository = serverRepository
                let debounceInterval = Constants.connectionStateDebounceIntervalInMilliseconds
                let scheduler = scheduler
                return .merge(
                    .publisher {
                        // The shared publisher replays the current value on subscription; let that first emission
                        // through immediately so the initial render isn't delayed, and debounce the rest to coalesce
                        // rapid connection transitions.
                        let updates = state.$connectionState.publisher
                        return Publishers.Merge(
                            updates.first(),
                            updates.dropFirst().debounce(for: .milliseconds(debounceInterval), scheduler: scheduler)
                        )
                        .receive(on: UIScheduler.shared)
                        .map(Action.connectionStateUpdated)
                    }
                    .cancellable(id: CancelID.connectionState, cancelInFlight: true),
                    .run { send in await send(.locationPinsLoaded(Self.loadLocationPins(from: repository))) }
                        .cancellable(id: CancelID.locationPins, cancelInFlight: true)
                )

            case let .connectionStateUpdated(connectionState):
                // The view derives the highlight, camera, and pin from this state, and animates the change itself.
                let derived = MapConnectionState(connectionState, locationPins: state.locationPins)
                if derived != state.mapConnectionState {
                    state.isFollowingConnection = true
                }
                state.mapConnectionState = derived
                return .none

            case let .locationPinsLoaded(pins):
                state.locationPins = pins
                // `MapConnectionState` derives from the pins as well: the unresolved-connect path parks the user pin on
                // a loaded city. The load can lose the race against the first connection-state emission (the shared
                // publisher replays synchronously on subscription), so re-derive here rather than leaving the pin
                // invisible until the next connection change.
                state.mapConnectionState = MapConnectionState(state.connectionState, locationPins: pins)
                return .none

            case let .locationPinTapped(pin):
                // First tap selects and reveals the pill; the connect happens on the pill tap.
                state.selectedLocationID = pin.id
                return .none

            case let .connectPillTapped(pin):
                state.selectedLocationID = nil // the pill has done its job
                if state.userTier.isFree {
                    return .send(.delegate(.showUpsell))
                }
                return .send(.delegate(.connect(pin.connectionSpec)))

            case .pinClusterTapped, .mapMoved:
                // If the user moves the map, stop following the location and de-select any pin they may have tapped on.
                state.selectedLocationID = nil
                state.isFollowingConnection = false
                return .none

            case .userPinTapped:
                state.selectedLocationID = nil
                state.isFollowingConnection = true
                return .none

            case .mapBackgroundTapped:
                state.selectedLocationID = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Reads the connectable locations — one entry per city or state group, plus one per gateway — skipping secure core
    /// and under-maintenance groups, and maps them to grey pins at each group's representative coordinate (one member
    /// server's position; a group's servers are colocated, so any member is close).
    static func loadLocationPins(from repository: ServerRepository) -> [LocationPin] {
        // Two sweeps: cities/states (grouped by city, gateways excluded SQL-side), then gateways (grouped by server
        // type, which yields one group per gateway per country).
        let cities = repository
            .getGroups(
                filteredBy: [.features(.standard), .isNotUnderMaintenance, .kind(.country(code: nil))],
                groupedBy: .cityName
            )
            .compactMap(placePin(for:))
        let gateways = repository
            .getGroups(filteredBy: [.features(.standard), .isNotUnderMaintenance], groupedBy: .serverType)
            .compactMap(gatewayPin(for:))
        return cities + gateways
    }

    private static func placePin(for group: ServerGroupInfo) -> LocationPin? {
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
        return LocationPin(
            id: "\(code)#\(displayName)",
            displayName: displayName,
            translatedCity: group.translatedCity,
            latitude: group.latitude,
            longitude: group.longitude,
            minTier: group.minTier,
            location: location,
            // Render on the country's coast if the true coordinate falls just offshore of the simplified coastline
            // (Nuuk, Reykjavik). Snaps only within the pin's own country.
            direction: CoastSnap.snappedDirection(
                latitudeDegrees: group.latitude,
                longitudeDegrees: group.longitude,
                countryCode: code
            )
        )
    }

    /// A gateway as a pin. The kind carries no country, so the ID is disambiguated by coordinate (a same-named gateway
    /// with servers in two countries appears as two groups and gets two pins), the pill shows no flag, and the position
    /// uses the raw coordinate with no coast snap.
    private static func gatewayPin(for group: ServerGroupInfo) -> LocationPin? {
        guard case let .gateway(name) = group.kind else { return nil }
        return LocationPin(
            id: "gateway#\(name)@\(group.latitude),\(group.longitude)",
            displayName: name,
            latitude: group.latitude,
            longitude: group.longitude,
            minTier: group.minTier,
            location: .gateway(name: name)
        )
    }
}
