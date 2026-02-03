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
struct ServersFeaturesInformationViewSnapshotTests {
    @Test("All features in single section")
    func serversFeaturesInformationViewAllFeatures() {
        let view = ServersFeaturesInformationView(
            store: Store(initialState: .mock) {
                ServersFeaturesInformationFeature()
            },
            onDismiss: {}
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 1000)))
    }

    @Test("Multiple sections with titles")
    func serversFeaturesInformationViewMultipleSections() {
        let view = ServersFeaturesInformationView(
            store: Store(initialState: .multipleSections) {
                ServersFeaturesInformationFeature()
            },
            onDismiss: {}
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
    }

    @Test("Single feature without title")
    func serversFeaturesInformationViewNoTitles() {
        let view = ServersFeaturesInformationView(
            store: Store(initialState: .noTitles) {
                ServersFeaturesInformationFeature()
            },
            onDismiss: {}
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 300)))
    }

    @Test("Single feature with title")
    func serversFeaturesInformationViewSingleFeature() {
        let view = ServersFeaturesInformationView(
            store: Store(initialState: .singleFeature) {
                ServersFeaturesInformationFeature()
            },
            onDismiss: {}
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 350)))
    }
}

extension ServersFeaturesInformationViewSnapshotTests: @preconcurrency AssertSnapshot {
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
