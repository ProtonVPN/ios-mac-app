//
//  Created on 06/05/2026 by Max Kupetskyi.
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

#if os(iOS)
    import ComposableArchitecture
    @testable import Settings_iOS
    @testable import SettingsShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct EnvironmentSelectorMobileViewSnapshotTests {
        @Test("EnvironmentSelectorMobileView")
        func environmentSelectorMobileView() {
            let store = Store(
                initialState: DebugConfigurationFeature.State(
                    apiEndpoint: "https://vpn-api.proton.me",
                    atlasSecret: "atlas-secret",
                    atlasSecretFetchURLString: "",
                    overrides: [.empty()],
                    localValuesOverrides: [.empty()]
                ),
                reducer: { DebugConfigurationFeature() }
            )

            let view = EnvironmentSelectorMobileView(store: store)
                .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13ProMax)))
        }
    }

    extension EnvironmentSelectorMobileViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Settings/Tests/SettingsTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
