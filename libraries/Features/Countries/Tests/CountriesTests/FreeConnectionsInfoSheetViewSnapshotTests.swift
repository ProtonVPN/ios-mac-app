//
//  Created on 10/04/2026 by Max Kupetskyi.
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

#if os(macOS)
    import ComposableArchitecture
    @testable import Countries_macOS
    import CountriesShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct FreeConnectionsInfoSheetViewSnapshotTests {
        @Test("Free connections info sheet")
        func freeConnectionsInfoSheetViewDefault() {
            let countries: IdentifiedArrayOf<FreeConnectionsFeature.State.Country> = [
                FreeConnectionsFeature.State.Country(code: "US", name: "United States"),
                .init(code: "JP", name: "Japan"),
                .init(code: "NL", name: "Netherlands"),
                .init(code: "RO", name: "Romania"),
                .init(code: "PL", name: "Poland"),
                .init(code: "DE", name: "Germany"),
            ]
            let view = FreeConnectionsView(
                store: Store(
                    initialState: .init(countries: countries)
                ) {
                    EmptyReducer()
                }
            )
            .background(Color(.background))
            .environment(\.colorScheme, .dark)

            let nsView = NSHostingView(rootView: view)
            assertSnapshot(of: nsView, as: .image(size: CGSize(width: 520, height: 500)))
        }
    }

    extension FreeConnectionsInfoSheetViewSnapshotTests: @preconcurrency AssertSnapshot {
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
