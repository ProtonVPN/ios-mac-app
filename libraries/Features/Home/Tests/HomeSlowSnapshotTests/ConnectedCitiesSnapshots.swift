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

import SwiftUI
import System
import Testing

import ComposableArchitecture
import SnapshotTesting
import TestingErgonomics

import Home
@testable import HomeShared
import Theme
import VPNAppCore

struct MapCitiesScreenTests {
    @Shared(.userCountry) var userCountry

    let mapRenderingPrecision: Float = 0.99

    @Test("Map Screen Cities", arguments: Cities.all)
    @MainActor
    func cities(city: (code: String, cityName: String, lat: Double, long: Double)) {
        let countryCode = city.0
        let store = Store(initialState: HomeMapFeature.State(), reducer: HomeMapFeature.init)
        let size = ViewImageConfig.iPhoneSe.size!
        let mapView = ZStack {
            HomeMapView(store: store, availableHeight: size.height, availableWidth: size.width)
                .frame(size)
                .background(Color(.background))
                .environment(\.colorScheme, .dark)
            VStack {
                Text("\(countryCode), \(city.cityName)")
                    .foregroundStyle(.white)
                    .font(.hero)
                    .padding(.top, .themeSpacing64)
                Spacer()
            }
        }

        withDependencies {
            $0.locale = Locale(identifier: "en")
            $0.date = .constant(Date())
        } operation: {
            $userCountry.withLock { $0 = countryCode }
            let actual: VPNConnectionActual = .mock(country: countryCode, coordinates: .init(latitude: city.lat, longitude: city.long))
            store.send(.newMapState(.connectedCoordinates(.init(latitude: city.lat, longitude: city.long), countryCode)))
            store.send(.connectionStateUpdated(.connected(.defaultFastest, actual)))

            assertSnapshot(
                of: mapView,
                as: .image(precision: mapRenderingPrecision, layout: .sizeThatFits),
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
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Home/Tests/HomeSlowSnapshotTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
