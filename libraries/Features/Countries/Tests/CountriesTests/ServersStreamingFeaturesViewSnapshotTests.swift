//
//  Created on 05/01/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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
@testable import Countries
import SnapshotTesting
import SwiftUI
import System
import Testing

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct ServersStreamingFeaturesViewSnapshotTests {
    @Test("Three streaming services")
    func serversStreamingFeaturesViewThreeServices() {
        let view = ServersStreamingFeaturesView(
            store: Store(initialState: .mock) {
                ServersStreamingFeaturesFeature()
            }
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 500)))
    }

    @Test("Single streaming service")
    func serversStreamingFeaturesViewSingleService() {
        let view = ServersStreamingFeaturesView(
            store: Store(initialState: .singleService) {
                ServersStreamingFeaturesFeature()
            }
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 450)))
    }

    @Test("Many streaming services")
    func serversStreamingFeaturesViewManyServices() {
        let view = ServersStreamingFeaturesView(
            store: Store(initialState: .manyServices) {
                ServersStreamingFeaturesFeature()
            }
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 600)))
    }

    @Test("Few streaming services")
    func serversStreamingFeaturesViewFewServices() {
        let view = ServersStreamingFeaturesView(
            store: Store(initialState: .fewServices) {
                ServersStreamingFeaturesFeature()
            }
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 480)))
    }
}

extension ServersStreamingFeaturesViewSnapshotTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"] {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Countries/Tests/CountriesTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
