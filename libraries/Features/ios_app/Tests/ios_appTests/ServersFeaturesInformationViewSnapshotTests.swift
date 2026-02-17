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

@testable import ios_app
import SnapshotTesting
import SwiftUI
import System
import Testing
import TestingErgonomics

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct ServersFeaturesInformationViewSnapshotTests {
    @Test("All features in single section")
    func serversFeaturesInformationViewAllFeatures() {
        let view = ServersFeaturesInformationView(
            viewModel: ServersFeaturesInformationViewModelImplementation.mock,
            onDismiss: {}
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 1000)))
    }

    @Test("Multiple sections with titles")
    func serversFeaturesInformationViewMultipleSections() {
        let view = ServersFeaturesInformationView(
            viewModel: ServersFeaturesInformationViewModelImplementation.multipleSections,
            onDismiss: {}
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 800)))
    }

    @Test("Single feature without title")
    func serversFeaturesInformationViewNoTitles() {
        let view = ServersFeaturesInformationView(
            viewModel: ServersFeaturesInformationViewModelImplementation.noTitles,
            onDismiss: {}
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 300)))
    }

    @Test("Single feature with title")
    func serversFeaturesInformationViewSingleFeature() {
        let view = ServersFeaturesInformationView(
            viewModel: ServersFeaturesInformationViewModelImplementation.singleFeature,
            onDismiss: {}
        )
        .background(Color(.background, .weak))
        .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 350)))
    }
}

extension ServersFeaturesInformationViewSnapshotTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/ios_app/Tests/ios_appTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
