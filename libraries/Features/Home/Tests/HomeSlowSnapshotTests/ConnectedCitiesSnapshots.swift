//
//  Created on 2025-05-27 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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
import CoreLocation
import Domain
import Home
@testable import HomeShared
import SnapshotTesting
import SwiftUI
import Testing
import TestingErgonomics
import Theme
import VPNAppCore

struct MapCitiesScreenTests {
    @Shared(.userCountry) var userCountry

    // GPU-render tolerances, shared across the GPU suites.
    let mapRenderingPrecision = Self.gpuSnapshotPrecision
    let mapPerceptualPrecision = Self.gpuPerceptualPrecision

    @Test("Map Screen Cities", arguments: Cities.all)
    @MainActor
    func cities(city: (code: String, cityName: String, lat: Double, long: Double)) throws {
        let countryCode = city.0
        let store = Store(initialState: HomeMapFeature.State(), reducer: HomeMapFeature.init)
        let size = try #require(ViewImageConfig.iPhoneSe.size)
        let mapView = MapSnapshotScreen(store: store, title: "\(countryCode), \(city.cityName)", size: size)

        withDependencies {
            $0.locale = Locale(identifier: "en")
            $0.date = .constant(Date())
        } operation: {
            $userCountry.withLock { $0 = countryCode }
            let server: Server = .mock(country: countryCode, coordinates: .init(latitude: city.lat, longitude: city.long))
            store.send(.newMapState(.connectedCoordinates(.init(latitude: city.lat, longitude: city.long), countryCode)))
            store.send(.connectionStateUpdated(.previewConnected(for: .defaultFastest, server: server)))

            assertSnapshot(
                of: mapView,
                as: .image(precision: mapRenderingPrecision, perceptualPrecision: mapPerceptualPrecision, layout: .sizeThatFits),
                named: "Connected",
                testName: "\(countryCode), \(city.cityName)"
            )
            $userCountry.withLock { $0 = nil }
            store.send(.newMapState(.disconnected))
        }
    }
}

extension MapCitiesScreenTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
