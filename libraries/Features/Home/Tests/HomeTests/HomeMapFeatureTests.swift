//
//  Created on 20/07/2026.
//
//  Copyright (c) 2026 Proton AG
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
import DomainTestSupport
import Foundation
@testable import HomeShared
import Persistence
import Testing

@Suite("Home map feature")
@MainActor
struct HomeMapFeatureTests {
    private static let geneva = LocationPin(
        id: "CH#Geneva",
        displayName: "Geneva",
        latitude: 46.2,
        longitude: 6.14,
        minTier: .free,
        location: .city(name: "Geneva", code: "CH", order: .fastest)
    )

    private static let zurich = LocationPin(
        id: "CH#Zurich",
        displayName: "Zurich",
        latitude: 47.37,
        longitude: 8.54,
        minTier: .free,
        location: .city(name: "Zurich", code: "CH", order: .fastest)
    )

    // MARK: - Displayed pins

    @Test("The connected city's pin leaves the displayed set, and returns on disconnect")
    func connectedCityLeavesTheDisplayedPins() {
        var state = HomeMapFeature.State()
        state.locationPins = [Self.geneva, Self.zurich]
        #expect(state.displayedLocationPins == [Self.geneva, Self.zurich])

        state.mapConnectionState = .connected(
            coordinates: CLLocationCoordinate2D(latitude: Self.geneva.latitude, longitude: Self.geneva.longitude),
            code: "CH"
        )
        #expect(state.displayedLocationPins == [Self.zurich])

        state.mapConnectionState = .disconnected
        #expect(state.displayedLocationPins == [Self.geneva, Self.zurich])
    }

    // MARK: - Selection & connect

    @Test("Tapping a city pin selects it; the connect happens on the pill tap")
    func locationPinTapSelects() async {
        let store = TestStore(initialState: HomeMapFeature.State()) { HomeMapFeature() }

        await store.send(.locationPinTapped(Self.geneva)) {
            $0.selectedLocationID = Self.geneva.id
        }
    }

    @Test("The connect pill connects a paid user and dismisses itself")
    func connectPillConnectsPaidUser() async {
        @Shared(.userTier) var userTier
        $userTier.withLock { $0 = .paid }
        var state = HomeMapFeature.State()
        state.selectedLocationID = Self.geneva.id
        let store = TestStore(initialState: state) { HomeMapFeature() }

        await store.send(.connectPillTapped(Self.geneva)) {
            $0.selectedLocationID = nil
        }
        await store.receive(\.delegate.connect, Self.geneva.connectionSpec)
    }

    @Test("The connect pill routes a free user to the upsell instead")
    func connectPillUpsellsFreeUser() async {
        @Shared(.userTier) var userTier
        $userTier.withLock { $0 = .free }
        var state = HomeMapFeature.State()
        state.selectedLocationID = Self.geneva.id
        let store = TestStore(initialState: state) { HomeMapFeature() }

        await store.send(.connectPillTapped(Self.geneva)) {
            $0.selectedLocationID = nil
        }
        await store.receive(\.delegate.showUpsell)
    }

    @Test("Camera gestures dismiss the pill")
    func cameraGesturesDeselect() async {
        let store = TestStore(initialState: HomeMapFeature.State()) { HomeMapFeature() }

        await store.send(.locationPinTapped(Self.geneva)) { $0.selectedLocationID = Self.geneva.id }
        await store.send(.mapMoved) {
            $0.selectedLocationID = nil
            $0.isFollowingConnection = false
        }
        await store.send(.locationPinTapped(Self.geneva)) { $0.selectedLocationID = Self.geneva.id }
        await store.send(.pinClusterTapped) { $0.selectedLocationID = nil }
        await store.send(.locationPinTapped(Self.geneva)) { $0.selectedLocationID = Self.geneva.id }
        await store.send(.userPinTapped) {
            $0.selectedLocationID = nil
            $0.isFollowingConnection = true
        }
    }

    @Test("Gestures stop the camera following the connection; connection changes and the user pin resume it")
    func followingTracksWhoDrives() async {
        let store = TestStore(initialState: HomeMapFeature.State()) { HomeMapFeature() }

        await store.send(.mapMoved) { $0.isFollowingConnection = false }
        await store.send(.userPinTapped) { $0.isFollowingConnection = true }
        await store.send(.pinClusterTapped) { $0.isFollowingConnection = false }

        // Any change to the derived map state wins the camera back; a repeat of the same state does not.
        let poland = Server.mock(country: "PL", coordinates: .init(latitude: 52.23, longitude: 21.01))
        await store.send(.connectionStateUpdated(.disconnected))
        await store.send(.connectionStateUpdated(.previewConnected(for: .specificCountryServer, server: poland))) {
            $0.isFollowingConnection = true
            $0.mapConnectionState = .connected(coordinates: .init(latitude: 52.23, longitude: 21.01), code: "PL")
        }
    }

    @Test("A background tap dismisses the pill, and is inert once nothing is selected")
    func backgroundTapDismissesPill() async {
        var state = HomeMapFeature.State()
        state.selectedLocationID = Self.geneva.id
        let store = TestStore(initialState: state) { HomeMapFeature() }

        await store.send(.mapBackgroundTapped) { $0.selectedLocationID = nil }
        await store.send(.mapBackgroundTapped)
    }

    // MARK: - Map state derivation

