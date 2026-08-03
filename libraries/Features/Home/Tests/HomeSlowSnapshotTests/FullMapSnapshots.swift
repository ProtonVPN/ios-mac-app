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
import DependenciesTestSupport
import Domain
import Home
@testable import HomeShared
import SnapshotTesting
import SwiftUI
import Testing
import TestingErgonomics
import Theme

// The full interactive map, reached by constructing the state (`presentation: .full`) rather than by
// delivering gestures — which is what makes this snapshot possible at all. It is the only screen-level
// coverage of the interactive render path: day/night lighting (`lightFade` 1), the terminator at the
// pinned date, and the city pins drawn in the globe's own Metal pass.
@Suite(
    "Full map",
    .serialized,
    .snapshots(record: .missing),
    .dependencies {
        $0.locale = Locale(identifier: "en")
        $0.date = .constant(SnapshotEnvironment.date)
        $0.continuousClock = TestClock()
    }
)
struct FullMapSnapshots {
    // GPU-render tolerances, shared across the GPU suites.
    let precision = Self.gpuSnapshotPrecision
    let perceptualPrecision = Self.gpuPerceptualPrecision

    /// A spread of city pins across Europe, close enough at the default zoom that Zurich and Milan exercise the
    /// clustering path alongside the singles.
    private static let locationPins = [
        pin("Paris", code: "FR", latitude: 48.85, longitude: 2.35),
        pin("Zurich", code: "CH", latitude: 47.37, longitude: 8.54),
        pin("Milan", code: "IT", latitude: 45.46, longitude: 9.19),
        pin("Stockholm", code: "SE", latitude: 59.33, longitude: 18.07),
        pin("Lisbon", code: "PT", latitude: 38.72, longitude: -9.14),
    ]

    private static func pin(_ name: String, code: String, latitude: Double, longitude: Double) -> LocationPin {
        LocationPin(
            id: "\(code)#\(name)",
            displayName: name,
            latitude: latitude,
            longitude: longitude,
            minTier: .free,
            location: .city(name: name, code: code, order: .fastest)
        )
    }

    @Test("The full interactive map: lit globe, terminator, and city pins")
    @MainActor
    func fullMap() throws {
        var state = HomeMapFeature.State()
        state.presentation = .full
        state.locationPins = Self.locationPins
        let store = Store(initialState: state, reducer: HomeMapFeature.init)

        let size = try #require(ViewImageConfig.iPhoneSe.size)
        let mapView = HomeMapView(
            store: store,
            availableHeight: size.height, // the full map fills the screen; no sheet chrome
            availableWidth: size.width,
            renderHeight: size.height
        )
        .frame(size)
        .background(Color(.background))
        .environment(\.colorScheme, .dark)
        // Render the globe via off-screen Metal read-back, since a live MTKView can't be captured by the snapshot
        // strategy's `layer.render(in:)`.
        .environment(\.globeRenderMode, .staticImage)

        assertSnapshot(
            of: mapView,
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: .sizeThatFits),
            named: "FullMap"
        )
    }
}

extension FullMapSnapshots: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
