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
import DependenciesTestSupport
import Domain
import Home
@testable import HomeShared
import SnapshotTesting
import SwiftUI
import Testing
import TestingErgonomics
import Theme
import VPNAppCore

// `.serialized` + the `.dependencies` trait give every city its own dependency context (store
// construction and view rendering see the same overrides) and keep the `@Shared` writes from
// interleaving across parameterized cases. The `TestClock` never ticks, so the map view's Sun/Moon
// re-sampling loop stays parked and the render is a single deterministic frame.
@Suite(
    "Map cities",
    .serialized,
    .snapshots(record: .missing),
    .dependencies {
        $0.locale = Locale(identifier: "en")
        $0.date = .constant(SnapshotEnvironment.date)
        $0.continuousClock = TestClock()
    }
)
struct MapCitiesScreenTests {
    // GPU-render tolerances, shared across the GPU suites.
    let mapRenderingPrecision = Self.gpuSnapshotPrecision
    let mapPerceptualPrecision = Self.gpuPerceptualPrecision

    @Test("Map Screen Cities", arguments: Cities.all)
    @MainActor
    func cities(city: (code: String, cityName: String, lat: Double, long: Double)) throws {
        // Declared in the test body, not as a suite stored property: the suite instance is created outside
        // the `.dependencies` trait's scope, so a projection bound there would write to a different shared
        // storage than the store reads.
        @Shared(.userCountry) var userCountry
        let countryCode = city.code
        $userCountry.withLock { $0 = countryCode }

        let store = Store(initialState: HomeMapFeature.State(), reducer: HomeMapFeature.init)
        let size = try #require(ViewImageConfig.iPhoneSe.size)
        let mapView = MapSnapshotScreen(store: store, title: "\(countryCode), \(city.cityName)", size: size)

        // One send through the reducer's own derivation path; the first emission is applied
        // immediately (the debounce only coalesces subsequent ones).
        let server: Server = .mock(country: countryCode, coordinates: .init(latitude: city.lat, longitude: city.long))
        store.send(.connectionStateUpdated(.previewConnected(for: .defaultFastest, server: server)))

        assertSnapshot(
            of: mapView,
            as: .image(precision: mapRenderingPrecision, perceptualPrecision: mapPerceptualPrecision, layout: .sizeThatFits),
            named: "Connected",
            testName: "\(countryCode), \(city.cityName)"
        )
    }
}

extension MapCitiesScreenTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
