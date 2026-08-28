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
    import ModalsShared
    import SnapshotTesting
    import SwiftUI
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct FreeConnectionsInfoSheetViewSnapshotTests {
        /// The size of the window the app shows the sheet in.
        private static let layout = SnapshotEnvironment.Layout.fixed(CGSize(width: 520, height: 500))

        private static let countries: IdentifiedArrayOf<FreeConnectionsFeature.State.Country> = [
            FreeConnectionsFeature.State.Country(code: "US", name: "United States"),
            .init(code: "JP", name: "Japan"),
            .init(code: "NL", name: "Netherlands"),
            .init(code: "RO", name: "Romania"),
            .init(code: "PL", name: "Poland"),
            .init(code: "DE", name: "Germany"),
        ]

        @Test("Free connections info sheet")
        func freeConnectionsInfoSheetViewDefault() {
            assertSnapshot(of: Self.view(), layout: Self.layout)
        }

        private static func view() -> some View {
            FreeConnectionsView(store: Store(initialState: .init(countries: countries)) { EmptyReducer() })
                .background(Color(.background))
        }
    }

    extension FreeConnectionsInfoSheetViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Modals/Tests/ModalsTests")
        }
    }
#endif