    @Test("A connection-state update derives the map state (and with it the pin mode)")
    func connectionStateUpdatedDerivesMapState() async {
        let store = TestStore(initialState: HomeMapFeature.State()) { HomeMapFeature() }
        let poland = Server.mock(country: "PL", coordinates: .init(latitude: 52.23, longitude: 21.01))

        await store.send(.connectionStateUpdated(.previewConnected(for: .specificCountryServer, server: poland))) {
            $0.mapConnectionState = .connected(coordinates: .init(latitude: 52.23, longitude: 21.01), code: "PL")
        }
        #expect(store.state.pinMode == .exitConnected)

        await store.send(.connectionStateUpdated(.disconnected)) {
            $0.mapConnectionState = .disconnected
        }
        #expect(store.state.pinMode == .disconnected)
    }

    @Test("Loading the pins mid-connect re-derives the map state, parking the pin on the target city")
    func locationPinsLoadedRederivesMapConnectionState() async {
        // Regression: connecting via an unresolved spec whose city pin loads *after* the first connection-state
        // emission. Without the re-derive the pin stayed invisible until the next connection transition.
        @Shared(.connectionState) var connectionState
        $connectionState.withLock {
            $0 = .connecting(.unresolved(ConnectionPreparationIntent(
                spec: Self.geneva.connectionSpec,
                acceptableProtocols: .all
            )), tunnelActive: false)
        }
        let store = TestStore(initialState: HomeMapFeature.State()) { HomeMapFeature() }

        await store.send(.locationPinsLoaded([Self.geneva])) {
            $0.locationPins = [Self.geneva]
            $0.mapConnectionState = .connecting(coordinates: .init(latitude: 46.2, longitude: 6.14), code: "CH")
        }
        #expect(store.state.pinMode == .connecting)
    }

    @Test("An unresolved connect with no matching pin keeps only the country, and the pin stays hidden")
    func unresolvedConnectWithoutPinKeepsCountry() async {
        let store = TestStore(initialState: HomeMapFeature.State()) { HomeMapFeature() }
        let intent = ConnectionPreparationIntent(spec: Self.geneva.connectionSpec, acceptableProtocols: .all)

        await store.send(.connectionStateUpdated(.connecting(.unresolved(intent), tunnelActive: false))) {
            $0.mapConnectionState = .connecting(coordinates: nil, code: "CH")
        }
        #expect(store.state.pinMode == .invisible)
    }

    // MARK: - Pin loading

    @Test("Loading maps city and state groups to pins and folds gateways in as their own pins")
    func loadCityPinsIncludesGateways() {
        var repository = ServerRepository()
        repository.groups = { _, grouping, _ in
            switch grouping {
            case .cityName:
                return [
                    .mock(kind: .city(name: "Geneva", code: "CH"), latitude: 46.2, longitude: 6.14, translatedCity: "Genève"),
                    .mock(kind: .state(name: "Bavaria", code: "DE"), latitude: 48.1, longitude: 11.6),
                    .mock(kind: .country(code: "FR"), latitude: 48.85, longitude: 2.35), // dropped: not a place pin
                ]
            case .serverType:
                return [
                    .mock(kind: .gateway(name: "Acme"), latitude: 50.1, longitude: 8.68, minTier: .paid),
                    .mock(kind: .country(code: "DE"), latitude: 52.5, longitude: 13.4), // dropped: gateways only
                ]
            case .stateName:
                Issue.record("The pin load never groups by state name")
                return []
            }
        }

        let pins = HomeMapFeature.loadLocationPins(from: repository)

        #expect(pins.map(\.id) == ["CH#Geneva", "DE#Bavaria", "gateway#Acme@50.1,8.68"])
        #expect(pins.map(\.localizedName) == ["Genève", "Bavaria", "Acme"])
        #expect(pins.map(\.location) == [
            .city(name: "Geneva", code: "CH", order: .fastest),
            .state(name: "Bavaria", code: "DE", order: .fastest),
            .gateway(name: "Acme"),
        ])
        // The gateway pin has no country, so the connect pill renders without a flag.
        #expect(pins.last?.countryCode == nil)
        #expect(pins.last?.minTier == .paid)
    }

    @Test("Same-named gateways in two countries stay two distinct pins")
    func gatewayPinsDisambiguateByCoordinate() {
        var repository = ServerRepository()
        repository.groups = { _, grouping, _ in
            guard grouping == .serverType else { return [] }
            return [
                .mock(kind: .gateway(name: "Acme"), latitude: 50.1, longitude: 8.68),
                .mock(kind: .gateway(name: "Acme"), latitude: 40.7, longitude: -74.0),
            ]
        }

        let pins = HomeMapFeature.loadLocationPins(from: repository)

        #expect(pins.count == 2)
        #expect(Set(pins.map(\.id)).count == 2, "coordinate-disambiguated IDs must not collide")
    }
}

private extension ServerGroupInfo {
    static func mock(
        kind: Kind,
        latitude: Double,
        longitude: Double,
        minTier: VpnTier = .free,
        translatedCity: String? = nil
    ) -> ServerGroupInfo {
        ServerGroupInfo(
            kind: kind,
            featureIntersection: .zero,
            featureUnion: .zero,
            minTier: minTier,
            maxTier: minTier,
            serverCount: 1,
            cityCount: 1,
            latitude: latitude,
            longitude: longitude,
            translatedCity: translatedCity,
            supportsSmartRouting: false,
            isUnderMaintenance: false,
            protocolSupport: .all
        )
    }
}
