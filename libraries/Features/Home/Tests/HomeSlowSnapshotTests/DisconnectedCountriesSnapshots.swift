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
import Home
@testable import HomeShared
import SnapshotTesting
import SwiftUI
import Testing
import TestingErgonomics
import Theme
import VPNAppCore

struct DisconnectedCountriesSnapshotsTests {
    @Shared(.userCountry) var userCountry

    // GPU-render tolerances, shared across the GPU suites.
    let mapRenderingPrecision = Self.gpuSnapshotPrecision
    let mapPerceptualPrecision = Self.gpuPerceptualPrecision

    @Test("Map Screen Countries", arguments: Countries.all)
    @MainActor
    func countries(countryCode: String) throws {
        let countryCode = countryCode.uppercased()
        let store = Store(initialState: HomeMapFeature.State(), reducer: HomeMapFeature.init) {
            $0.locale = Locale(identifier: "en")
            $0.date = .constant(Date())
            $0.continuousClock = TestClock()
        }
        let size = try #require(ViewImageConfig.iPhoneSe.size)
        let mapView = MapSnapshotScreen(store: store, title: countryCode, size: size)

        withDependencies {
            $0.locale = Locale(identifier: "en")
            $0.date = .constant(Date())
            // The map view re-samples the Sun and Moon on a sleep loop over this clock. A TestClock
            // never ticks, so the render stays a single deterministic frame.
            $0.continuousClock = TestClock()
        } operation: {
            $userCountry.withLock { $0 = countryCode }
            store.send(.newMapState(.disconnected))
            store.send(.connectionStateUpdated(.disconnected))
            assertSnapshot(
                of: mapView,
                as: .image(precision: mapRenderingPrecision, perceptualPrecision: mapPerceptualPrecision, layout: .sizeThatFits),
                named: "Disconnected",
                testName: countryCode
            )
            $userCountry.withLock { $0 = nil }
            store.send(.newMapState(.disconnected))
        }
    }
}

extension DisconnectedCountriesSnapshotsTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
