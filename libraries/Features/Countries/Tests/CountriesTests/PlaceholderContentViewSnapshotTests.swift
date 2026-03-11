//
//  Created on 20/02/2026 by Max Kupetskyi.
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
    @testable import Countries_iOS
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct PlaceholderContentViewSnapshotTests {
        @Test("PlaceholderContentView (standard)")
        func placeholderContentViewStandard() {
            let view = PlaceholderContentView(onlyCountries: false)
                .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        @Test("PlaceholderContentView (secure core)")
        func placeholderContentViewSecureCore() {
            let view = PlaceholderContentView(onlyCountries: true)
                .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }
    }

    extension PlaceholderContentViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Countries/Tests/CountriesTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
