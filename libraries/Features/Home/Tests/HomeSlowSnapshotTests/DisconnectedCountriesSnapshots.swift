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

import Home
@testable import HomeShared
import Theme
import VPNAppCore

import SnapshotTestsSupport

struct DisconnectedCountriesSnapshotsTests {
    @Shared(.userCountry) var userCountry

    let mapRenderingPrecision: Float = 0.99

    @Test("Map Screen Countries", arguments: Countries.all)
    @MainActor
    func countries(countryCode: String) {
        let countryCode = countryCode.uppercased()
        let store = Store(initialState: HomeMapFeature.State(), reducer: HomeMapFeature.init)
        let size = ViewImageConfig.iPhoneSe.size!
        let mapView = ZStack {
            HomeMapView(store: store, availableHeight: size.height, availableWidth: size.width)
                .frame(size)
                .background(Color(.background))
                .environment(\.colorScheme, .dark)
            VStack {
                Text(countryCode)
                    .foregroundStyle(.white)
                    .font(.hero)
                    .padding(.themeSpacing64)
                Spacer()
            }
        }

        withDependencies {
            $0.locale = Locale(identifier: "en")
            $0.date = .constant(Date())
        } operation: {
            $userCountry.withLock { $0 = countryCode }
            store.send(.newMapState(.disconnected))
            store.send(.connectionStateUpdated(.disconnected))
            assertSnapshot(
                of: mapView,
                as: .image(precision: mapRenderingPrecision, layout: .sizeThatFits),
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
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Home/Tests/HomeSlowSnapshotTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
